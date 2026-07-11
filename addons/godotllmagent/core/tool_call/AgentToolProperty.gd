class_name AgentToolProperty;
extends Resource;
## 工具调用的参数定义

@export var name : String = ""; 		## 参数名称

@export var type : String = ""; 		## 参数类型

@export var description : String = ""; 	## 参数描述

func _init(name : String, type : String, descript : String) :
	self.name = name;
	self.type = type;
	self.description = descript;
