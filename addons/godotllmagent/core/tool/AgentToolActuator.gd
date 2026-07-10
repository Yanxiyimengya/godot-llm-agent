class_name AgentToolActuator;
extends Node;

func send_result(result : Variant) -> AgentMessageToolCall : 
	var res : AgentMessageToolCall = AgentMessageToolCall.new();
	res.content = str(result);
	return res;

func send_error(error_message : Variant) -> AgentMessageToolCall : 
	push_error(error_message);
	return send_result(error_message);

func call_tool(tool : AgentTool, \
		tool_call : AgentToolCall) -> AgentMessageToolCall:
	var args : Dictionary = JSON.parse_string(tool_call.arguments);
	if (!_validate_arguments(tool, args)) : 
		return send_error("参数错误");
	return send_result(tool._call(args));

## 验证参数有效性
func _validate_arguments(tool : AgentTool, arguments : Dictionary) -> bool:
	var parameters : Array[AgentToolProperty] = tool._get_properties();
	
	# 验证参数输入
	if (parameters.is_empty()) : 
		return false;
	var required_values : PackedStringArray = tool._get_required();
	for required_name : String in required_values :
		if (!arguments.has(required_name)) :
			return false;
	
	return true;
