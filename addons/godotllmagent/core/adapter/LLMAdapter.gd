@abstract
class_name LLMAdapter;
extends RefCounted;

var config : AgentConfiguration;

func _init(config) -> void:
	self.config = config;

## 构造请求头
@abstract
func generate_header() -> PackedStringArray;

## 构造请求体
@abstract
func generate_body(messages : Array[AgentMessage], \
		tool_list : Dictionary[String, AgentTool], \
		extra_parameters : Dictionary) -> String;


## 构造工具调用错误消息
@abstract
func generate_tool_call_error(error : AgentMessageToolCall) -> String;

## 构造正确的请求路径
@abstract
func generate_url() -> String;

## 解析响应数据
@abstract
func phrase_response(response : AgentResponse) -> AgentConversationMessages;
