@abstract
class_name AgentTool;
extends Resource;
## 智能体调用的工具

## 该 AgentTool 的所有者集合
var owner : AgentToolSet;

@abstract
func _get_description() -> String;

@abstract
func _get_properties() -> Array[AgentToolProperty];

@abstract
func _get_required() -> PackedStringArray;

@abstract
func _call(params : Dictionary) -> Variant;

#region 返回结果处理
## 包装工具调用返回值
static func send_result(result : Variant) -> AgentMessageToolCall : 
	var res : AgentMessageToolCall = AgentMessageToolCall.new();
	res.content = str(result);
	return res;

## 包装工具调用返回值，并抛出异常
static func send_error(error_message : Variant) -> AgentMessageToolCall : 
	push_error(error_message);
	return send_result(error_message);
#endregion
