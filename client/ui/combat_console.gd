class_name CombatConsole
extends RichTextLabel

signal message_added(entry: Dictionary)

const MAX_MESSAGES := 200
const CHANNEL_COLORS := {
	"system": Color("aab3c2"),
	"chat": Color("c3daf7"),
	"damage": Color("ff9992"),
	"healing": Color("9de5a5"),
	"mana": Color("9bc9ff"),
	"death": Color("ffc472"),
}

var entries: Array[Dictionary] = []
var channel_filter := "all"


func _ready() -> void:
	bbcode_enabled = false
	focus_mode = Control.FOCUS_NONE
	selection_enabled = true
	scroll_following = true
	add_theme_font_size_override("normal_font_size", 14)
	# Scrollbars must not capture movement or attack keys after a click.
	get_v_scroll_bar().focus_mode = Control.FOCUS_NONE


func append_message(message: String, channel: String = "system") -> void:
	var entry := {"text": message, "channel": channel}
	entries.append(entry)
	if entries.size() > MAX_MESSAGES:
		entries.pop_front()
		_rebuild()
	elif _matches_filter(entry):
		_append_entry(entry)
	message_added.emit(entry)


func set_channel_filter(value: String) -> void:
	if value not in ["all", "combat", "system"]:
		return
	channel_filter = value
	_rebuild()


func clear_session() -> void:
	entries.clear()
	clear()


func _matches_filter(entry: Dictionary) -> bool:
	if channel_filter == "combat":
		return entry.channel not in ["system","chat"]
	return channel_filter == "all" or entry.channel == "system"


func _append_entry(entry: Dictionary) -> void:
	push_color(CHANNEL_COLORS.get(entry.channel, CHANNEL_COLORS.system))
	# Names and messages are plain text, never interpreted as BBCode.
	add_text(str(entry.text) + "\n")
	pop()


func _rebuild() -> void:
	clear()
	for entry in entries:
		if _matches_filter(entry):
			_append_entry(entry)
