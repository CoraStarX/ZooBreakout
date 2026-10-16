# Zoo Breakout

Godot 4.7 · GDScript 靜態型別 · 3D 灰盒 · 45° 正交。

目前方向為單角色擬態。移動、獨立員工可讀性、變形 A 三項白盒基線已結項；下一步準備量產管線驗證，範圍尚待確定。舊雙動物關卡保留作歷史玩法與回歸基準。

## 開啟專案

以 Godot 4.7 開啟根目錄 `project.godot`。選擇下列場景，再執行目前場景（F6；Mac 可能需 Fn+F6）：

| 入口 | 用途 | 操作 |
|---|---|---|
| `scenes/traversal/movement_lab.tscn` | 已驗收猴移動 | WASD、Space 跳躍／放手、F3 統計 |
| `scenes/traversal/staff_readability_lab.tscn` | 已驗收獨立員工基線 | 同上；F3 感知摘要／完整診斷 |
| `scenes/forms/form_lab.tscn` | 已驗收變形 A | WASD、Q 本體／猴切換、Space 猴移動、F3 |
| `scenes/boot/start_select.tscn` | 舊雙動物關卡 | F5 預設仍進此入口；見[舊關卡操作](docs/LEGACY_PLAY_GUIDE.md) |

根目錄 `movement_lab.tscn`、`staff_readability_lab.tscn` 保留為舊入口相容場景；新工作統一使用 `scenes/` 入口。`prototypes/` 是驗證場景與測試，不是遊戲入口。

## 文件入口

- [現行階段與範圍](docs/P2_CHECKLIST.md) · [技術現況](docs/TECH.md) · [當前 QA](docs/qa_reports/latest_report.md)
- [設計決策](docs/DESIGN.md) · [架構與門禁](docs/ARCHITECTURE.md) · [開發紀律](AGENTS.md)
- [移動規格](docs/MOVEMENT_SLICE.md) · [員工規格](docs/STAFF_READABILITY.md) · [變形規格](docs/FORMS_SLICE.md)
- [整理紀錄與下一階段前置](docs/PROJECT_BASELINE.md)

## 驗證

```bash
# 首次開啟／新增 class_name 後刷新快取
/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import
# 全部 31 套件
tools/run_tests.sh
# 三項白盒專項
tools/run_tests.sh p2_traversal p2_staff_readability p2_forms
```

退出碼非 0 或輸出含 FAIL／FINDING／SCRIPT ERROR／ERROR: 即失敗。舊 `p2_full_loop` 的 `pending=1` 是既有 Soft 通關天數待決，不能視為全項驗收完成。視覺／手感變更另做非 headless 檢查。
