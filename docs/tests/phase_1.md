# 阶段 1 测试用例（工程骨架与数据层）

所有命令都在仓库根目录执行，`$GODOT` 指 `/Applications/Godot.app/Contents/MacOS/Godot`。

```bash
cd /Users/lixiaofeng/workspace/GameProjects/GodotProjects/splendor
GODOT=/Applications/Godot.app/Contents/MacOS/Godot
```

---

## T1-01 工程骨架齐全

**前置条件**：无。

**步骤**

```bash
ls CLAUDE.md docs/PROGRESS.md docs/DEVELOPMENT_PLAN.md
ls autoload core game ai llm net debug_ui data tests docs
for d in autoload core game ai llm net debug_ui data tests docs; do ls $d/README.md; done
```

**预期结果**：以上文件与目录全部存在；每个目录各有一份 `README.md`。

---

## T1-02 工程能被 Godot 导入，无脚本错误

**前置条件**：无。

**步骤**

```bash
$GODOT --headless --import --path . 2>&1 | grep -E "SCRIPT ERROR|Parse Error"
```

**预期结果**：没有输出（没有脚本错误）。首次导入会打印一串进度日志，属于正常。

---

## T1-03 数据加载与统计正确

**前置条件**：无。

**步骤**

```bash
$GODOT --headless --path . tests/data_report.tscn; echo "退出码: $?"
```

**预期结果**：退出码 `0`，输出包含（数值必须与此处一致）：

```
规则：2/3/4 人每色宝石 4/5/7，金币 5，胜利分 15，持币上限 10，预留上限 3，每级场面 4 张
发展卡：90 张
  1 级：40 张（白8 蓝8 绿8 红8 黑8）；0分 35张 / 1分 5张
  2 级：30 张（白6 蓝6 绿6 红6 黑6）；1分 10张 / 2分 15张 / 3分 5张
  3 级：20 张（白4 蓝4 绿4 红4 黑4）；3分 5张 / 4分 10张 / 5分 5张
贵族：10 位
OK - 数据校验通过
```

---

## T1-04 卡表人工核对

**前置条件**：T1-03 通过。

**步骤**：打开 `docs/CARD_LIST.md`，对照实体卡（或官方卡表）逐张核对。

**预期结果**：卡表按「等级 → 颜色（白蓝绿红黑）→ 分数 → 花费」排序，每行含 id、加成色、分数、五色花费与合计；共 90 行发展卡 + 10 行贵族。
重点核对几张标志性卡牌：

| id | 卡面 | 说明 |
|---|---|---|
| `L3-R-02` | 红加成 4 分，花费 7 绿 | 计划里写明的锚点卡 |
| `L3-W-02` | 白加成 4 分，花费 7 黑 | 三级 7 费卡的另一例 |
| `L2-*-06` | 五种颜色各一张 3 分卡，花费 6 枚**本颜色** | 二级 3 分卡 |
| `L1-*-08` | 五种颜色各一张 1 分卡，花费 4 枚其他颜色 | 一级唯一的 1 分卡 |
| `N-06` ～ `N-10` | 4+4 型贵族 | 另 5 位是 3+3+3 型 |

---

## T1-05 规则参数与计划一致

**前置条件**：无。

**步骤**：打开 `data/rules.json`，对照 `docs/DEVELOPMENT_PLAN.md` 阶段 1 第 4 条。

**预期结果**：2/3/4 人每色宝石 `4/5/7`、金币 `5`、贵族数 = 人数 + 1（`3/4/5`）、胜利分 `15`、持币上限 `10`、预留上限 `3`、拿两枚同色要求该色剩余 ≥ `4`、每级场面 `4` 张；另有 4 个规则细节开关（含义见 `data/README.md`）。

---

## T1-06 JSON 语法错误能定位到行号

**前置条件**：已备份 `data/cards.json`。

**步骤**

```bash
cp data/cards.json /tmp/cards_backup.json
python3 -c "p='data/cards.json'; s=open(p).read(); open(p,'w').write(s[:-3])"
$GODOT --headless --path . tests/data_report.tscn; echo "退出码: $?"
cp /tmp/cards_backup.json data/cards.json
```

**预期结果**：退出码 `1`，报出类似

```
数据校验失败，共 1 个问题：
  x cards.json：第 938 行 JSON 语法错误：Expected ','
```

---

## T1-07 非法数值能定位到具体卡牌

**前置条件**：已备份 `data/cards.json`。

**步骤**：把 `L1-W-01` 的白字花费改成 `"cost": {"blue": 8}`（超过单色上限 7），重跑 `tests/data_report.tscn`，然后还原。

**预期结果**：退出码 `1`，第一条即为 `cards.json L1-W-01：cost.blue = 8 超过单色花费上限 7`，并连带报出「1 级卡牌应为 40 张，实际 39 张」「1 级 white 色卡牌应为 8 张，实际 7 张」。

---

## T1-08 id 重复会被发现

**前置条件**：已备份 `data/cards.json`。

**步骤**：把第二张卡的 `id` 改成与第一张相同，重跑，然后还原。

**预期结果**：退出码 `1`，报 `cards.json L1-W-01：id 与前面的卡牌重复`。

---

## T1-09 少一张卡会被发现

**前置条件**：已备份 `data/cards.json`。

**步骤**：删掉任意一张 1 级卡，重跑，然后还原。

**预期结果**：退出码 `1`，报「1 级卡牌应为 40 张，实际 39 张」以及对应颜色的「应为 8 张，实际 7 张」。

---

## T1-10 卡牌花费里出现金币会被发现

**前置条件**：已备份 `data/cards.json`。

**步骤**：把某张卡的 `cost` 改成 `{"gold": 2}`，重跑，然后还原。

**预期结果**：退出码 `1`，报 `cards.json L1-W-02：cost 不能包含 gold`。

---

## T1-11 锚点卡校验（整表错位检测）

**前置条件**：已备份 `data/cards.json`。

**步骤**：把 `L3-R-02`（红加成 4 分 7 绿）的花费从 `{"green": 7}` 改成 `{"blue": 7}`，重跑，然后还原。

**预期结果**：退出码 `1`，报 `cards.json：找不到锚点卡（3 级 red 加成 4 分 花费 green=7）——整表可能错位了`。

---

## T1-12 贵族要求形状校验

**前置条件**：已备份 `data/nobles.json`。

**步骤**：把 `N-01` 的要求改成 `{"white": 4, "blue": 3}`（4+3 不是合法形状），重跑，然后还原。

**预期结果**：退出码 `1`，报 `nobles.json N-01：要求必须是「两个 4」或「三个 3」，实际为 [3, 4]`。

---

## T1-13 与开源卡表交叉比对（一次性脚本，不入库）

**前置条件**：能访问网络；脚本与下载的数据放在 `/tmp`，不进入仓库。

**步骤**：见 `docs/PROGRESS.md` 阶段 1 的「交叉比对」小节。

**预期结果**：录入的 90 张卡与 10 位贵族与多个互相独立的开源实现逐张一致；有分歧的来源能逐条列出差异并判断是谁错。

---

## T1-14 修改数据后无需改代码即可生效

**前置条件**：T1-03 通过。

**步骤**：把 `data/rules.json` 里 `"max_tokens"` 改成 `9`，重跑 `tests/data_report.tscn`，然后还原。

**预期结果**：统计行里的「持币上限」变成 `9`，其余不变；说明规则数值确实来自数据文件而不是代码里的常量。
