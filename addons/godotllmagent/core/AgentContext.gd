class_name AgentContext;
extends Resource;
## Agent 上下文对象

## 历史对话列表
var histroy_messages : Array[AgentMessage] = [];

## 工具列表 
## [br]格式:工具名称:工具类实例
var tool_list : Dictionary[String, AgentTool] = {};
