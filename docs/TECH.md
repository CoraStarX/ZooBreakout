# Borrowed Shapes — 技術現況

Godot 4.7、GDScript靜態型別、3D灰盒、45°正交。核心解耦與使用者手動驗收已通過，正在清理名稱與已封存產品的專屬模組。

| 項目 | 現況 |
|---|---|
| 主入口 | scenes/forms/form_lab.tscn（F5） |
| 純移動回歸 | scenes/traversal/movement_lab.tscn |
| 控制器 | gameplay/traversal與gameplay/forms |
| 輸入 | project.godot內7個action，含左搖桿與手柄A |
| Autoload／訊號 | 只有Bus／noise_made |
| UI／診斷 | UIKit、ProximityLabel、DebugHUD；偏好為UserPrefs靜態工具 |
| 核心閉包 | 36個實質檔案＋25個UID＝61檔 |
| 員工 | 獨立沙盒與診斷／配置保留，未整合入FormLab |

統一門禁tools/run_tests.sh對準目前保留的核心套件與兩個入口載入；不再預設執行已退出的產品套件。當前結果見[QA](qa_reports/latest_report.md)。

閉包清單見[migration-manifest.txt](migration-manifest.txt)，解耦前後的完整證據見[decoupling-log.md](decoupling-log.md)。歷史驗證紀錄保留原文，不以本輪名稱覆寫。

正式移植、核心以外的內容製作與遠端CI執行尚未驗證。本輪不變更已驗收的操作、物理與相機行為。

2026-10-16：測試產物舊前綴與切片文件過期入口描述已整理；沙盒外七項核心門禁通過，歷史證據保留。
