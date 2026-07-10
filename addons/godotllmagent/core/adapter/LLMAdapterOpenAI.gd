class_name LLMAdapterOpenAI;
extends LLMAdapter;

func _get_role_enum(role : String) -> AgentMessage.Role:
	match(role) :
		"system": return AgentMessage.Role.SYSTEM;
		"user": return AgentMessage.Role.USER;
		"assistant": return AgentMessage.Role.ASSISTANT;
		"tool": return AgentMessage.Role.TOOL;
		_: return AgentMessage.Role.UNKNOWN;
	
func _get_role_string(role : AgentMessage.Role) -> String:
	match (role) :
		AgentMessage.Role.SYSTEM: return "system";
		AgentMessage.Role.USER: return "user";
		AgentMessage.Role.ASSISTANT: return "assistant";
		AgentMessage.Role.TOOL: return "tool";
		_: return "unknown";

#region 解析请求
## 解析响应，响应必须是有效的
## [br]返回多条备选消息
func phrase_response(response : AgentResponse) -> AgentConversationMessages:
	var msgs : AgentConversationMessages = AgentConversationMessages.new();
	response.finished.connect(msgs.finished.emit);
	response.updated.connect(
		func() : 
			var response_body : Dictionary = response.get_body();
			
			if (response_body.has("error")) :
				push_warning("Agent API returned an error response: %s" % [JSON.stringify(response_body["error"])]);
				return;
			
			if (!response_body.has("choices") || typeof(response_body["choices"]) != TYPE_ARRAY) :
				push_warning("Agent API response has no choices array.");
				return;
			
			for choice : Dictionary in response_body.get("choices", []) :
				if (choice.has("index")) : 
					var choice_index : int = choice.get("index", 0);
					if (!msgs.messages.has(choice_index)):
						var msg : AgentMessageAssistant = AgentMessageAssistant.new();
						msgs.messages[choice_index] = msg;
					
					if (choice.has("message")) : 
						msgs.messages[choice_index] = phrase_message(msgs.messages[choice_index], choice["message"]);
					elif (choice.has("delta")) : 
						msgs.messages[choice_index] = phrase_message(msgs.messages[choice_index], choice["delta"]);
			
			msgs.updated.emit();
	);
	return msgs;

# 解析 JSON 消息
func phrase_message(msg : AgentMessageAssistant, \
		dict : Dictionary) -> AgentMessageAssistant:
	if (dict.has("content") && dict["content"] != null) : 
		msg.content += str(dict["content"]);
	if (dict.has("reasoning_content") && dict["reasoning_content"] != null) : 
		msg.reasoning_content += str(dict["reasoning_content"]);
	if (dict.has("role") && dict["role"] != null) : 
		msg.role = _get_role_enum(dict["role"]);
	
	if (dict.has("tool_calls") && typeof(dict["tool_calls"]) == Variant.Type.TYPE_ARRAY) :
		for tool_call_data : Dictionary in dict["tool_calls"] :
			var function_dict : Dictionary = tool_call_data.get("function", {})
			var tool_call_id : String = tool_call_data.get("id", "");
			var tool_call_index : int = tool_call_data.get("index", 0);
			
			if (!msg.tool_calls.has(tool_call_index)) : 
				var tool_call_name : String = function_dict.get("name", "");
				var tool_call : AgentToolCall = AgentToolCall.new(tool_call_id, tool_call_name);
				if (tool_call != null && tool_call.is_valid()) : 
					msg.tool_calls[tool_call_index] = tool_call;
			
			var tool_call : AgentToolCall = msg.tool_calls[tool_call_index];
			var tool_call_arguments : String = function_dict.get("arguments", "");
			tool_call.arguments += tool_call_arguments;
	return msg;

#endregion

#region 构建请求
func generate_header() -> PackedStringArray:
	var headers : PackedStringArray = [
		"Content-Type: application/json",
		"Accept: application/json",
	];
	var api_key : String = config.api_key;
	if (!api_key.is_empty()) :
		headers.append("Authorization: Bearer %s" % [api_key]);
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
	if (lower_url.ends_with("/chat/completions")) :
		return base_url + query;
	if (lower_url.ends_with("/v1")) :
		return base_url + "/chat/completions" + query;
	if (lower_url.ends_with("/")) :
		base_url = base_url.substr(0, base_url.length() - 1);
	return base_url + "/chat/completions" + query;

func _generate_messages(history_messages : Array[AgentMessage]) -> Array[Dictionary]:
	var result : Array[Dictionary] = [];
	
	# 添加系统提示词
	if (!config.system_prompt.strip_edges().is_empty()) :
		var system_prompt : Dictionary = {};
		system_prompt["role"] = _get_role_string(AgentMessage.Role.SYSTEM);
		system_prompt["content"] = config.system_prompt;
		result.push_back(system_prompt);
		
	# 将消息列表中的全部消息序列化为字典
	for msg : AgentMessage in history_messages :
		var msg_dict : Dictionary = {};
		msg_dict["role"] = _get_role_string(msg.role);
		msg_dict["content"] = msg.content;
		
		if (msg.role == AgentMessage.Role.TOOL):
			var tool_msg : AgentMessageToolCall = msg as AgentMessageToolCall;
			if (tool_msg == null) : continue;
			msg_dict["tool_call_id"] = tool_msg.tool_call_id;
		else :
			if (msg.role == AgentMessage.Role.ASSISTANT):
				var assistant_msg : AgentMessageAssistant = msg as AgentMessageAssistant;
				if (assistant_msg != null && !assistant_msg.tool_calls.is_empty()) :
					msg_dict["tool_calls"] = [];
					for index : int in assistant_msg.tool_calls :
						var tool_call : AgentToolCall = assistant_msg.tool_calls[index];
						if (tool_call.is_valid()) :
							msg_dict["tool_calls"].push_back({
								"id" : tool_call.id,
								"type" : "function",
								"function" : {
									"name" : tool_call.name,
									"arguments" : JSON.stringify(tool_call.arguments),
								},
							});
			else : pass;
		result.push_back(msg_dict);
	
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
			"type" : "function",
			"function" : {
				"name" : tool_name,
				"description" : tool._get_description(),
				"parameters" : {
					"type" : "object",
					"properties" : properties,
				},
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
		"messages" : _generate_messages(messages),
	};
	
	if (config.stream) : request_body["stream"] = true;
	if (config.temperature != 1.0) : request_body["temperature"] = config.temperature;
	if (config.top_p < 1.0) : request_body["top_p"] = config.top_p;
	if (config.n > 1) : request_body["n"] = config.n;
	if (config.max_tokens > 0) : request_body["max_tokens"] = config.max_tokens;
	if (!config.stop.is_empty()) : request_body["stop"] = Array(config.stop);
	if (config.presence_penalty != 0.0) : request_body["presence_penalty"] = config.presence_penalty;
	if (config.frequency_penalty != 0.0) : request_body["frequency_penalty"] = config.frequency_penalty;
	if (!tool_list.is_empty()) :
		request_body["tools"] = _generate_tools(tool_list);
		request_body["tool_choice"] = "auto";
	
	for key : Variant in extra_parameters : 
		if (request_body.has(key)) : continue;
		request_body[key] = extra_parameters[key];
	
	return JSON.stringify(request_body);

func generate_tool_call_error(error : AgentMessageToolCall) -> String : 
	var result : String = "";
	result = JSON.stringify({
		"error" : error.message,
	});
	return result;
#endregion
