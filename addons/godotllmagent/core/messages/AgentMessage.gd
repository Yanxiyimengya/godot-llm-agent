class_name AgentMessage;
extends Resource;
## 智能体对话的消息

## 消息角色
enum Role
{
	UNKNOWN,
	USER,
	SYSTEM,
	ASSISTANT,
	TOOL,
}

## 消息的角色信息
@export
var role : Role = Role.USER;

## 消息的内容
@export
var content : String = "";
