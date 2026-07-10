extends AgentTool;

func _get_description() -> String:
	return """
以阻塞方式执行给定进程。path 中指定的文件必须存在且可执行。将使用系统路径解析。arguments 按给定顺序使用，用空格分隔，并用引号包裹。
如果提供了 output 数组，则进程的完整 shell 输出，将作为单个 String 元素被追加到 output。如果 read_stderr 为 true，则标准错误流的输出也会被追加到数组中。
在 Windows 上，如果 open_console 为 true 并且进程是控制台应用程序，则会打开一个新的终端窗口。
该方法返回命令的退出代码，如果进程执行失败，则返回 -1。
目前环境是windows
""";

func _get_properties() -> Array[AgentToolProperty]:
	return [
		AgentToolProperty.new("path", "string", ""),
		AgentToolProperty.new("arguments", "array", ""),
		AgentToolProperty.new("output", "array", ""),
		AgentToolProperty.new("read_stderr", "boolean", ""),
		AgentToolProperty.new("open_console", "boolean", ""),
		];
func _get_required() -> PackedStringArray :
	return ["path", "arguments"];

func _call(args : Dictionary) -> Variant:
	var out : Array = [];
	OS.execute(args["path"], args["arguments"], out, false, true);
	print(out);
	return out;
