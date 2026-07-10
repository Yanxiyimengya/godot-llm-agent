@abstract
class_name AgentTool;
extends Resource;
## 智能体调用的工具

@abstract
func _get_description() -> String;

@abstract
func _get_properties() -> Array[AgentToolProperty];

@abstract
func _get_required() -> PackedStringArray;

@abstract
func _call(args : Dictionary) -> Variant;
