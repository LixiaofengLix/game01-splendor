## 异常弹窗：21 启动时数据校验失败、22 存档无法读取。
## 由应用入口加到弹窗层；关闭时发 closed，数据失败页的“退出”发 exit_requested。
class_name UiErrorModal
extends Control

signal closed
signal exit_requested
## 22 的【读到第 N 步为止】（U6）：参数是从头读到的步数。
signal resume_until_requested(step: int)

var _frame: UiModalFrame
var _errors_text: String = ""
var _resume_until_button: UiButton = null


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP

	var scrim := ColorRect.new()
	scrim.name = "Scrim"
	scrim.color = UiPalette.SCRIM
	scrim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(scrim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	_frame = UiModalFrame.new()
	_frame.name = "ErrorFrame"
	_frame.preferred_width = 420
	_frame.title = "出错了"
	center.add_child(_frame)


## 21：启动时数据校验失败，不进主菜单。
func setup_data_errors(errors: Array[String]) -> void:
	_errors_text = "\n".join(errors)
	_frame.title = "游戏数据有问题，没法开局"
	_frame.set_tag("数据校验失败", &"red")
	var body: VBoxContainer = _frame.body()

	var mascot_row := HBoxContainer.new()
	mascot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(mascot_row)
	mascot_row.add_child(UiAssets.mascot_icon(-1, 64))

	var list := VBoxContainer.new()
	list.name = "ErrorList"
	list.add_theme_constant_override("separation", 4)
	body.add_child(list)
	for message: String in errors:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)
		list.add_child(row)
		var bullet := Label.new()
		bullet.text = "·"
		bullet.add_theme_color_override("font_color", UiPalette.DANGER)
		row.add_child(bullet)
		var split: int = message.find("：")
		if split > 0:
			var file_label := Label.new()
			file_label.text = message.substr(0, split + 1)
			file_label.add_theme_color_override("font_color", UiPalette.INK)
			file_label.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
			row.add_child(file_label)
			var rest := Label.new()
			rest.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			rest.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			rest.add_theme_color_override("font_color", UiPalette.DANGER)
			rest.text = message.substr(split + 1)
			row.add_child(rest)
		else:
			var label := Label.new()
			label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			label.add_theme_color_override("font_color", UiPalette.DANGER)
			label.text = message
			row.add_child(label)

	var description := Label.new()
	description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	description.add_theme_color_override("font_color", UiPalette.INK_2)
	description.text = "启动时会检查卡表、贵族、规则和电脑配置，有一项不对就不让开局，免得打到一半出错。"
	body.add_child(description)

	var copy := UiButton.new()
	copy.name = "ErrorCopy"
	copy.variant = &"ghost"
	copy.text = "复制错误"
	copy.focus_mode = Control.FOCUS_NONE
	copy.pressed.connect(func() -> void:
		DisplayServer.clipboard_set(_errors_text)
		copy.text = "已复制")
	_frame.add_action(copy)

	var quit := UiButton.new()
	quit.name = "ErrorQuit"
	quit.variant = &"dark"
	quit.text = "退出"
	quit.focus_mode = Control.FOCUS_NONE
	quit.pressed.connect(func() -> void: exit_requested.emit())
	_frame.add_action(quit)


## 22：存档读不了。reason 取 UiSaveEntry.REASON_*；detail 是原始错误，放在“详细信息”里。
## fail_step 是重放失败的那一步；大于 1 时提供【读到第 N-1 步为止】。
func setup_save_error(reason: String, detail: String = "", fail_step: int = 0) -> void:
	_frame.title = "这个存档读不了"
	var reason_text: String = "无法读取"
	var explanation: String = ""
	match reason:
		UiSaveEntry.REASON_VERSION_TOO_NEW:
			reason_text = "版本太新"
			explanation = "这个存档由更新版本的游戏保存，升级后才能读取。"
		UiSaveEntry.REASON_CORRUPT:
			reason_text = "文件损坏"
			explanation = "文件内容不完整或不是存档。"
		UiSaveEntry.REASON_VERIFY_FAILED:
			reason_text = "重放校验失败"
			if fail_step > 0:
				explanation = "重放到第 %d 步时，局面和存档记录的不一样。" % fail_step
			else:
				explanation = "重放完成后，局面和存档记录的不一样。"
			explanation += "通常是卡表或规则改过数值。存档文件没有动，换回原来的数据就能读。"
		_:
			reason_text = "不认识的类型"
			explanation = "文件是有效的 JSON，但不是认识的存档类型。"
	_frame.set_tag(reason_text, &"red")
	var body: VBoxContainer = _frame.body()

	var mascot_row := HBoxContainer.new()
	mascot_row.alignment = BoxContainer.ALIGNMENT_CENTER
	body.add_child(mascot_row)
	mascot_row.add_child(UiAssets.mascot_icon(1, 64))

	var explanation_label := Label.new()
	explanation_label.name = "SaveErrorText"
	explanation_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explanation_label.text = explanation
	body.add_child(explanation_label)

	if not detail.is_empty():
		var detail_label := Label.new()
		detail_label.name = "SaveErrorDetail"
		detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		detail_label.add_theme_color_override("font_color", UiPalette.INK_3)
		detail_label.text = "详细信息：" + detail
		detail_label.visible = false
		body.add_child(detail_label)
		var toggle := UiButton.new()
		toggle.name = "SaveErrorDetailToggle"
		toggle.variant = &"quiet"
		toggle.size_key = &"sm"
		toggle.text = "详细信息"
		toggle.focus_mode = Control.FOCUS_NONE
		toggle.pressed.connect(func() -> void:
			detail_label.visible = not detail_label.visible
			toggle.text = "收起详细信息" if detail_label.visible else "详细信息")
		_frame.add_action(toggle)

	if reason == UiSaveEntry.REASON_VERIFY_FAILED and fail_step > 1:
		_resume_until_button = UiButton.new()
		_resume_until_button.name = "SaveErrorResumeUntil"
		_resume_until_button.variant = &"ghost"
		_resume_until_button.text = "读到第 %d 步为止" % (fail_step - 1)
		_resume_until_button.focus_mode = Control.FOCUS_NONE
		_resume_until_button.pressed.connect(
				func() -> void: resume_until_requested.emit(fail_step - 1))
		_frame.add_action(_resume_until_button)

	var back := UiButton.new()
	back.name = "SaveErrorBack"
	back.variant = &"ghost"
	back.text = "返回列表"
	back.focus_mode = Control.FOCUS_NONE
	back.pressed.connect(func() -> void: closed.emit())
	_frame.add_action(back)


func resume_until_button() -> UiButton:
	return _resume_until_button


func frame() -> UiModalFrame:
	return _frame
