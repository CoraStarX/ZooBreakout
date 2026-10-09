# Zoo Breakout — P2 清单

> 垂直切片。首刀重心：**出园空间可读 + 白天 Prep 可发现**（强化计划感，不扩新物种）。

## 验证题

白天不依赖 Debug（不按 T / 不用 R），玩家能否自己完成「捡套件 → 到挖/爬点做准备」？  
夜间挖洞 / 攀爬是否读得成「翻出园墙」，并进入对应 ExitZone 通关？

- **Keep**：白天有事做且 Prep 自然发现；挖/爬点落在外墙或内外一眼可读；通关不回退。
- **Kill**：白天仍像空等时间；挖内墙却远处外门消失；玩家说不清「我在逃动物园」。

## 里程碑

- [x] M0 挖/爬交互落到最外圈围墙（西外墙挖洞 / 南外墙攀爬）
- [x] M1 白天 Prep 可发现性（套件醒目 + 目标/反馈把「先捡再准备」说死）
- [x] M2 昼夜节奏 + 天数（Day 计数 / Open 90s / 天亮结算 / 第 7 天期限 / 安分降警戒；门禁 `p2_day_cycle`）（详见 [DAYNIGHT_LOOP.md](DAYNIGHT_LOOP.md)）
- [x] M2b 零件点（7 个搜集点/动词门槛/每日补货/3 零件可替代套件做准备；门禁 `p2_gather`）
- [x] M2f 被抓改短押（15s + 笼内搜集 + 笼门加固 + 同伴营救 + 抓捕原因提示；门禁 `p2_capture`）
- [x] M2c 情报观察（2 个观察点：歇岗时刻 → HUD 距歇岗倒计时；巡逻路线 → 地面画线；须看得见职员才累积进度；跨天保留；门禁 `p2_intel`）
- [x] M2d 夜间施工（路线 3 档；每档零件×2 或套件(顶 2 档)；Soft 6s / Hard 14s；可被打断不扣料；进度跨天保留；取代白天准备；门禁 `p2_route_work` + 端到端 `p2_full_loop`）
- [x] M2g 材料系统 v2：三种原料 + 路线配方 + 金属稀缺/工具间/潜行偷工具车 + 巡逻点停步（门禁 `p2_cart`、`p2_gather`）；路线回 3 档
- [ ] M2e 平衡与回归：首轮手玩（2 天通关）→ 已上调：4 档/5 天/Open 75s/职员每日增强；待第二轮手玩确认（目标：熟练 3–4 天通关，5 天内可败）
- [ ] M3 回归门禁：既有 `p1_*` / `p0_*` 全绿 + 新增「纯白天不按 T」跟班
- [ ] M4 backlog：套件面板 UI / 白天深度 / 新物种 — 不挡本切片结项

## 空间规则（已锁定方向）

| 路线 | 期望 |
|------|------|
| **挖掘线** | 玩家操作的破障点 = 西侧**外墙**缺口（或破障后外墙开口与落点同一视线） |
| **攀爬线** | 玩家翻越的 = 南侧**外墙**（或展区南墙翻出后外门已在脚下、无「远处墙消失」） |
| **出口** | 仍：西门 ExitWest / 南门 ExitSouth；WON/LOST 规则不变 |

禁止：内廊铁丝网完成 → 脚本静默关掉远处外门且无空间因果。

## Prep 可发现（M1 验收要点；⚠ 2026-10-09 已被「夜间施工」取代：白天不再施加套件，改为搜集+侦察，见 DAYNIGHT_LOOP.md）

| 项 | 期望 |
|----|------|
| 地面 `dig_kit` / `climb_kit` | 日间一眼能认出（色/标/标签），无需读代码坐标 |
| HUD / 目标 | Open 时段明确「搜集套件 → 到挖/爬点准备」 |
| 施加反馈 | Breach% + 清单勾选可读；日间仍不打开路径 |
| 纯白天跟班 | 不按 T，在 Open 时长内能走完捡+准备至少一条线 |

## 从 QA 迁入的 backlog（本切片可顺带，不强制）

- [x] 出园空间叙事（挖/爬在外墙）— **M0 Done**
- [x] 白天 Prep 可发现 — **M1 Done**
- [ ] Prep Loop 套件面板 UI — 仍 backlog（完整面板）
- [ ] 白天深度（更多情报/观察玩法）— M2 最多 1 点，其余 P3

## 复测（结项前必跑）

```bash
godot --headless --path . res://prototypes/p2_outer_walls.tscn
godot --headless --path . res://prototypes/p1_win_routes.tscn
godot --headless --path . res://prototypes/p1_monkey_walkthrough.tscn
godot --headless --path . res://prototypes/p0_regression.tscn
godot --headless --path . res://prototypes/p0_walkthrough.tscn
godot --headless --path . res://prototypes/p2_run_reset.tscn
godot --headless --path . res://prototypes/p2_day_cycle.tscn
godot --headless --path . res://prototypes/p2_gather.tscn
godot --headless --path . res://prototypes/p2_capture.tscn
godot --headless --path . res://prototypes/p2_intel.tscn
godot --headless --path . res://prototypes/p2_route_work.tscn
godot --headless --path . res://prototypes/p2_full_loop.tscn
```

一键：`tools/run_tests.sh`（全部套件，任一 FAIL/FINDING 即红）。

## P3 待办（已记录，不进本切片）

- **垂直结构验证原型**：一块带 0.5–1.5m 平台的区域，攀爬改为真实向上移动；验证相机遮挡、跟随绕行、职员视线高度遮挡。**触及 FollowCamera 须先出方案给用户确认。**
- **关卡重制**：展区分层（屋顶/围墙顶/地下管道），三种能力各有独占路线；地图放大。
- 跟随 AI 换导航网格（多层地形前置条件）。
- 劳役类惩罚玩法、新物种（獾/冲撞）、套件面板 UI。

## 本切片不做

- 完整套件面板 UI、存档、暂停菜单  
- 新物种（獾/冲撞）、多层/多园区  
- 改 `FollowCamera` 数学 / 自定义 Shader / 新 Autoload 状态机（须先 Architect）  
- 把白天做成第二条主线玩法（情报轨做深 → P3）

## 与 P1 关系

[P1_CHECKLIST.md](P1_CHECKLIST.md) **Done**：通关闭环 + Prep Loop + 动词灰盒 + 双开局。  
P2 不重做胜负，只修「读得懂、白天有事做」。
