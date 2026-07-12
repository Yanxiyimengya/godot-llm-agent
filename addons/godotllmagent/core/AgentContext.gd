class_name AgentContext;
extends Resource;
## Agent 上下文对象

## 历史对话列表
var histroy_messages : Array[AgentMessage] = [];

## 获取上下文的历史消息列表
func get_context_messages() -> Array[AgentMessage]:
	return histroy_messages;
