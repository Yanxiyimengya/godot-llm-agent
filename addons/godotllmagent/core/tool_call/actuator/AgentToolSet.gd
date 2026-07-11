@icon("res://addons/godotllmagent/imgs/AgentToolSet.svg")
@abstract
class_name AgentToolSet;
extends Node;
## 给予 Agent 工具声明的组件
## [br]需要放在 AgentClient 节点下方

## 获取工具列表
@abstract
func list_tool() -> Dictionary[String, AgentTool];
