class_name AgentToolCall;
extends Resource;
## 表示 Agent 请求执行的工具调用信息

## 工具调用的ID
@export var id : String = "";

## 工具名称
@export var name : String = "";

## 工具参数
@export var arguments : String = "";

func _init(
		_id : String = "",
		_name : String = ""
		) -> void:
	id = _id;
	name = _name;

## 检查当前是否为一个有效的 ToolCall
func is_valid() -> bool : 
	return !self.id.is_empty() && !self.name.is_empty();
