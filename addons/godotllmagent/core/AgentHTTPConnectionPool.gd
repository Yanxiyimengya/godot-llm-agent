class_name AgentHTTPConnectionPool;
extends RefCounted;
## 智能体的 HTTP 连接池
## [br]不过，这个可能永远不会使用

var _list : Dictionary[HTTPClient, bool] = {};
var _pool : Array[HTTPClient] = [];

## 构造函数，初始化 count 个连接
func _init(count : int = 0) -> void:
	if (count > 0) : 
		_pool.resize(count);
		for i : int in count: _pool[i] = HTTPClient.new();

## 获取一个有效的 HTTPClient 
func get_http_client() -> HTTPClient:
	var _client : HTTPClient;
	if (_pool.is_empty()) : 
		_client = HTTPClient.new();
		_list[_client] = true;
	else : 
		_client = _pool.pop_back();
		_client.close();
	return _client;

## 将 HTTPClient 回收进池
func delete_http_client(client : HTTPClient) -> void:
	if (client in _list) : 
		_list.erase(client);
		_pool.push_back(client);
		client.close();
