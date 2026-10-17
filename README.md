# Borrowed Shapes

單角色擬態核心原型。Godot 4.7 · GDScript靜態型別 · 3D灰盒 · 45°正交。

移動、變形、攀爬、跨越已驗收；核心已解除舊玩法依賴。下一階段是量產管線驗證，尚未開始新玩法或美術量產。

## 遊玩

開啟根目錄project.godot，F5執行 `scenes/forms/form_lab.tscn`。它共用MovementLab的灰盒、鏡頭與移動，再加入形態初始化與切換。

| 輸入 | 操作 |
|---|---|
| WASD／方向鍵／左搖桿 | 移動；攀爬時控制方向 |
| Q | 本體／猴形態切換；回本體不受冷卻限制 |
| Space | 猴形態跳躍、跨越、跳下、攀爬放手；本體不能跳躍 |
| E／手柄A | 互動輸入；目前沒有新增互動玩法 |
| F3 | 診斷、重置／複製、形態提示開關 |

`scenes/traversal/movement_lab.tscn`保留作純移動回歸入口；`scenes/traversal/staff_readability_lab.tscn`保留作已驗收員工沙盒。它們不是第二個產品主入口。猴形態是目前已驗收內容，名稱與id保留。

## 驗證與文件

```bash
tools/run_tests.sh
# 個別回歸
tools/run_tests.sh p2_traversal p2_forms
```

Godot在沙盒外驗證；錯誤、警告、失敗或超時均使門禁失敗。首次開啟或新增全域類別後先以Godot headless import建立快取。

[設計](docs/DESIGN.md) · [架構](docs/ARCHITECTURE.md) · [技術現況](docs/TECH.md) · [範圍](docs/P2_CHECKLIST.md) · [開發指引](AGENTS.md) · [QA](docs/qa_reports/latest_report.md)

[61檔核心清單](docs/migration-manifest.txt)與[解耦紀錄](docs/decoupling-log.md)保留移植邊界。歷史文件與驗證證據保留原文；不作現行操作說明或新增功能依據。

## FormLab 風格基底

共用風格位於 `content/shared/`，只接入既有 FormLab。建築、平台、斜坡、碰撞與機制資料保持原樣；MovementLab 與員工入口保留原本呈現。

- `style_settings.tres` 的 `palette` 是唯一色板選擇入口，預設 `palette_warm_courtyard.tres`（A）；`palette_cool_architecture.tres`（B）可直接替換此引用，不需改場景或幾何。
- 在該設定 Resource 覆寫 `outline_enabled`、`toon_enabled`、`post_enabled` 可獨立開關；預設為基礎 flat shading 加環境，描邊與 toon 關閉。參數預設與區塊角色表集中在 `style_settings.gd`；角色 0／1／2／3 對應建築／平台／地面／亮面。
- 建築實例共用一個 ShaderMaterial，以逐實例角色、尺寸與斜坡旗標區分。尺寸僅供表面內側的程序描邊，不改網格或碰撞。遮擋沿用原查詢，透過 Forward+ 的逐實例透明度淡出。
- 攀爬面與跨越線共用另一個 unlit、停用霧的材質，固定青色、黃色及 `#26343A` 邊框，不跟隨 A／B 或建築描邊開關。形態角色與變形效果沿用既有配置。
- `environment_preset.tscn` 可實例化使用，包含 DirectionalLight3D 與 WorldEnvironment；色彩由色板注入，其餘環境參數集中在 preset。採 Linear tone mapping，避免改變機制色辨識；Glow 只對超過 HDR 門檻的亮部生效，bloom 為 0。

三組比較使用同一 FormLab、相機、解析度與玩家位置。以下命令只在視窗模式使用，輸出目錄須為絕對路徑：

```bash
/Applications/Godot.app/Contents/MacOS/Godot --path . scenes/forms/form_lab.tscn -- --style-capture=/tmp/borrowed_shapes_style
```

此選項在 FormLab 中等待至少 150 個物理幀，輸出 `01_palette_light.png`、`02_environment.png`、`03_outline_toon.png`，另輸出兩張 B 色板驗證圖。它在記憶體中暫換 B，檢查幾何、共用材質身分與機制色參數不變，再恢復 A 並退出；不儲存色板、場景或玩家偏好。

驗證狀態（2026-10-17）：首次字典鍵型別解析錯誤修正後，經使用者授權重驗。視窗編輯器匯入通過；FormLab 視窗模式至少 150 個物理幀、A 三張比較圖與 B 兩張驗證圖完成，均無錯誤或警告，正常退出碼 0。A／B 切換保留幾何、共用材質與機制色參數；填色內部像素顏色相同。截圖中的相機、HUD 與機制標記已檢視。操作驗證受阻：視窗工具只能綁定既有編輯器，未驗證移動、變形、攀爬與跨越；為結束驗證主動終止該遊戲程序（退出碼 -15），不算正常關閉通過。
