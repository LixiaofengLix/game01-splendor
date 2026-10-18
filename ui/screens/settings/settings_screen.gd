## 设置屏（15 / 16 / 关于）：顶栏页签 + 内容页。
## 改动立即写 user://ui_settings.json（UiSettings 的 setter）；大模型配置档由 UiLlmBridge 读写。
class_name UiSettingsScreen
extends Control

signal back_requested

const TAB_GENERAL: String = "general"
const TAB_LLM: String = "llm"
const TAB_NET: String = "net"
const TAB_ABOUT: String = "about"
const TAB_KEYS: Array[String] = [TAB_GENERAL, TAB_LLM, TAB_NET, TAB_ABOUT]
const TAB_LABELS: Array[String] = ["通用", "大模型", "联网", "关于"]

var _back_button: UiButton
var _tab_segment: UiSegmented
var _page_host: Control
var _general: UiSettingsGeneralPage
var _llm: UiSettingsLlmPage
var _about: UiSettingsAboutPage
var _net: Control
var _current_tab: String = TAB_GENERAL
var _options: Dictionary = {}


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_build()
	if not _options.is_empty():
		_apply_options(_options)


## options = {from_table: bool, usage: {profile_id: seat_count}}。
func configure(options: Dictionary) -> void:
	_options = options.duplicate(true)
	if is_node_ready():
		_apply_options(_options)


func _apply_options(options: Dictionary) -> void:
	if _llm != null:
		var usage: Variant = options.get("usage", {})
		_llm.set_usage(usage if usage is Dictionary else {})


# ---------------------------------------------------------------- 布局

func _build() -> void:
	_build_topbar()
	var body := MarginContainer.new()
	body.name = "Body"
	body.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.offset_top = 44
	body.add_theme_constant_override("margin_left", 24)
	body.add_theme_constant_override("margin_top", 18)
	body.add_theme_constant_override("margin_right", 24)
	body.add_theme_constant_override("margin_bottom", 20)
	add_child(body)

	_page_host = Control.new()
	_page_host.name = "PageHost"
	_page_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	body.add_child(_page_host)

	_general = UiSettingsGeneralPage.new()
	_general.name = "GeneralPage"
	_page_host.add_child(_general)

	_llm = UiSettingsLlmPage.new()
	_llm.name = "LlmPage"
	_llm.visible = false
	_page_host.add_child(_llm)

	_net = _make_net_page()
	_page_host.add_child(_net)

	_about = UiSettingsAboutPage.new()
	_about.name = "AboutPage"
	_about.visible = false
	_page_host.add_child(_about)

	open_tab(TAB_GENERAL)


func _build_topbar() -> void:
	var bar := Control.new()
	bar.name = "TopBar"
	bar.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	bar.offset_bottom = 44
	bar.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(bar)

	var background := ColorRect.new()
	background.color = UiPalette.HUD
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(background)
	var highlight := ColorRect.new()
	highlight.color = UiPalette.HUD_HIGHLIGHT
	highlight.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	highlight.offset_bottom = 2
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(highlight)
	var border := ColorRect.new()
	border.color = UiPalette.HUD_BORDER
	border.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	border.offset_top = -4
	border.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(border)

	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 14
	row.offset_right = -14
	row.add_theme_constant_override("separation", 12)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	bar.add_child(row)

	_back_button = UiButton.new()
	_back_button.name = "BackButton"
	_back_button.variant = &"hud"
	_back_button.size_key = &"sm"
	_back_button.text = "‹ 返回"
	_back_button.focus_mode = Control.FOCUS_NONE
	_back_button.pressed.connect(func() -> void: back_requested.emit())
	row.add_child(_back_button)

	var title := Label.new()
	title.text = "设置"
	title.add_theme_color_override("font_color", UiPalette.CREAM)
	title.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(title)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(spacer)

	_tab_segment = UiSegmented.new()
	_tab_segment.name = "Tabs"
	_tab_segment.items = TAB_LABELS
	# 联网界面在阶段 6 / U8 之前不开放。
	_tab_segment.disabled_indices = [TAB_KEYS.find(TAB_NET)]
	_tab_segment.selected_index = TAB_KEYS.find(TAB_GENERAL)
	_tab_segment.selected_changed.connect(func(index: int) -> void:
		open_tab(TAB_KEYS[clampi(index, 0, TAB_KEYS.size() - 1)]))
	row.add_child(_tab_segment)


func _make_net_page() -> Control:
	var page := Control.new()
	page.name = "NetPage"
	page.visible = false
	page.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	page.add_child(center)
	var card := UiNoticeCard.new()
	center.add_child(card)
	var fill := func() -> void:
		card.set_content(2, "联网设置", "联网大厅与掉线接管会在后续版本开放。")
	if card.is_node_ready():
		fill.call()
	else:
		card.ready.connect(fill, CONNECT_ONE_SHOT)
	return page


func open_tab(key: String) -> void:
	if not TAB_KEYS.has(key):
		return
	_current_tab = key
	_general.visible = key == TAB_GENERAL
	_llm.visible = key == TAB_LLM
	_net.visible = key == TAB_NET
	_about.visible = key == TAB_ABOUT
	if _tab_segment != null and _tab_segment.selected_index != TAB_KEYS.find(key):
		_tab_segment.selected_index = TAB_KEYS.find(key)
	if key == TAB_LLM and _llm != null:
		_llm.refresh()


# ---------------------------------------------------------------- 测试用

func current_tab() -> String:
	return _current_tab


func tab_segment() -> UiSegmented:
	return _tab_segment


func general_page() -> UiSettingsGeneralPage:
	return _general


func llm_page() -> UiSettingsLlmPage:
	return _llm


func about_page() -> UiSettingsAboutPage:
	return _about


func back_button() -> UiButton:
	return _back_button
