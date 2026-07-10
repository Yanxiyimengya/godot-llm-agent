extends AgentTool;

func _get_description() -> String:
	return "选择是否按下拉杆";

func _get_properties() -> Array[AgentToolProperty]:
	return [
		AgentToolProperty.new("操作", "boolean", "是否拉下拉杆"),
		];

func _get_required() -> PackedStringArray :
	return [];

func _call(args : Dictionary) -> Variant:
	return "SUCCESS";
