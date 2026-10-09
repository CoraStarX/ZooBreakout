# Zoo Breakout — P1 清单

> **P1 Done (2026-10-09)** — QA M0–M4 门禁全绿；套件面板 UI 仍 backlog。后续见 [P2_CHECKLIST.md](P2_CHECKLIST.md)。
>
> 垂直切片：通关闭环 + Prep Loop + 动词/双开局/出生点。

## 验证题

- 通关：挖掘/攀爬线出园 + 满警再抓败北？
- Prep：白天套件施加 → Breach%/清单，夜间仍可打通？
- M4：挖/爬演出可读；猴开局跟班可跑；出生点不在 `zoo_world` 硬编码？

## 里程碑

- [x] M0 RunSession 胜负 + 目标文案（挖掘/攀爬线就绪）
- [x] M1 双出园线几何 + ExitZone 同步检测
- [x] M2 结算 UI 回标题
- [x] M3 Prep Loop（套件搜集 + Breach 日常反馈）
- [x] M4 动词演出可读 / 猴开局跟班 / 出生点数据化

## 胜负规则（已锁定）

| 结果 | 条件 |
|------|------|
| **WON** | 任一出园线就绪；party 内所有非禁闭成员同时在对应 ExitZone |
| **LOST** | `Alert.level >= MAX` 且再次被抓（封园） |
| 日常被抓 | 仍走关禁闭，不直接败北 |

路线：

1. **挖掘线**：完成「铁丝网挖洞」→ 西侧外墙缺口 → 西门 ExitZone  
2. **攀爬线**：完成「棚顶攀爬」→ 南侧走廊 → 南门 ExitZone  

未救满也可通关；禁闭同伴不挡胜利，HUD 提示未同行。

## 从 QA 迁入的 backlog

- [x] 动词演出：攀爬越障 vault + 挖洞墙体缺口对齐
- [x] 双开局跟班（`p1_monkey_walkthrough`）
- [x] `zoo_world` 物种/坐标 → `content/levels/zoo_p0_spawns.gd`
- [ ] Prep Loop 套件 UI

## Prep Loop（M3 已落地）

| 步骤 | 行为 |
|------|------|
| 日间拾取 | 园区 `dig_kit` / `climb_kit` 地面套件 |
| 日间施加 | Open/Close 对挖洞/攀爬点 E → 消耗套件、Breach +20%、清单勾选（不打开路径） |
| 夜间打通 | 仍按 Soft/Hard 破障；已准备略加快 Soft |

完整套件面板 UI 仍属 backlog。

## 复测

```bash
godot --headless --path . res://prototypes/p1_prep_loop.tscn
godot --headless --path . res://prototypes/p1_win_routes.tscn
godot --headless --path . res://prototypes/p1_monkey_walkthrough.tscn
godot --headless --path . res://prototypes/p0_regression.tscn
godot --headless --path . res://prototypes/p0_walkthrough.tscn
```

## 本切片不做

完整套件面板 UI、存档、暂停菜单、相机/Shader 改动、新 Autoload 状态机。
