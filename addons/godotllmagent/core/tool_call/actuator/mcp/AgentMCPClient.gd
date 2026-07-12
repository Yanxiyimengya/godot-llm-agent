@abstract
class_name AgentMCPClient;
extends AgentToolSet;
## 表示 MCP 客户端

# MCP 连接状态
enum MCPStatus {
	CLOSED,
	INITIALIZING,
	READY,
};

var status : MCPStatus = MCPStatus.CLOSED; # MCP 服务状态


func _enter_tree() -> void:
	init_mcp();

func _exit_tree() -> void:
	uninit_mcp();

## 尝试初始化 MCP 服务器
@abstract
func init_mcp() -> void;

## 结束 MCP 服务器
@abstract
func uninit_mcp() -> void;
