# 阶段 5 测试用例（大模型 AI）

## 先用 30 秒看这里

- **已经由脚本验证过、不用你跑的**：
  - `tests/llm_selfcheck.tscn`：配置 / AppConfig / 局面描述与隐藏信息 / 提示词 / 客户端
    （正常、结构化回退、HTTP 401/500、断网、超时、测试连接）/ 控制器
    （JSON、代码块、越界、网络、超时、取消）/ 完整 LLM vs 程序 AI 对局 /
    `start_new_game` 的 llm 座位 / 调试棋盘与配置面板（T5-01、T5-02）。
  - `tests/board_smoke.tscn`、`tests/flow_selfcheck.tscn`、`tests/ai_selfcheck.tscn`、
    `tests/data_report.tscn`、`tests/rules_selfcheck.tscn -- 2000`：回归（T5-03）。
- **需要你验收的**（机器判断不了的部分）在文末「需要你验收」：
  真实服务 / 本地 Ollama 的连接、等待与理由是否看得懂、兜底提示是否清楚。

所有命令都在仓库根目录执行，`$GODOT` 指 `/Applications/Godot.app/Contents/MacOS/Godot`。

```bash
cd /Users/lixiaofeng/workspace/GameProjects/GodotProjects/splendor
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
```

---

## T5-01 数据与配置校验

**前置条件**：无。

**步骤**

```bash
$GODOT --headless --path . tests/data_report.tscn; echo "退出码: $?"
```

**预期结果**：退出码 `0`，和阶段 4 一样的数据校验输出（卡表、贵族、三档 AI 配置）。
大模型示例配置与提示词由 `llm_selfcheck` 校验（见 T5-02）。

可选：检查示例配置存在且没有真实 Key：

```bash
python3 - <<'EOF'
import json
data = json.load(open("data/llm/llm_config.example.json"))
for key, profile in data["llm"]["profiles"].items():
    print(key, profile["model"], "api_key=", repr(profile["api_key"]))
EOF
```

**预期结果**：输出两个配置档（`deepseek` / `ollama`），`api_key` 都是空字符串。

---

## T5-02 大模型自检（本地模拟服务器）

**前置条件**：无。不会访问外网，也不会动你的真实 `user://config.json`
（测试用临时配置路径）。

**步骤**

```bash
$GODOT --headless --path . tests/llm_selfcheck.tscn; echo "退出码: $?"
```

**预期结果**：退出码 `0`，末尾类似：

```
=== 大模型自检（本地模拟服务器）===
  配置解析与校验 ✓
  AppConfig 读写与校验 ✓
  局面描述与隐藏信息断言 ✓
  提示词模板与性格 ✓
  LlmClient：正常 / 结构化回退 / HTTP / 断网 / 超时 / 测试连接 ✓
  LlmController：正常 / 代码块 / 解析失败 / HTTP / 超时 / 取消 ✓
  全流程：LLM vs 程序 AI（34 次请求，4080 tokens）✓
ERROR: GameController：座位 0 的类型 "llm" 在本阶段不可用
  ...（这是“不存在的配置档应拒绝开局”用例的预期日志，不是失败）
  start_new_game 的 llm 座位与坏配置档 ✓
  调试界面配置面板 ✓

OK —— 共 120 项检查全部通过，用时 5.8 秒。
```

请求数 / token 数由模拟服务器和固定种子决定，本次是 34 / 4080；改动规则或模拟策略后可能变化，
但应该是“正常结束、0 次兜底”。

**覆盖的内容**：

- 配置档字段校验（温度、base_url、model、结构化输出、兜底难度、性格、预算范围）。
- AppConfig：首次复制示例、保存后读回、新建 / 激活 / 删除、不能删最后一个、坏 JSON 报错。
- 局面描述：主要区块、当前玩家、动作编号从 1 开始、对手盲抽显示为未知；
  用完整视图交叉检查文本不含牌堆卡牌 id / 对手盲抽 id；故意塞入隐藏 id 时能被检查出来。
- 提示词：占位符全部替换、四种性格模板都存在、messages 为 system + user。
- `LlmClient`：正常回复与 token 统计；服务不支持 `response_format` 时自动退回纯文本；
  HTTP 401；断网；超时；`test_connection`。
- `LlmController`：正常 JSON、代码块 + 前后解释、越界编号重试后 `parse_failed` 兜底、
  HTTP 500 重试后 `network` 兜底、超时预算内 `timeout` 兜底、`cancel_pending()` 后不再发动作。
- 完整对局：第 0 座大模型 + 第 1 座简单电脑，模拟服务器永远返回合法动作；
  对局以 `win_points` 正常结束、回合数相同、没有非法动作和兜底。
- `start_new_game` 的 `llm` 座位（临时 AppConfig）能推进对局；不存在的配置档被拒绝；
  两个大模型座位分别用两个配置档时，请求里的 `model` 各不相同（不同座位可以用不同模型）。
- 调试棋盘：日志出现大模型等待与理由；配置面板能加载配置档。

---

## T5-03 回归

**前置条件**：无。

**步骤**

```bash
$GODOT --headless --path . tests/flow_selfcheck.tscn; echo "退出码: $?"
$GODOT --headless --path . tests/board_smoke.tscn; echo "退出码: $?"
$GODOT --headless --path . tests/ai_selfcheck.tscn; echo "退出码: $?"
$GODOT --headless --path . tests/rules_selfcheck.tscn -- 2000; echo "退出码: $?"
```

**预期结果**（本次实际）：

- `flow_selfcheck`：`OK —— 共 8647 项检查全部通过，用时 3.3 秒。`
- `board_smoke`：`OK —— 共 101 项检查全部通过，用时 0.5 秒。`
  （增加大模型座位选项、配置档下拉框、`seat_options` 传递的检查）
- `ai_selfcheck`：`OK —— 共 149 项检查全部通过，用时 5.7 秒。`
- `rules_selfcheck -- 2000`：`OK —— 共 523273 项检查全部通过，用时 137.3 秒。`
  （2000 局 / 284679 步，最长 273 步；运行中的非法动作 ERROR 日志是“非法动作被拒绝”用例的预期输出）

---

## T5-04 真实 OpenAI 兼容服务（手工）

**前置条件**：有一个 OpenAI 兼容服务的 `base_url`、`model` 和 API Key
（DeepSeek、通义、Kimi、OpenAI 等均可）。**不要把 Key 写进仓库文件。**

**步骤**

1. 启动主场景：

   ```bash
   $GODOT --path .
   ```

2. 在设置界面点「大模型设置…」。
3. 选择一个配置档（例如 `deepseek`），填写：
   - BASE URL（例如 `https://api.deepseek.com/v1`）
   - API KEY（密码框）
   - 模型名（例如 `deepseek-chat`）
4. 点「测试连接」。**预期**：几秒内显示 `✓ 连接成功（模型 …，HTTP 200）· N.N 秒`。
5. 点「保存」；关闭面板。
6. 设置界面：人数 2，座位 0 人类，座位 1 大模型（配置档选你刚保存的那个），开始游戏。
7. 走几步，观察：
   - 轮到大模型时，顶栏变成「大模型思考中… 已等 N.N / 预算 秒」，所有动作按钮禁用。
   - 日志出现「… 座位 1 的大模型（显示名）第 1 次请求」。
   - 模型返回后，日志出现「◇ 座位 1 的大模型理由：…」，然后自动执行动作。
   - 一局大约 60–120 次请求；慢是正常的。
8. 换一局，故意把 Key 改错再开（或断网 / 停掉本地服务）。**预期**：
   - 重试 `max_retries` 次后，日志出现「⚠ 座位 1 的大模型网络 / 接口错误，这一步由困难电脑代打。」
   - 对局继续，不会卡死。
9. 在大模型思考时点「返回设置」，再开一局。**预期**：没有旧动作注入新局，
   日志没有「不在他的回合」之类错误。

**预期结果**：真实服务能连上并打完一局；错误 Key / 断网时能自动兜底；
等待时间和理由在界面上可读；Key 只存在 `user://config.json`。

> 说明：你填写的 Key 会明文保存在本机用户目录（单机工具的常规做法）；
> 仓库里的 `data/llm/llm_config.example.json` 始终是空 Key。

---

## T5-05 本地 Ollama（手工，需要先安装）

**前置条件**：本机当前没有安装 Ollama。

**步骤**

1. 安装并启动（任选一种）：

   ```bash
   brew install ollama
   ollama serve
   ```

   或者从 <https://ollama.com/download> 下载 macOS 应用。

2. 拉一个模型（示例是 7B，机器吃不消可以换更小的）：

   ```bash
   ollama pull qwen2.5:7b
   ollama list
   ```

3. 确认 OpenAI 兼容接口在跑：

   ```bash
   curl -s http://127.0.0.1:11434/v1/models | head -c 400
   ```

4. 启动游戏 → 「大模型设置…」→ 选择 `ollama` 配置档：
   - BASE URL：`http://127.0.0.1:11434/v1`
   - 模型名：与 `ollama list` 里的一致（默认示例 `qwen2.5:7b`）
   - Key 留空
5. 点「测试连接」，然后开一局 2 人（座位 1 大模型）。

**预期结果**：测试连接成功；对局能推进。本地模型可能比云端慢，等待时间会显示在顶栏。
如果模型经常返回非 JSON，日志会出现「回复无法解析，由困难电脑代打」——这是预期的兜底，
换更大的模型或降低温度可以改善。

> 如果 Ollama 版本不认 `response_format`，客户端会自动退回纯文本（配置档的
> `structured_output` 用 `auto`）；不需要你改配置。

---

## T5-06 4 人局与大模型互打（手工，可选）

**前置条件**：已完成 T5-04 或 T5-05。

**步骤**

1. 4 人局：座位 0 人类，座位 1/2/3 分别选大模型 / 普通电脑 / 困难电脑。
2. 再开一局 4 人，全部座位选大模型（可以选不同配置档）。
3. 观察一局或走 15–30 步。

**预期结果**：

- 大模型座位自动行动；人类回合按钮可用，其他回合全部禁用。
- 日志里能看到每个大模型座位的请求、理由和（如果有）兜底。
- 4 个大模型同时跑会明显变慢；这是预期（每个动作一次 HTTP）。
- 返回设置 / 再开新局不会残留旧请求。

---

## T5-07 隐藏信息（自动验证为主）

**前置条件**：无。

**步骤**

```bash
$GODOT --headless --path . tests/llm_selfcheck.tscn; echo "退出码: $?"
```

**预期结果**：退出码 `0`，其中“局面描述与隐藏信息断言 ✓”。

**这条为什么可以放心**：

- `llm_selfcheck` 用完整状态构造了一个“对手盲抽预留”的局面，检查：
  - 发给模型的是 `to_dict(viewer_seat)`，不是完整视图；
  - 文本里不含牌堆里的任何卡牌 id；
  - 文本里不含对手盲抽预留的卡牌 id；
  - 视图里没有种子 / 随机数 / 牌堆顺序。
- 调试构建里 `LlmController` 发送前还会再断言一次；如果泄露，游戏会直接报错停下
  （所以手工玩的时候没有报错，就说明没有触发）。

**你要观察的**：在与真实模型对局时，模型有没有“说出”牌堆里还没翻开的牌。
正常情况它只能看到牌堆张数，不应该提到具体未知卡牌。

---

## T5-08 配置持久化与 API Key 位置（手工）

**前置条件**：完成 T5-04 的保存。

**步骤**

1. 关闭游戏，重新 `$GODOT --path .`。
2. 打开「大模型设置…」，确认 BASE URL / 模型 / 显示名还在；Key 框显示为密码点。
3. 查看用户配置文件位置：

   ```bash
   ls -l "$HOME/Library/Application Support/Godot/app_userdata/Splendor/config.json"
   python3 - <<'EOF'
   import json, os
   p = os.path.expanduser("~/Library/Application Support/Godot/app_userdata/Splendor/config.json")
   data = json.load(open(p))
   print("profiles:", list(data["llm"]["profiles"]))
   print("active:", data["llm"]["active_profile"])
   EOF
   ```

**预期结果**：配置在重启后保留；Key 只在 `user://config.json` 里；
`git status` 不会出现这个文件（它在用户目录，不在仓库）。

---

## 需要你验收（机器判断不了的部分）

### A. 真实服务连接（约 5 分钟）

按 T5-04 连接至少一家 OpenAI 兼容服务，跑几步对局。**要你回答的**：

1. 测试连接是否成功？用的哪家服务 / 模型？
2. 顶栏的「已等 N / 预算 秒」是否看得懂？一次请求大概等多久？
3. 日志里的模型理由是否有用、是否太长 / 太短？
4. 故意填错 Key 或断网时，兜底提示是否清楚？对局有没有卡住？

### B. 本地 Ollama（可选，约 10 分钟）

按 T5-05 安装并连接。**要你回答的**：测试连接是否成功？本地模型的动作是否合理？
如果经常解析失败，记下模型名和日志里的错误。

### C. 界面与手感

按 T5-06 开 3/4 人局。**要你回答的**：大模型回合的等待状态是否明显？
4 个大模型一起跑时界面是否还能操作（禁用按钮、返回设置）？
返回设置 / 载入预设局面后有没有旧请求的残留？

---

## 附：本阶段没有做的（按计划留给后续阶段）

- 联网时把大模型等待 / 理由 / 兜底同步给客户端（阶段 6）。
- 正式 UI 的设置页（并行 UI 线的第 16 屏；调试面板只用于验证）。
- 真实服务的自动化测试（需要 Key / Ollama，本阶段用本地模拟服务器覆盖分支）。
- 大模型座位参与存档的座位类型恢复（IR-04；目前读档 / 重放仍重建为人类）。
- token 用量显示（`LlmController.token_usage()` 可取，调试界面未展示）。
