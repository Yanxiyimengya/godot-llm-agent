class_name AgentLocalMCPClient;
extends AgentMCPClient;
## 本地 MCP 客户端

signal mcp_initialized;
signal mcp_notification(message : Dictionary);
signal mcp_log(log : String);

## 启动本地 MCP 服务的命令
@export 
var command : String = "";

## 启动参数
@export 
var args : PackedStringArray;

@export_group("Client")
## MCP 客户端名称
@export 
var client_name : String = "";
## MCP 客户端版本
@export 
var client_version : String = "";
## MCP 协议版本号
@export 
var protoco_version : String = "";

var _mcp_protoco_version : String;
var _mcp_stdio : FileAccess;
var _mcp_err : FileAccess;
var _mcp_server_pid : int = -1;
var _next_request_id : int = 0;
var _pending_requests : Dictionary[int, MCPRequest] = {};
var _mcp_tools : Dictionary[String, AgentTool] = {};

# MCP 请求对象
class MCPRequest:
	extends RefCounted;
	signal completed(message : Dictionary);
	var id : int = -1;

func init_mcp() -> void : 
	if (status != MCPStatus.CLOSED) : return;
	
	status = MCPStatus.INITIALIZING;
	
	var execute_command : String = command;
	var execute_args : PackedStringArray = args;
	
	if (OS.get_name() == "Windows") : 
		execute_command = "cmd.exe";
		var command_line : String = command;
		for argument : String in args :
			command_line += " \"%s\"" % [
				argument.replace("\"", "\"\"")
			];
		execute_args = PackedStringArray([
			"/d",
			"/c",
			command_line,
		]);
	
	var result : Dictionary = OS.execute_with_pipe(
		execute_command,
		execute_args,
		false
	);
	if (result.is_empty()) : 
		status = MCPStatus.CLOSED;
		return;
	
	_mcp_stdio = result.get("stdio");
	_mcp_err = result.get("stderr");
	_mcp_server_pid = result.get("pid");
	
	if (_mcp_stdio == null) : 
		uninit_mcp();
		return;
	
	# 发送 initialize request
	var init_message : Dictionary = await send_request(
		"initialize",
		{
			"protocolVersion" : protoco_version,
			"capabilities" : {},
			"clientInfo" : {
				"name" : client_name,
				"version" : client_version,
			},
		}
	);
	if (!init_message.has("result")) : 
		uninit_mcp();
		return;
	else : 
		_mcp_protoco_version = \
				init_message["result"]["protocolVersion"];
	
	# 发送 initialize notification
	send_notification("notifications/initialized", {});
	
	await _get_tool_list();
	
	status = MCPStatus.READY;
	mcp_initialized.emit();


func uninit_mcp() -> void : 
	status = MCPStatus.CLOSED;
	
	for request_id : int in _pending_requests :
		var pending : MCPRequest = _pending_requests[request_id];
		pending.completed.emit({});
	_pending_requests.clear();
	_mcp_tools.clear();
	
	if (_mcp_stdio != null) : _mcp_stdio.close();
	if (_mcp_err != null) : _mcp_err.close();
	
	if (_mcp_server_pid > 0 && \
			OS.is_process_running(_mcp_server_pid)) : 
		OS.kill(_mcp_server_pid);
	
	_mcp_stdio = null;
	_mcp_err = null;
	_mcp_server_pid = -1;


func list_tool() -> Dictionary[String, AgentTool] :
	if (status == MCPStatus.INITIALIZING) : 
		await mcp_initialized;
	if (status != MCPStatus.READY) : return {};
	return _mcp_tools;

## 调用 MCP 工具
func mcp_call(tool_name : String, \
		params : Dictionary) -> Variant : 
	if (status != MCPStatus.READY) : 
		return {};
	
	var result : Dictionary = await send_request(
		"tools/call",
		{
			"name" : tool_name,
			"arguments" : params,
		}
	);
	return result;

func _process(delta : float) -> void:
	if (_mcp_stdio == null) : return;
	
	while (_mcp_stdio.get_length() > 0) : 
		var line : String = _mcp_stdio.get_line();
		if (line.is_empty()) : 
			continue;
		
		var json : JSON = JSON.new();
		var error : Error = json.parse(line);
		if (error != Error.OK) : 
			##DANGER
			continue;
		if (!(json.data is Dictionary)) : continue;
		var message : Dictionary = json.data;
		
		if (message.has("id") && \
				(message.has("result") || message.has("error"))) : 
			var request_id : int = int(message["id"]);
			
			if (_pending_requests.has(request_id)) : 
				var pending : MCPRequest = \
						_pending_requests[request_id];
				_pending_requests.erase(request_id);
				pending.completed.emit(message);
			continue;
		
		if (message.has("method")) : 
			if (message.has("id")) : 
				_handle_server_request(message);
			else : 
				_handle_notification(message);
			continue;
	
	# 监听 stderr 流
	if (_mcp_err != null) : 
		while (_mcp_err.get_length() > 0) : 
			var line : String = _mcp_err.get_line();
			if (line.is_empty()) : continue;
			mcp_log.emit(line);

## 向 MCP 服务器发送请求
func send_request(method : String, \
		params : Variant) -> Dictionary:
	if (_mcp_stdio == null) : 
		return {};
	
	_next_request_id += 1;
	var request_id : int = _next_request_id;
	
	var pending : MCPRequest = MCPRequest.new();
	pending.id = request_id;
	_pending_requests[request_id] = pending;
	
	var json_rpc : JSONRPC = JSONRPC.new();
	var request : Dictionary = json_rpc.make_request(
		method,
		params,
		request_id
	);
	
	var json_str : String = JSON.stringify(request) + "\n";
	_mcp_stdio.store_string(json_str);
	
	if (_mcp_stdio.get_error() != OK) : 
		_pending_requests.erase(request_id);
		push_error("写入MCP管道失败");
		return {};
	
	_mcp_stdio.flush();
	
	var result : Dictionary = await pending.completed;
	return result;


## 向本地 MCP 服务器发送 JSON RPC 消息
func send_notification(method : String, \
		params : Variant) -> void:
	if (_mcp_stdio == null) : return;
	
	var request : Dictionary = {
		"jsonrpc" : "2.0",
		"method" : method,
		"params" : params,
	};
	
	var json_str : String = JSON.stringify(request) + "\n";
	_mcp_stdio.store_string(json_str);
	
	if (_mcp_stdio.get_error() != OK) : 
		push_error("写入MCP管道失败");
		return;
	
	_mcp_stdio.flush();


## 处理 MCP Notification
func _handle_notification(message : Dictionary) -> void:
	var method : String = message.get("method", "");
	match (method) :
		"notifications/tools/list_changed":
			await _get_tool_list();
		_: pass;
	
	mcp_notification.emit(message);


## 处理 MCP Server Request
func _handle_server_request(message : Dictionary) -> void:
	var request_id : int = int(message.get("id", -1));
	var method : String = message.get("method", "");
	push_warning(
		"暂不支持 MCP Server Request: %s, id: %d" % [
			method,
			request_id,
		]
	);

## 获取 MCP 工具列表
func _get_tool_list() -> void : 
	var response : Dictionary = await send_request(
		"tools/list",
		{}
	);
	
	if (!response.has("result")) : 
		return;
	
	var response_result : Dictionary = \
			response.get("result", {});
	
	if (!response_result.has("tools")) : 
		return;
	
	var tools : Array = response_result.get("tools", []);
	var new_tools : Dictionary[String, AgentTool] = {};
	
	for tool_declear : Dictionary in tools : 
		var tool_name : String = \
				tool_declear.get("name", "");
		var tool_desc : String = \
				tool_declear.get("description", "");
		
		if (tool_name.is_empty()) : 
			continue;
		
		var tool_properties : Dictionary = {};
		var tool_required : Array = [];
		
		if (tool_declear.has("inputSchema")) : 
			var schema : Dictionary = \
					tool_declear["inputSchema"];
			tool_properties = \
					schema.get("properties", {});
			tool_required = \
					schema.get("required", []);
		
		var tool : AgentMCPTool = AgentMCPTool.new(
			tool_name,
			tool_desc,
			tool_properties,
			tool_required
		);
		tool.owner = self;
		new_tools[tool_name] = tool;
	
	_mcp_tools = new_tools;
