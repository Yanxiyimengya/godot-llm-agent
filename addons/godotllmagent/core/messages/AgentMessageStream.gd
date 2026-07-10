class_name AgentMessageStream;
extends AgentMessageAssistant;

var tool_arguments_cache : String = "";

func _init() -> void:
	self.role = AgentMessage.Role.ASSISTANT;
