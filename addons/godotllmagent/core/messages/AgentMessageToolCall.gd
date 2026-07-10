class_name AgentMessageToolCall;
extends AgentMessage;

## 工具调用ID
var tool_call_id : String = "";

func _init() -> void:
	self.role = AgentMessage.Role.TOOL;
