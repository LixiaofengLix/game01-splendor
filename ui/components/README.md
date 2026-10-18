# ui/components/

可复用的界面零件。零件只接收“显示数据”（颜色、数字、`card_id` + `CardCatalog`、状态布尔值），
不认识视图字典；视图到零件的转换在 `screens/` 里做。

- `frame.gd` — `UiFrame`：9 宫格框 + 底色 + 可选硬投影 / 顶部内高光 / 重点色条 / 左侧 4px 内条，
  内容放进 `content`。
- `button.gd` — `UiButton`：6 种配色（accent / dark / ghost / quiet / danger / hud）× sm / 默认 / lg；
  悬停抬起、按下压扁；`preview_state` 只给陈列场景用。
- `menu_button.gd` — `UiMenuButton`：主菜单大按钮（24 号主文字 + 12 号副文字 + `›`）。
- `segmented.gd` — `UiSegmented`：分段选择，`selected_changed(index)`。
- `switch.gd` — `UiSwitch`：40×24 像素开关；代码里切换用 `set_on()`。
- `input_field.gd` — `UiInput`：像素输入框。
- `tag.gd` — `UiTag`：默认 / dark / mint / orange / purple / red 6 种配色；`in_hud` 切到顶栏深底配色。
- `kbd.gd` — `UiKbd`：键帽。
- `progress_bar.gd` — `UiProgressBar`：高 6，带 8px 周期竖纹。
- `spinner.gd` — `UiSpinner`：12×12 四帧像素转圈。
- `list_row.gd` — `UiListRow`：列表行（普通 / 选中）。
- `modal_frame.gd` — `UiModalFrame`：大框弹窗，`body()` 加内容、`add_action()` 加按钮。
- `toast.gd` — `UiToast`：2.5 秒自动消失的成功提示。
- `notice_card.gd` — `UiNoticeCard`：右栏持续状态提示卡。
- `gem_chip.gd` — `UiGemChip`：圆形筹码，lg / md / sm / xs，满币 / 空心 / 已选 / 待弃 / bare。
- `bonus_tile.gd` — `UiBonusTile`：方形折扣块，noble / opp / base / big / md。
- `cost_pill.gd` — `UiCostPill`：花费药丸，普通 / 迷你。
- `dev_card.gd` — `UiDevCard`：市场 / 迷你发展卡，含可买、差 N、选中、光晕、对手头像、空位、牌背、盲抽标签；
  `show_status` 控制“可买 / 差 N”标签是否显示（不是我的回合时仍保留悬停缺口条）；
  `back_label` 是牌背中间的文字（补牌翻面时置空，默认“盲抽”）。
- `deck_pile.gd` — `UiDeckPile`：牌堆（有牌 / 已空 / 选中）。
- `noble_tile.gd` — `UiNobleTile`：贵族牌（市场 / 大号 / 选中）。
- `card_ref.gd` — `UiCardRef`：日志里的卡牌引用小块。
- `hud.gd` — `UiHud`：高 44 的顶栏（标题、人数轮数、终局标签、回合胶囊、规则 / 菜单按钮）。
- `turn_pill.gd` — `UiTurnPill`：回合胶囊（轮到我 / 等别人 + 转圈 / 纯文字）。
- `card_popover.gd` — `UiCardPopover`：选中卡 / 牌堆后的浮层（宽 272），显示支付预览、
  “需要 / 已有”、买后变化与购买 / 预留按钮；`mode` 取 `market` / `deck` / `reserved`。
- `bank_column.gd` — `UiBankColumn`：宽 100 的银行列，6 枚 lg 筹码 + 操作提示 + 确认 / 取消；
  `set_interactive()` / `set_clickable_colors()` / `set_selection()` 控制点击态，发出 `chip_clicked`。
- `my_panel.gd` — `UiMyPanel`：左栏底部高 246 的面板：状态条 + 身份 / 资源 / 预留三列。
  顶部托盘有确认 / 取消（发出 `confirm_pressed` / `cancel_pressed`）；预留卡可点（`reserved_card_clicked`）。
- `opponent_panel.gd` — `UiOpponentPanel`：右栏对手面板：分数进度条、6 列折扣 + 宝石网格、预留标记。
- `log_panel.gd` — `UiLogPanel`：对局日志，最新一条高亮，支持 `{card:id}` / `{gem:color}` 内联标记。

所有类名统一 `Ui` 前缀。陈列与截图见 `ui/dev/`；牌桌的组合方式见 `ui/screens/table/`。

U5 起，面板零件额外暴露动效定位用的只读方法（不改变显示逻辑）：`bank_column.chip_rect()`、
`my_panel.score_control()` / `token_chip()` / `bonus_tile()` / `reserved_card_rect()` / `reserved_area_rect()`、
`opponent_panel.score_control()` / `token_chip()` / `bonus_tile()`、`hud.endgame_tag_control()`。
牌桌把它们换算成屏幕矩形交给 `UiTableAnim`。
