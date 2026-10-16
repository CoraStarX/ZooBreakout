# Zoo Breakout — 技術現況

更新：2026-10-16。三項白盒已結項，專案完成文件與入口整理，準備討論量產管線驗證；尚未開始量產實作。逐輪落地記錄見 [TECH_HISTORY.md](TECH_HISTORY.md)。

## 技術基線

Godot 4.7、GDScript 靜態型別、3D 灰盒、45° 正交。依賴 Content → GamePlay → Core；規則與門禁見 [ARCHITECTURE.md](ARCHITECTURE.md)。

| 模組 | 規則／資料／場景 |
|---|---|
| 猴移動 | `gameplay/traversal/`、`content/traversal/traversal_params.*`、`scenes/traversal/movement_lab.tscn` |
| 獨立員工 | `gameplay/staff/readability_staff.gd`、`staff_perception_footprint.gd`、`content/staff/*readability*.tres`、`scenes/traversal/staff_readability_lab.tscn` |
| 變形 A | `gameplay/forms/`、`content/forms/`、`scenes/forms/form_lab.tscn` |
| 玩家 UI／診斷 | `GameHUD`／`UIKit`、`ProximityLabel`；開發資訊在 `debug_hud.gd`；偏好走 `UserPrefs` |
| 舊正式世界 | `scenes/boot/start_select.tscn` → `scenes/world/zoo_p0.tscn`；仍為 F5 主入口 |

Autoload 沿用 Bus、Game、Clock、Alert、OfficeStorage、CaptureFlow。三項白盒沒有新增全域狀態機；跨場景新局走 RunLifecycle.reset()。

三項白盒是獨立沙盒，尚未組成完整擬態潛行迴路。變形 C 已選擇封裝既有 ReadabilityStaff，但封裝／整合尚未實作；變形 B 實際窄縫亦未實作。

## 驗證與保留項

統一入口 `tools/run_tests.sh`，31 套件；白盒專項為 p2_traversal、p2_staff_readability、p2_forms。當前結果見 [QA](qa_reports/latest_report.md)。

保留舊關卡與所有回歸，避免在未完成新迴路前失去比較基準。既有 full_loop pending=1 與遠端 CI 未驗證分開追蹤。文件歷史中的待手玩描述以 [現行清單](P2_CHECKLIST.md) 與最新結項裁決為準。
