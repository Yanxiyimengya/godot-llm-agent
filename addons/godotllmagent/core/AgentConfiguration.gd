class_name AgentConfiguration;
extends Resource;
## 智能体的通用配置文件

## LLM 接口地址
@export var base_url : String = "";

## LLM 密钥
## [br][b]注意[/b] 在任何情况下，都不应该通过检查器直接填写此字段，这会导致信息泄露
@export var api_key : String = "";

## LLM 系统提示词
@export var system_prompt : String = "";

## LLM 额外请求参数
@export var extra_parameters : Dictionary = {};

@export_category("Model")

@export var model : String = ""; ## 使用的模型
@export var stream : bool = false; ## 是否启用 SSE 流
@export var temperature : float = 1.0;
@export var top_p : float = 1.0;
@export var n : int = 1;
@export var max_tokens : int = 0;
@export var stop : PackedStringArray = [];
@export var presence_penalty : float = 0.0;
@export var frequency_penalty : float = 0.0;

@export_category("Network")
@export var connent_timeout_seconds : float = 15.0; ## 连接超时时间（单位：秒）
@export var body_idle_timeout_seconds : float = 30.0; ## 读取请求体超时时间（单位：秒）
@export var body_total_timeout_seconds : float = 120.0; ## 读取请求体总超时时间（单位：秒）
