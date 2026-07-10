class_name AgentConversationMessages;
extends RefCounted;
## 表示智能体一次会话产生的消息

signal updated();		## 消息更新时触发
signal finished();		## 消息响应完成时触发

## 智能体消息
var messages : Dictionary[int, AgentMessageAssistant] = {};

## 获取消息
func get_message(index : int) -> AgentMessageAssistant:
	return messages.get(index, null);
