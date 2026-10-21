class_name ArenaPerformanceOverlay
extends Label
## Real client frame intervals, never inferred from server latency or video.
var intervals: Array[float] = []
var _refresh := 0.0
var _previous_us := 0
var _mode := ""
func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	z_index = 90
	add_theme_font_size_override("font_size", 12)
	add_theme_color_override("font_shadow_color", Color.BLACK)
	add_theme_constant_override("shadow_offset_x", 1)
	add_theme_constant_override("shadow_offset_y", 1)
func _process(delta: float) -> void:
	visible = ArenaVisualSettings.metrics
	if not visible:
		intervals.clear()
		_previous_us = 0
		return
	var mode := "AO original" if ArenaVisualSettings.uses_original_fx() else "Moderno"
	if mode != _mode:
		_mode = mode
		intervals.clear()
		_previous_us = 0
		_refresh = 0
	var now := Time.get_ticks_usec()
	if _previous_us > 0: intervals.append((now - _previous_us) / 1000.0)
	_previous_us = now
	if intervals.size() > 600: intervals.pop_front()
	if intervals.is_empty(): return
	_refresh += delta
	if _refresh < 0.5: return
	_refresh = 0
	var ordered := intervals.duplicate()
	ordered.sort()
	var p95: float = ordered[maxi(0, ceili(ordered.size() * 0.95) - 1)]
	text = "%s · %d FPS · p95 %.1f ms · draw %d" % [_mode, Engine.get_frames_per_second(), p95, Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME)]
