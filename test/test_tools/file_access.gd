extends AgentTool
class_name AgentFileAccessTool;

# 允许访问的根目录（可根据实际情况在构造函数或初始化时设置）
var _base_directory: String = "res://"  # 默认使用 Godot 的用户数据目录，安全隔离

# 设置允许访问的根目录（如果需要外部配置）
func set_base_directory(path: String) -> void:
	_base_directory = path


func _get_description() -> String:
	return "读写指定文件夹下的文件（仅限安全目录）"


func _get_properties() -> Array[AgentToolProperty]:
	return [
		AgentToolProperty.new("path", "string", "文件路径（相对于安全根目录）"),
		AgentToolProperty.new("p", "string", "操作类型，'r' 读取，'w' 写入"),
		AgentToolProperty.new("content", "string", "写入时的文件内容（写入时必填）"),
	]


func _get_required() -> PackedStringArray:
	return ["path", "p"]


func _call(args: Dictionary) -> Variant:
	# 1. 基础参数提取与校验
	var op: String = args.get("p", "")
	var raw_path: String = args.get("path", "")
	
	if op != "r" and op != "w":
		return _error("无效的操作参数，必须是 'r' 或 'w'")
	
	if raw_path.is_empty():
		return _error("文件路径不能为空")
	
	# 2. 路径安全校验：防止目录遍历攻击
	var safe_path := _sanitize_path(raw_path)
	if safe_path.is_empty():
		return _error("路径包含非法字符或试图访问上级目录")
	
	var full_path := _base_directory.path_join(safe_path)
	
	# 3. 执行具体操作
	match op:
		"r":
			return _read_file(full_path)
		"w":
			var content: String = args.get("content", "")
			return _write_file(full_path, content)
		_:
			return _error("未知操作")  # 实际上不会执行到这里


# ---------- 私有辅助方法 ----------

func _sanitize_path(path: String) -> String:
	# 去除开头的 '.' 或 '../' 等危险字符
	var cleaned := path.replace("\\", "/")  # 统一分隔符
	# 如果包含 ".." 则拒绝
	if cleaned.find("..") != -1:
		return ""
	# 如果以 "/" 或 "./" 开头，去除它们
	if cleaned.begins_with("/"):
		cleaned = cleaned.substr(1)
	if cleaned.begins_with("./"):
		cleaned = cleaned.substr(2)
	# 如果为空或只剩下 "." 则拒绝
	if cleaned.is_empty() or cleaned == ".":
		return ""
	return cleaned


func _read_file(path: String) -> Variant:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return _error("无法打开文件进行读取，请检查路径或权限")
	
	var content := file.get_as_text()  # 默认 UTF-8
	file.close()
	return {"success": true, "content": content, "path": path}


func _write_file(path: String, content: String) -> Variant:
	# 确保目录存在
	var dir := FileAccess.open(path.get_base_dir(), FileAccess.READ)
	if dir == null:
		# 目录不存在，尝试创建
		DirAccess.make_dir_recursive_absolute(path.get_base_dir());
	
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		return _error("无法打开文件进行写入，请检查目录权限")
	
	file.store_string(content)
	file.close()
	return {"success": true, "message": "文件写入成功", "path": path}


func _error(msg: String) -> Dictionary:
	return {"error": msg}
