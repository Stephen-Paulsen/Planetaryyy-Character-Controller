extends Control

var rows = {}

@export_group("Global Defaults")
@export var default_color: Color = Color(0, 1, 0.5, 0.2)
@export var label_font_size: int = 10

@export_group("Progress Bar Sizing")
@export var bar_width: float = 58.0
@export var bar_height: float = 6.0
@export var bg_color: Color = Color(0, 1, 0.5, 0.2)

# Helper to position nodes
func _set_or_update_position(node: Control, pos: Vector2):
	if pos != Vector2.ZERO:
		node.position = pos

# --- Corrected Order: Name, Value, Color, Position ---
func update_stat(stat_name: String, value: Variant, color: Color = default_color, pos: Vector2 = Vector2.ZERO):
	if not rows.has(stat_name):
		var rtl = RichTextLabel.new()
		rtl.bbcode_enabled = true
		rtl.fit_content = true
		rtl.custom_minimum_size.x = 250
		add_child(rtl)
		rows[stat_name] = rtl
	
	var node = rows[stat_name]
	_set_or_update_position(node, pos)
	
	# Converts the RGBA Color object to a Hex string for BBCode
	var hex = color.to_html(true) 
	node.text = "[font_size=%d][color=#%s][b]%s:[/b][/color] [color=#ffffff]%s[/color]" % [label_font_size, hex, stat_name, str(value)]

# --- Corrected Order: Name, Value, Color, Position ---
func update_progress(bar_name: String, value: float, color: Color = default_color, pos: Vector2 = Vector2.ZERO):
	if not rows.has(bar_name):
		var container = VBoxContainer.new()
		container.add_theme_constant_override("separation", 2)
		
		var label = RichTextLabel.new()
		label.bbcode_enabled = true
		label.fit_content = true
		
		var pb = ProgressBar.new()
		pb.custom_minimum_size = Vector2(bar_width, bar_height)
		pb.show_percentage = false
		
		# Background Style
		var style_bg = StyleBoxFlat.new()
		style_bg.bg_color = bg_color
		pb.add_theme_stylebox_override("background", style_bg)
		
		container.add_child(label)
		container.add_child(pb)
		add_child(container)
		
		rows[bar_name] = {"container": container, "pb": pb, "label": label}
	
	var row = rows[bar_name]
	_set_or_update_position(row.container, pos)
	
	var hex = color.to_html(true)
	row.label.text = "[font_size=%d][color=#%s][b]%s[/b][/color]" % [label_font_size, hex, bar_name]
	
	# Update Fill Color
	var style_fill = StyleBoxFlat.new()
	style_fill.bg_color = color 
	row.pb.add_theme_stylebox_override("fill", style_fill)
	
	row.pb.value = value
