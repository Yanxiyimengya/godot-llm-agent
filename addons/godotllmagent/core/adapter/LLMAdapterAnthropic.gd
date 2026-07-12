class_name LLMAdapterAnthropic;
extends LLMAdapter;

#region 解析请求
## 解析响应，响应必须是有效的
func phrase_response(response : AgentResponse) -> AgentConversationMessages:
	if (response == null) : 
		return null;
	var msgs : AgentConversationMessages = AgentConversationMessages.new();
	
	# 解析 Anthropic Content Block
	var phrase_content : Callable = func(msg : AgentMessageAssistant, \
			block : Dictionary, index : int = 0) -> void:
		var block_type : String = block.get("type", "");
		match(block_type) :
			"text", "text_delta":
				msg.content += str(block.get("text", ""));
			"thinking", "thinking_delta":
				msg.reasoning_content += str(block.get("thinking", ""));
			"tool_use":
				var tool_call_id : String = block.get("id", "");
				var tool_call_name : String = block.get("name", "");
				if (tool_call_id.is_empty()) :
					tool_call_id = "call_" + (tool_call_name + str(randi())).md5_text();
				if (!tool_call_name.is_empty()) :
					var tool_call : AgentToolCall = AgentToolCall.new(
						tool_call_id, tool_call_name);
					var input : Variant = block.get("input", null);
					if (input != null) :
						tool_call.arguments = JSON.stringify(input);
					msg.tool_calls[index] = tool_call;
			"input_json_delta":
				if (msg.tool_calls.has(index)) :
					var tool_call : AgentToolCall = msg.tool_calls[index];
					tool_call.arguments += str(block.get("partial_json", ""));
			_:
				pass;
	
	response.finished.connect(msgs.finished.emit);
	response.updated.connect(
		func() : 
			var body : String = response.get_body();
			var json : JSON = JSON.new();
			if (json.parse(body) != Error.OK) : 
				push_warning("Agent API response error.");
				return;
			var response_body : Dictionary = json.data;
			
			if (response_body.has("error")) :
				push_warning("Agent API returned an error response: %s" \
					% [JSON.stringify(response_body["error"])]);
				return;
			
			if (!msgs.messages.has(0)) :
				var msg : AgentMessageAssistant = AgentMessageAssistant.new();
				msg.role = AgentMessage.Role.ASSISTANT;
				msgs.messages[0] = msg;
			
			var msg : AgentMessageAssistant = msgs.messages[0];
			var response_type : String = response_body.get("type", "");
			
			match(response_type) :
				"message":
					if (response_body.get("role", "") == "assistant") :
						msg.role = AgentMessage.Role.ASSISTANT;
					var content : Variant = response_body.get("content", []);
					if (typeof(content) == TYPE_ARRAY) :
						for index : int in content.size() :
							var block : Variant = content[index];
							if (typeof(block) == TYPE_DICTIONARY) :
								phrase_content.call(msg, block, index);
				
				"message_start":
					var message : Dictionary = response_body.get("message", {});
					if (message.get("role", "") == "assistant") :
						msg.role = AgentMessage.Role.ASSISTANT;
				
				"content_block_start":
					var block : Dictionary = response_body.get("content_block", {});
					var index : int = response_body.get("index", 0);
					phrase_content.call(msg, block, index);
				
				"content_block_delta":
					var delta : Dictionary = response_body.get("delta", {});
					var index : int = response_body.get("index", 0);
					phrase_content.call(msg, delta, index);
				
				"content_block_stop", \
				"message_delta", \
				"message_stop", \
				"ping":
					pass;
				
				"error":
					push_warning("Anthropic API returned an error response: %s" \
						% [JSON.stringify(response_body.get("error", {}))]);
			
			msgs.updated.emit();
	);
	return msgs;

#endregion

#region 构建请求
func generate_header() -> PackedStringArray:
	var headers : PackedStringArray = [
		"Content-Type: application/json",
		"Accept: application/json",
		"anthropic-version: 2023-06-01",
	];
	var api_key : String = config.api_key;
	if (!api_key.is_empty()) :
		headers.append("x-api-key: %s" % [api_key]);
	return headers;

# 验证请求路径
func generate_url() -> String:
	var base_url : String = config.base_url.strip_edges();
	if (base_url.is_empty()) :
		return base_url;

	var query_index : int = base_url.find("?");
	var query : String = "";
	if (query_index >= 0) :
		query = base_url.substr(query_index);
		base_url = base_url.substr(0, query_index);

	var lower_url : String = base_url.to_lower();
	if (lower_url.ends_with("/v1/messages")) :
		return base_url + query;
	if (lower_url.ends_with("/v1")) :
		return base_url + "/messages" + query;
	if (lower_url.ends_with("/")) :
		base_url = base_url.substr(0, base_url.length() - 1);
	return base_url + "/v1/messages" + query;

func _generate_messages(history_messages : Array[AgentMessage]) -> Array[Dictionary]:
	var result : Array[Dictionary] = [];
	var tool_results : Array[Dictionary] = [];
	
	# 提交等待中的工具结果
	var flush_tool_results : Callable = func() -> void:
		if (tool_results.is_empty()) :
			return;
		result.push_back({
			"role" : "user",
			"content" : tool_results.duplicate(true),
		});
		tool_results.clear();
	
	# 将消息列表中的全部消息序列化为字典
	for msg : AgentMessage in history_messages :
		if (msg.role == AgentMessage.Role.TOOL) :
			var tool_msg : AgentMessageToolCall = msg as AgentMessageToolCall;
			if (tool_msg == null) : 
				continue;
			tool_results.push_back({
				"type" : "tool_result",
				"tool_use_id" : tool_msg.tool_call_id,
				"content" : tool_msg.content,
			});
			continue;
		
		if (msg.role == AgentMessage.Role.USER) :
			if (!tool_results.is_empty()) :
				var content : Array[Dictionary] = tool_results.duplicate(true);
				tool_results.clear();
				if (!msg.content.is_empty()) :
					content.push_back({
						"type" : "text",
						"text" : msg.content,
					});
				result.push_back({
					"role" : "user",
					"content" : content,
				});
			else :
				result.push_back({
					"role" : "user",
					"content" : msg.content,
				});
		
		elif (msg.role == AgentMessage.Role.ASSISTANT) :
			flush_tool_results.call();
			
			var content : Array[Dictionary] = [];
			if (!msg.content.is_empty()) :
				content.push_back({
					"type" : "text",
					"text" : msg.content,
				});
			
			var assistant_msg : AgentMessageAssistant = msg as AgentMessageAssistant;
			if (assistant_msg != null && !assistant_msg.tool_calls.is_empty()) :
				for index : int in assistant_msg.tool_calls :
					var tool_call : AgentToolCall = assistant_msg.tool_calls[index];
					if (!tool_call.is_valid()) :
						continue;
					
					var input : Variant = {};
					if (!tool_call.arguments.is_empty()) :
						var json : JSON = JSON.new();
						if (json.parse(tool_call.arguments) == Error.OK) :
							input = json.data;
					
					content.push_back({
						"type" : "tool_use",
						"id" : tool_call.id,
						"name" : tool_call.name,
						"input" : input,
					});
			
			if (!content.is_empty()) :
				result.push_back({
					"role" : "assistant",
					"content" : content,
				});
	
	flush_tool_results.call();
	return result;

# 构建工具调用
func _generate_tools(tool_list : Dictionary[String, AgentTool]) -> Array[Dictionary]:
	var result : Array[Dictionary] = [];
	for tool_name : String in tool_list.keys() :
		var tool : AgentTool = tool_list[tool_name];
		if (tool == null || tool_name.is_empty()) :
			continue;
		
		# 构建参数定义
		var properties : Dictionary[String, Dictionary] = {};
		for prop : AgentToolProperty in tool._get_properties() :
			properties[prop.name] = {
				"type": prop.type,
				"description": prop.description,
			};
		
		# 构建工具定义
		var tool_declare : Dictionary = {
			"name" : tool_name,
			"description" : tool._get_description(),
			"input_schema" : {
				"type" : "object",
				"properties" : properties,
				"required" : tool._get_required(),
			},
		};
		
		result.push_back(tool_declare);
	return result;

func generate_body(
		messages : Array[AgentMessage],
		tool_list : Dictionary[String, AgentTool],
		extra_parameters : Dictionary = {}) -> String:
	var request_body : Dictionary = {
		"model" : config.model,
		"max_tokens" : config.max_tokens if config.max_tokens > 0 else 4096,
		"messages" : _generate_messages(messages),
	};
	
	if (!config.system_prompt.strip_edges().is_empty()) :
		request_body["system"] = config.system_prompt;
	if (config.stream) : 
		request_body["stream"] = true;
	if (config.temperature != 1.0) : 
		request_body["temperature"] = config.temperature;
	if (config.top_p < 1.0) : 
		request_body["top_p"] = config.top_p;
	if (!config.stop.is_empty()) : 
		request_body["stop_sequences"] = Array(config.stop);
	if (!tool_list.is_empty()) :
		request_body["tools"] = _generate_tools(tool_list);
		request_body["tool_choice"] = {
			"type" : "auto",
		};
	
	for key : Variant in extra_parameters :
		if (request_body.has(key)) : 
			continue;
		request_body[key] = extra_parameters[key];
	
	return JSON.stringify(request_body);

func generate_tool_call_error(error : AgentMessageToolCall) -> String :
	var result : String = "";
	result = JSON.stringify({
		"error" : error.message,
	});
	return result;
#endregion
