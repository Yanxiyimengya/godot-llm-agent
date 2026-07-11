class_name AgentResponse;
extends RefCounted;
## 当尝试请求 LLM时，LLM 返回的结果
## [br]支持SSE

signal updated();		## 当响应更新时触发
signal finished();		## 当响应成功完成时触发

## LLM 请求状态
enum Status
{
	NONE,				## 无连接
	BODY,				## 表示已经接收到响应体
	FAILED,				## 响应失败
	FINISHED,			## 表示响应已完成
}

## 是否为 SSE 响应
var stream : bool = false;

## 响应状态
var status : AgentResponse.Status = AgentResponse.Status.NONE;

var _response_body : String = ""; # 响应体数据
var _is_opened : bool = false; # 是否打开

## 获取响应状态
func get_status() -> Status: return status;

## 更新响应体消息
func update_body(body : String) -> void:
	if (!_is_opened) : return;
	self.status = AgentResponse.Status.BODY;
	_response_body = body;
	updated.emit();

## 打开此响应对象，重置对象状态，允许更新响应信息
func open(is_stream : bool) -> void:
	self._is_opened = true;
	self.stream = is_stream;
	self.status = AgentResponse.Status.NONE;

## 关闭此响应对象，不再更新请求
func close(status : AgentResponse.Status = \
			AgentResponse.Status.FINISHED) -> void:
	self._is_opened = false;
	if (self.status != status):
		if (status == AgentResponse.Status.FINISHED) :
			finished.emit();
		self.status = status;

func get_body() -> String:
	return _response_body;
