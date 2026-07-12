class_name AgentSayTool;
extends AgentTool;

func _get_description() -> String:
	return "说一句话，打印在控制台，用户可以看到，支持BBCode格式";

func _get_properties() -> Array[AgentToolProperty]:
	return [
		AgentToolProperty.new("content", "string", "内容，支持BBCode格式"),
	]

func _get_required() -> PackedStringArray:
	return ["content"];

func _call(params : Dictionary) -> Variant:
	print_rich(params["content"]);
	return "success";
