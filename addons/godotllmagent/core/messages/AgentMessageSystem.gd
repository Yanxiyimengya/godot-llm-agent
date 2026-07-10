class_name AgentMessageSystem;
extends AgentMessage;

func _init() -> void:
	self.role = AgentMessage.Role.SYSTEM;
