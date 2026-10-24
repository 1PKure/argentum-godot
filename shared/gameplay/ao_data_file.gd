class_name AODataFile
extends RefCounted


static func read_sections(path: String) -> Dictionary:
	var sections: Dictionary = {}
	var section := ""
	for raw_line in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw_line.strip_edges()
		if line.is_empty() or line.begins_with("'") or line.begins_with(";") or line.begins_with("#"):
			continue
		if line.begins_with("[") and line.contains("]"):
			section = line.substr(1, line.find("]") - 1)
			sections[section] = {}
		elif not section.is_empty() and line.contains("="):
			var split := line.find("=")
			sections[section][line.substr(0, split).strip_edges()] = line.substr(split + 1).strip_edges()
	return sections
