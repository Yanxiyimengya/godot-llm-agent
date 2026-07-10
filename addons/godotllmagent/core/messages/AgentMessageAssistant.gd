class_name AgentMessageAssistant;
extends AgentMessage;

## 智能体请求执行的工具调用信息列表
@export var tool_calls : Dictionary[int, AgentToolCall] = {};

## 智能体思考消息
@export var reasoning_content : String = "";

## 是否为流式消息
@export var stream : bool = false;

func _init() -> void:
	self.role = AgentMessage.Role.ASSISTANT;
