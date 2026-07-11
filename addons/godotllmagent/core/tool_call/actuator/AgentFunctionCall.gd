class_name AgentFunctionCall;
extends AgentToolSet;
## 本地Function Call执行器

@export
var tool_list : Dictionary[String, AgentTool] = {};

func _ready() -> void:
	if (!tool_list.is_empty()) : 
		for tool_name : String in tool_list : 
			tool_list[tool_name].owner = self;

## 添加工具到执行器
func add_tool(tool_name : String, tool : AgentTool) -> void: 
	if (tool_list.has(tool_name)) : 
		return;
	tool.owner = self;
	tool_list[tool_name] = tool;

## 获取工具列表
func list_tool() -> Dictionary[String, AgentTool]:
	return tool_list;
