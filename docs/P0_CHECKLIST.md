# Zoo Breakout — P0 清单

> **P0 Done (2026-10-01)** — QA 门闩回归全绿后正式结项。后续见 [P1_CHECKLIST.md](P1_CHECKLIST.md)。

## 验证题

换控 + 跟随是否成立？「有动词更稳 / 无动词可硬闯」是否可读？

## 操作

| 输入 | 作用 |
|------|------|
| WASD / 左摇杆 | **相对相机**移动 |
| E / 手柄 A | 交互（世界空间标签可读 Soft/Hard） |
| Tab / Q / 手柄 Y | 换控 |
| F / LB | 队友 Follow |
| H / RB | 队友 Hold |
| R | **【Debug 默认关】** 跳过笼门解救（`Game.debug_enabled`） |
| T | **【Debug 默认关】** 推进时段 |

正式解救路径：打开同伴笼门自动入队（勿依赖 R）。

## Keep / Kill

见 [DESIGN.md](DESIGN.md)。

## 完成定义

- [x] M0 工程可运行
- [x] M1 单动物 Soft/Hard 门（笼门锁 / 铁丝网）
- [x] M2 双动物换控+跟随（正式：开同伴笼门入队；R 仅为 Debug）
- [x] M3 双解法关卡（攀爬捷径 vs 硬闯铁丝网）
- [x] M4 简易抓捕（硬闯噪音+警戒范围内送回）
- [x] M5 评审记录写在本文件底部

## M5 评审

日期：2026-09-30  
结论：**Keep**（带 Refactor 清单进架构落地）

笔记：

- 钩子成立：换控、解救入队、Soft（有能力更稳）/ Hard（更吵更慢）可读。
- 试玩中暴露并已修：角色无 mesh、相机跟随与 45° 成帧、铁丝网不应整段消失。
- Follow/Hold 与危险区待命可用，足够支撑 P1。
- Refactor（不否决钩子）：`zoo_world` God Object → 抽 PartyController；关卡几何场景化；Capture/Clock 进 GamePlay 层。

### 结项确认（2026-10-01）

- QA 门闩：围栏封闭、重力下落、目标一致、Debug 默认关、回归 18/18、跟班 13/13 → **全绿**。
- **P0 正式结项**；垂直切片进入 [P1_CHECKLIST.md](P1_CHECKLIST.md)（通关闭环首周）。
