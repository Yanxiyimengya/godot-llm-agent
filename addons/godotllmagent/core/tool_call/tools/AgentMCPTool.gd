class_name AgentMCPTool;
extends AgentTool;
## 来自 MCP Server 的远程工具

var name : String;
var description : String;
var properties : Array[AgentToolProperty];
var required : PackedStringArray;

func _init(
		n : String,\
		desc: String, \
		props: Dictionary,\
		req : PackedStringArray) -> void:
	name = n;
	description = desc;
	required = req;
	for prop_name : String in props : 
		var prop_info : Dictionary = props[prop_name];
		var prop : AgentToolProperty = AgentToolProperty.new(
			prop_name,
			prop_info.get("type", ""),
			prop_info.get("description", ""),
		);
		properties.push_back(prop);
	
func _get_description() -> String : 
	return description;

func _get_properties() -> Array[AgentToolProperty] : 
	return properties;

func _get_required() -> PackedStringArray : 
	return required;

func _call(params : Dictionary) -> Variant : 
	if (!owner) : return null;
	return await owner.mcp_call(self.name, params);
