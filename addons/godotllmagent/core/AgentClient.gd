@icon("../imgs/AgentClient.svg")
class_name AgentClient;
extends Node;
## Agent 客户端通信节点
## 负责维护 Agent 于 LLM 之间的通信

## 出错时触发
signal error(error : AgentError);

enum AgentError
{
	NOT_OPENED,				# 会话未打开
	REQUEST_URL_EMPTY,		# url地址为空
	REQUEST_URL_WRONG,		# url地址有误
	
	CONNENT_TIMEOUT,		# 连接超时
	CONNENT_ERROR,			# 连接错误
	
	REQUEST_TIMEOUT,		# 请求超时
	REQUEST_ERROR,			# 请求失败
	
	RESPONSE_TIMEOUT,		# 响应超时
	RESPONSE_ERROR,			# 响应失败
	
	LLM_ERROR,				# 大模型错误
}

@export var config : AgentConfiguration = AgentConfiguration.new();
var context : AgentContext;
var adapter : LLMAdapter;
var tool_actuator : AgentToolActuator;

#region 生命周期
var _is_opened : bool = false;

func _notification(what: int) -> void:
	if (what == NOTIFICATION_PREDELETE) :
		self.close();

## 打开 Agent 会话
func open() -> Error:
	_is_opened = true;
	context = AgentContext.new();
	adapter = LLMAdapterOpenAI.new(config);
	tool_actuator = AgentToolActuator.new();
	return Error.OK;

## 关闭 Agent 会话
func close() -> void:
	_is_opened = false;
	pass;

## 若 Agent 会话已打开，返回 true，否则返回 false
func is_opened() -> bool:
	return self._is_opened;
#endregion

#region 工具方法
# 解析URL的 地址/端口/TLS/请求路径
func _parse_url(url : String) -> Dictionary:
	var regex : RegEx = RegEx.new();
	if (regex.compile("^(https?)://([^/:?#]+)(?::([0-9]+))?([^?#]*)?(?:\\?([^#]*))?") != OK) :
		return {};
	var match_result : RegExMatch = regex.search(url);
	if (match_result == null) :
		return {};

	var scheme : String = match_result.get_string(1).to_lower();
	var port_text : String = match_result.get_string(3);
	var path : String = match_result.get_string(4);
	var query : String = match_result.get_string(5);
	if (path.is_empty()) :
		path = "/";
	if (!query.is_empty()) :
		path += "?" + query;
	return {
		"host" : match_result.get_string(2),
		"port" : int(port_text) if !port_text.is_empty() else (443 if scheme == "https" else 80),
		"tls" : scheme == "https",
		"path" : path,
	};

func _push_error(e : AgentError, m : String = "") -> void:
	var s : String = "";
	match (e):
		AgentError.NOT_OPENED: s = "会话未打开";
		AgentError.REQUEST_URL_EMPTY: s = "url 地址为空";
		AgentError.REQUEST_URL_WRONG: s = "错误的 url 地址";
		AgentError.REQUEST_TIMEOUT: s = "请求超时";
		AgentError.REQUEST_ERROR: s = "请求失败";
		AgentError.CONNENT_TIMEOUT: s = "连接超时";
		AgentError.CONNENT_ERROR: s = "连接失败";
		AgentError.RESPONSE_TIMEOUT: s = "响应超时";
		AgentError.RESPONSE_ERROR: s = "响应失败";
		AgentError.LLM_ERROR: s = "LLM 错误";
		_ : s = "[unknown]";
	push_error("ERROR %s: %s" % [
		s,
		m
	]);
	error.emit(e);
#endregion

## 向大模型发送会话请求
## [br]返回 AgentMessageAssistant 表示来自LLM的回复，这个对象会持续更新
func request() -> AgentResponse:
	if (!self.is_opened()) : 
		_push_error(AgentError.NOT_OPENED);
		return null;
	if (config.base_url.is_empty()) : 
		_push_error(AgentError.REQUEST_URL_EMPTY);
		return null;
	
	var response : AgentResponse = AgentResponse.new();
	response.open(config.stream);
	
	var url : String = adapter.generate_url();
	var parsed_url : Dictionary = self._parse_url(url);
	var http_client : HTTPClient = HTTPClient.new();
	
	var _close_client : Callable = func(
			status : AgentResponse.Status = AgentResponse.Status.FAILED \
			) -> void:
		response.close(status);
		http_client.close();
	
	# 读取HTTP响应的异步函数
	var _read_body : Callable = func(streaming : bool = false) -> void:
		if (http_client == null): return;
		var body_buffer : PackedByteArray = PackedByteArray();
		var read_start_msec : int = Time.get_ticks_msec();
		var last_chunk_msec : int = read_start_msec;
		
		# 循环读取响应
		var sse_buffer : String = "";
		while (http_client.get_status() == HTTPClient.STATUS_BODY) :
			http_client.poll();
			var chunk : PackedByteArray = http_client.read_response_body_chunk();
			if (!chunk.is_empty()) :
				if (streaming) : 
					# 流式响应，更新 response
					sse_buffer += chunk.get_string_from_utf8();
					var normalized : String = sse_buffer.replace("\r\n", "\n").replace("\r", "\n");
					var events : Array = normalized.split("\n\n", false);
					
					# 检查 SSE 事件是否完整，不完整则缓存 sse_buffer
					if (!normalized.ends_with("\n\n")) :
						sse_buffer = events.pop_back() if events.size() > 0 else "";
					else : 
						sse_buffer = "";
					
					for event : String in events :
						var data_lines : PackedStringArray = [];
						for raw_line : String in event.split("\n", false) :
							var line : String = raw_line.strip_edges();
							if (line.begins_with("data:")) :
								data_lines.push_back(line.substr(5).strip_edges());
						if (data_lines.is_empty()) : continue;
						
						# 处理结束事件
						var data : String = "\n".join(data_lines).strip_edges();
						if (data == "[DONE]") : 
							continue;
						
						response.update_body(JSON.parse_string(data));
				else : 
					# 非流式响应，将数据缓存到 body_buffer
					body_buffer.append_array(chunk);
				last_chunk_msec = Time.get_ticks_msec();
			
			# 超时处理
			if (Time.get_ticks_msec() - read_start_msec >= (config.body_total_timeout_seconds * 1000.0)) :
				_push_error(AgentError.RESPONSE_TIMEOUT, "响应时间超时");
				_close_client.call();
				break;
			elif (Time.get_ticks_msec() - last_chunk_msec >= (config.body_idle_timeout_seconds * 1000.0)) :
				_push_error(AgentError.RESPONSE_TIMEOUT, "读取响应数据块超时");
				_close_client.call();
				break;
			
			await get_tree().process_frame;
		
		# 非流式响应，将缓存释放到 response
		if (!streaming) : 
			var body : String = body_buffer.get_string_from_utf8();
			response.update_body(JSON.parse_string(body));
			
	# 执行HTTP请求的异步函数
	var _begin_request : Callable = func() -> bool:
		var tls_options : TLSOptions = TLSOptions.client() if parsed_url["tls"] else null;
		var connent_error : Error = http_client.connect_to_host(\
				parsed_url["host"], \
				parsed_url["port"], \
				tls_options);
		if (connent_error == Error.OK):
			var connect_start_msec : int = \
					Time.get_ticks_msec();
			
			# 连接服务器
			while (http_client.get_status() == HTTPClient.STATUS_CONNECTING || http_client.get_status() == HTTPClient.STATUS_RESOLVING) :
				http_client.poll();
				if (Time.get_ticks_msec() - connect_start_msec >= (config.timeout_seconds * 1000.0)) :
					_push_error(AgentError.CONNENT_TIMEOUT);
					_close_client.call();
					return false;
				await get_tree().process_frame;
			if (http_client.get_status() != HTTPClient.STATUS_CONNECTED) :
				_push_error(AgentError.CONNENT_ERROR, str(http_client.get_status()));
				_close_client.call();
				return false;
			
			# 构建请求
			var request_body : String = adapter.generate_body(
					context.histroy_messages,
					context.tool_list,
					config.extra_parameters
					);
			print_rich("[color=orange]请求体构建成功\n[color=white]%s" % [request_body])
			http_client.request(
				HTTPClient.METHOD_POST,
				parsed_url["path"],
				adapter.generate_header(),
				request_body
				);
			
			## 等待响应
			while (http_client.get_status() == HTTPClient.STATUS_REQUESTING) :
				http_client.poll();
				if (Time.get_ticks_msec() - connect_start_msec >= (config.timeout_seconds * 1000.0)) :
					_push_error(AgentError.REQUEST_TIMEOUT);
					_close_client.call();
					return false;
				await get_tree().process_frame;
			
			if (!http_client.has_response()) :
				_push_error(AgentError.RESPONSE_ERROR, "无LLM响应体");
				_close_client.call();
				return false;
			
			# 解析响应
			var response_code : int = http_client.get_response_code();
			if (response_code < 200 || response_code >= 300) :
				# 响应失败
				await _read_body.call(false);
				_push_error(AgentError.RESPONSE_ERROR, str(response.get_body())+"\ncode:"+str(response_code));
				_close_client.call();
				return false;
			else : 
				# 响应成功
				await _read_body.callv([response.stream]);
				_close_client.callv([AgentResponse.Status.FINISHED]);
				return true;
		else : 
			_push_error(AgentError.REQUEST_ERROR, str(connent_error));
			_close_client.call();
			return false;
	
	_begin_request.call();
	
	return response;

func request_message() -> AgentConversationMessages :
	# 解析消息，更新消息对象
	return adapter.phrase_response(request());

func call_tool(assistant_message : AgentMessageAssistant) -> Dictionary[int, AgentMessageToolCall] : 
	if (assistant_message.tool_calls.is_empty()) : 
		return {};
	
	var result : Dictionary[int, AgentMessageToolCall] = {};
	
	for index : int in assistant_message.tool_calls:
		var tool_call : AgentToolCall = assistant_message.tool_calls[index];
		if (!context.tool_list.has(tool_call.name)) : 
			result[index] = tool_actuator.send_error("工具名称 %s 不存在" % [tool_call.name]);
			continue;
		var tool : AgentTool = context.tool_list.get(tool_call.name);
		var tool_call_result : AgentMessageToolCall = tool_actuator.call_tool(tool, tool_call);
		tool_call_result.tool_call_id = tool_call.id;
		result[index] = tool_call_result;
	
	return result;
