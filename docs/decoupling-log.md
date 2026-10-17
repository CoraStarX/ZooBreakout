# 階段 2 解耦紀錄

分支：borrowed-shapes。按使用者指定步驟順序執行；Godot 驗證全部在沙盒外。任何 ERROR 或 WARNING 即停止，不設白名單。未提交或推送。

## 步驟 1：工程 Input Map

- 改動檔案：project.godot。
- 加入 move_left、move_right、move_forward、move_back、traversal_jump、transform、interact。
- 保留 WASD／方向鍵、Space、Q、E、左搖桿移動與手柄 A 互動。
- 驗證：沙盒外 FormLab 與 MovementLab 各載入 120 幀；兩者退出碼均為 0，無 ERROR／WARNING，通過。

### FormLab headless 載入

- 命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/borrowed-shapes-stage2/step-1-FormLab.log --quit-after 120 res://scenes/forms/form_lab.tscn`
- 退出碼：0。
- 結果：通過；無 ERROR／WARNING。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
```

### MovementLab headless 載入

- 命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/borrowed-shapes-stage2/step-1-MovementLab.log --quit-after 120 res://scenes/traversal/movement_lab.tscn`
- 退出碼：0。
- 結果：通過；無 ERROR／WARNING。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
```

## 步驟 2：主入口與 Autoload

- 改動檔案：project.godot。
- 主入口改為 scenes/forms/form_lab.tscn。
- Autoload 只保留 Bus，移除 Game、Clock、Alert、OfficeStorage、CaptureFlow 的註冊；原檔案均未刪除。
- 驗證：待沙盒外依序載入 FormLab 與 MovementLab；若第一個失敗立即停止，不啟動下一個。

### FormLab headless 載入

- 命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/borrowed-shapes-stage2/step-2-FormLab.log --quit-after 120 res://scenes/forms/form_lab.tscn`
- 退出碼：0。
- 結果：失敗；立即停止後續步驟。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

SCRIPT ERROR: Parse Error: Identifier "Game" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:50)
SCRIPT ERROR: Parse Error: Identifier "Game" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:52)
SCRIPT ERROR: Parse Error: Identifier "Game" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:97)
SCRIPT ERROR: Parse Error: Identifier "Game" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:98)
SCRIPT ERROR: Parse Error: Identifier "CaptureFlow" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:115)
SCRIPT ERROR: Parse Error: Identifier "Alert" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:129)
SCRIPT ERROR: Parse Error: Identifier "Game" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:129)
SCRIPT ERROR: Parse Error: Identifier "Game" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:131)
SCRIPT ERROR: Parse Error: Identifier "Alert" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:137)
SCRIPT ERROR: Parse Error: Identifier "Clock" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:140)
SCRIPT ERROR: Parse Error: Identifier "Clock" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:140)
SCRIPT ERROR: Parse Error: Identifier "Clock" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:140)
SCRIPT ERROR: Parse Error: Identifier "Clock" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:158)
SCRIPT ERROR: Parse Error: Identifier "Alert" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:164)
SCRIPT ERROR: Parse Error: Identifier "Clock" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:164)
SCRIPT ERROR: Parse Error: Identifier "Clock" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:164)
SCRIPT ERROR: Parse Error: Identifier "OfficeStorage" not declared in the current scope.
          at: GDScript::reload (res://content/ui/debug_hud.gd:168)
ERROR: Failed to load script "res://content/ui/debug_hud.gd" with error "Parse error".
   at: load (modules/gdscript/gdscript_resource_format.cpp:46)
ERROR: Node not found: "Panel/MovementStats" (relative to "/root/FormLab/DebugHUD").
   at: get_node (scene/main/node.cpp:1976)
   GDScript backtrace (most recent call first):
       [0] _build_guidance_settings (res://content/forms/form_lab.gd:55)
       [1] _ready (res://content/forms/form_lab.gd:46)
SCRIPT ERROR: Cannot call method 'add_child' on a null value.
          at: FormLab._build_guidance_settings (res://content/forms/form_lab.gd:55)
          GDScript backtrace (most recent call first):
              [0] _build_guidance_settings (res://content/forms/form_lab.gd:55)
              [1] _ready (res://content/forms/form_lab.gd:46)
WARNING: 1 RID of type "CanvasItem" was leaked.
   at: _free_rids (servers/rendering/renderer_canvas_cull.cpp:2733)
WARNING: 38 ObjectDB instances were leaked at exit (run with `--verbose` for details).
   at: cleanup (core/object/object.cpp:2535)
ERROR: 6 RID allocations of type 'PN13RendererDummy14TextureStorage12DummyTextureE' were leaked at exit.
ERROR: 2 RID allocations of type 'PN18TextServerAdvanced22ShapedTextDataAdvancedE' were leaked at exit.
ERROR: 1 RID allocations of type 'PN18TextServerAdvanced12FontAdvancedE' were leaked at exit.
```

## 停止狀態

- 步驟 1 通過；步驟 2 的 FormLab 載入失敗。引擎退出碼為 0，但存在 SCRIPT ERROR、ERROR 與 WARNING，因此驗證器退出碼為 1。
- 根因：取消舊 Autoload 註冊後，尚未執行步驟 5 的 DebugHUD 仍引用 Game、Clock、Alert、OfficeStorage、CaptureFlow。其解析失敗使 Panel/MovementStats 未建立，進而造成 FormLab 提示開關掛載錯誤與退出時洩漏警告。
- 依任何 ERROR／WARNING 立即停止規則，未執行步驟 2 的 MovementLab 載入，也未執行步驟 3–6、全量回歸、閉包重算或 manifest 產出。
- 保留步驟 1／2 的設定供檢視；目前主入口未通過載入驗證，不能視為可交付。沒有自行恢復 Autoload、調整步驟或套用白名單。
- 本輪只改動 project.godot 與本紀錄；員工診斷／統計／參數／AI 配置與玩法腳本均未改動。未提交／推送，未新增場景，未刪除檔案。

## 使用者修訂順序後繼續

依新順序 1–6 執行；前一輪失敗紀錄保留。任何 ERROR／WARNING 即停止。員工診斷型別、統計、參數與 AI 配置不變。

## 新順序步驟 1：保留已通過設定

- Input Map 與 FormLab 主入口不改。

## 新順序步驟 2：暫時恢復 Autoload 註冊

- 改動檔案：project.godot。
- 僅恢復 Game、Clock、Alert、OfficeStorage、CaptureFlow 註冊，Bus 保持註冊；其他設定不動。

### FormLab headless 載入

- 命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/borrowed-shapes-stage2/step-reordered-2-FormLab.log --quit-after 120 res://scenes/forms/form_lab.tscn`
- 退出碼：0。
- 結果：通過；無 ERROR／WARNING。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
```

### MovementLab headless 載入

- 命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/borrowed-shapes-stage2/step-reordered-2-MovementLab.log --quit-after 120 res://scenes/traversal/movement_lab.tscn`
- 退出碼：0。
- 結果：通過；無 ERROR／WARNING。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
```

## 新順序步驟 3：DebugHUD 解除舊世界依賴

- 改動檔案：content/ui/debug_hud.gd。
- 移除 9 處舊 Bus 訊號訂閱、舊員工 Debug 開關、背包文字與舊世界刷新分支；不再引用 Game、AnimalActor、StaffActor、RunSession、RouteExposure、Clock、Alert、OfficeStorage、CaptureFlow、GameConst、KitIds、IntelIds。
- 保留 F3 輸入與刷新頻率；_ensure_movement_controls 以後的面板建立、重置、複製、完整診斷及 movement_report 程式逐字不變，Panel/MovementStats 與員工診斷型別保留。

### FormLab headless 載入

- 命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/borrowed-shapes-stage2/step-reordered-3-FormLab.log --quit-after 120 res://scenes/forms/form_lab.tscn`
- 退出碼：0。
- 結果：通過；無 ERROR／WARNING。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
```

### MovementLab headless 載入

- 命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/borrowed-shapes-stage2/step-reordered-3-MovementLab.log --quit-after 120 res://scenes/traversal/movement_lab.tscn`
- 退出碼：0。
- 結果：通過；無 ERROR／WARNING。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
```

## 新順序步驟 4：FollowCamera 解除舊接線

- 改動檔案：core/camera/follow_camera.gd。
- 移除 Bus.animal_switched 訂閱、延後尋找 zoo_world／controlled_animal 與其兩個專用處理函式。
- 沿用 Lab 的 set_follow_target；set_follow_target、_process、_target_look_pos、_apply_camera_angle 與全部鏡頭數值不改。

### FormLab headless 載入

- 命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/borrowed-shapes-stage2/step-reordered-4-FormLab.log --quit-after 120 res://scenes/forms/form_lab.tscn`
- 退出碼：0。
- 結果：通過；無 ERROR／WARNING。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
```

### MovementLab headless 載入

- 命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/borrowed-shapes-stage2/step-reordered-4-MovementLab.log --quit-after 120 res://scenes/traversal/movement_lab.tscn`
- 退出碼：0。
- 結果：通過；無 ERROR／WARNING。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
```

## 新順序步驟 5：移除 Bus 訊號前檢查（阻擋，尚未修改 Bus）

- 目標核心閉包：36 個實質檔案、25 個 UID，共 61 檔，與先前假設 61 檔相同。
- 閉包內 Bus 成員引用只有 FormController:178 與 TraversalActor:339／588／651 的 noise_made；已無其他 Bus 訊號引用。
- 實際工程仍按步驟 2 註冊 Game、Clock、Alert、OfficeStorage、CaptureFlow。這些註冊不屬於目標閉包的種子，但仍會在每次啟動時建立。
- 啟動阻擋：gameplay/clock.gd:115 在 _ready 中執行 Bus.alert_changed.connect(_on_alert_changed)。此時刪除 alert_changed 將造成啟動錯誤。Clock另引用phase_changed／day_changed／interact_feedback；其他仍註冊的舊Autoload也引用舊Bus訊號。
- 在刪除前檢查停止，Bus未改動，也未自行提前執行步驟 6。這是靜態依賴阻擋，不是本輪已觀察到的 Godot ERROR／WARNING。
- 新順序步驟 2／3／4 的 FormLab 與 MovementLab，共 6 次沙盒外載入全部退出碼 0，無 ERROR／WARNING。
- 雜湊確認 gameplay/forms、gameplay/traversal、gameplay/staff、content/forms、content/traversal、content/staff 全部未變；相機set_follow_target之後的目標API／數學與原版完全相同；DebugHUD從_ensure_movement_controls開始的診斷函式完全相同。
- 步驟 5／6 未完成，尚未產出 migration-manifest.txt；尚未執行最終無舊Autoload驗證或宣稱移植就緒。
- 下一步需使用者明確授權：在 Bus 精簡前移除舊 Autoload 註冊並驗證，或將兩項設定改動視為同一個原子步驟後驗證。

## 合併步驟：唯讀靜態檢查通過

- 目標閉包：36個實質檔案、25個UID，共61檔。
- 閉包內對待移除Bus訊號及Game／Clock／Alert／OfficeStorage／CaptureFlow的引用均為0。
- 員工診斷型別／統計／參數與AI配置逐檔納入檢查，沒有待移除訊號或舊Autoload引用。
- 未發現Bus動態connect／emit_signal／索引存取。以下列出全專案仍引用待移除訊號的全部程式位置（排除註解與訊號宣告；Bus.get_script不是訊號，不列入）。

| 檔案 | 行號 | 訊號 | 目標閉包 |
|---|---:|---|---|
| content/interactables/gather_point.gd | 83 | day_changed | 外 |
| content/interactables/gather_point.gd | 152 | interact_feedback | 外 |
| content/interactables/gather_point.gd | 154 | interact_feedback | 外 |
| content/interactables/gather_point.gd | 157 | interact_feedback | 外 |
| content/interactables/gather_point.gd | 160 | interact_feedback | 外 |
| content/interactables/gather_point.gd | 173 | interact_feedback | 外 |
| content/interactables/gather_point.gd | 175 | interact_feedback | 外 |
| content/interactables/gather_point.gd | 177 | interact_feedback | 外 |
| content/interactables/gather_point.gd | 187 | interact_feedback | 外 |
| content/interactables/gather_point.gd | 192 | interact_feedback | 外 |
| content/interactables/gather_point.gd | 201 | interact_feedback | 外 |
| content/interactables/gather_point.gd | 210 | interact_feedback | 外 |
| content/interactables/gather_point.gd | 241 | material_gathered | 外 |
| content/interactables/gather_point.gd | 255 | interact_feedback | 外 |
| content/interactables/kit_pickup.gd | 91 | interact_feedback | 外 |
| content/interactables/kit_pickup.gd | 94 | interact_feedback | 外 |
| content/interactables/kit_pickup.gd | 103 | interact_feedback | 外 |
| content/interactables/observe_point.gd | 43 | intel_gained | 外 |
| content/interactables/observe_point.gd | 96 | interact_feedback | 外 |
| content/interactables/observe_point.gd | 100 | interact_feedback | 外 |
| content/interactables/observe_point.gd | 114 | interact_feedback | 外 |
| content/interactables/observe_point.gd | 129 | interact_feedback | 外 |
| content/interactables/observe_point.gd | 135 | interact_feedback | 外 |
| content/interactables/staff_cart.gd | 72 | interact_feedback | 外 |
| content/interactables/staff_cart.gd | 75 | interact_feedback | 外 |
| content/interactables/staff_cart.gd | 78 | interact_feedback | 外 |
| content/interactables/staff_cart.gd | 82 | interact_feedback | 外 |
| content/interactables/staff_cart.gd | 102 | material_gathered | 外 |
| content/interactables/staff_cart.gd | 103 | interact_feedback | 外 |
| content/interactables/staff_cart.gd | 109 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 77 | animal_rescued | 外 |
| content/levels/zoo_world.gd | 78 | run_outcome_changed | 外 |
| content/levels/zoo_world.gd | 79 | intel_gained | 外 |
| content/levels/zoo_world.gd | 80 | phase_changed | 外 |
| content/levels/zoo_world.gd | 119 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 177 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 182 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 246 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 270 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 272 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 277 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 341 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 373 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 386 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 442 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 478 | interact_feedback | 外 |
| content/levels/zoo_world.gd | 481 | interact_feedback | 外 |
| content/ui/day_banner.gd | 31 | day_summary | 外 |
| content/ui/game_hud.gd | 63 | interact_feedback | 外 |
| content/ui/hint_director.gd | 23 | material_gathered | 外 |
| content/ui/hint_director.gd | 24 | captured | 外 |
| content/ui/hint_director.gd | 25 | intel_gained | 外 |
| content/ui/hint_director.gd | 26 | animal_rescued | 外 |
| content/ui/hint_director.gd | 27 | phase_changed | 外 |
| content/ui/pause_menu.gd | 92 | interact_feedback | 外 |
| content/ui/run_result.gd | 16 | run_outcome_changed | 外 |
| gameplay/alert.gd | 12 | alert_changed | 外 |
| gameplay/alert.gd | 14 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 218 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 222 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 229 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 238 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 241 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 248 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 379 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 438 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 441 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 448 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 622 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 649 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 727 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 732 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 741 | interact_feedback | 外 |
| gameplay/animal_actor.gd | 787 | interact_feedback | 外 |
| gameplay/capture_flow.gd | 43 | interact_feedback | 外 |
| gameplay/capture_flow.gd | 50 | captured | 外 |
| gameplay/capture_flow.gd | 51 | detention_changed | 外 |
| gameplay/capture_flow.gd | 53 | interact_feedback | 外 |
| gameplay/capture_flow.gd | 69 | detention_changed | 外 |
| gameplay/capture_flow.gd | 74 | interact_feedback | 外 |
| gameplay/clock.gd | 12 | phase_changed | 外 |
| gameplay/clock.gd | 56 | day_changed | 外 |
| gameplay/clock.gd | 115 | alert_changed | 外 |
| gameplay/clock.gd | 125 | interact_feedback | 外 |
| gameplay/clock.gd | 131 | day_changed | 外 |
| gameplay/clock.gd | 157 | interact_feedback | 外 |
| gameplay/clock.gd | 159 | interact_feedback | 外 |
| gameplay/clock.gd | 161 | interact_feedback | 外 |
| gameplay/clock.gd | 163 | interact_feedback | 外 |
| gameplay/interaction/breach_builder.gd | 60 | interact_feedback | 外 |
| gameplay/interaction/breach_builder.gd | 133 | interact_feedback | 外 |
| gameplay/interaction/breach_builder.gd | 138 | interact_feedback | 外 |
| gameplay/interaction/breach_builder.gd | 142 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 92 | day_changed | 外 |
| gameplay/interaction/interactable.gd | 255 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 259 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 265 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 267 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 276 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 279 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 282 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 284 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 308 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 311 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 315 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 320 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 335 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 337 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 373 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 377 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 412 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 588 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 595 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 609 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 611 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 613 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 624 | interact_feedback | 外 |
| gameplay/interaction/interactable.gd | 669 | interact_feedback | 外 |
| gameplay/items/ground_item.gd | 50 | interact_feedback | 外 |
| gameplay/items/ground_item.gd | 55 | interact_feedback | 外 |
| gameplay/office_chest.gd | 44 | interact_feedback | 外 |
| gameplay/office_chest.gd | 47 | interact_feedback | 外 |
| gameplay/office_chest.gd | 66 | interact_feedback | 外 |
| gameplay/office_storage.gd | 14 | office_items_changed | 外 |
| gameplay/office_storage.gd | 26 | office_items_changed | 外 |
| gameplay/party_controller.gd | 45 | animal_rescued | 外 |
| gameplay/party_controller.gd | 70 | interact_feedback | 外 |
| gameplay/party_controller.gd | 75 | interact_feedback | 外 |
| gameplay/party_controller.gd | 77 | interact_feedback | 外 |
| gameplay/party_controller.gd | 99 | interact_feedback | 外 |
| gameplay/party_controller.gd | 118 | interact_feedback | 外 |
| gameplay/party_controller.gd | 141 | animal_switched | 外 |
| gameplay/run_session.gd | 28 | day_changed | 外 |
| gameplay/run_session.gd | 29 | day_changed | 外 |
| gameplay/run_session.gd | 30 | captured | 外 |
| gameplay/run_session.gd | 31 | animal_rescued | 外 |
| gameplay/run_session.gd | 56 | day_summary | 外 |
| gameplay/run_session.gd | 68 | run_outcome_changed | 外 |
| gameplay/run_session.gd | 69 | interact_feedback | 外 |
| gameplay/run_session.gd | 75 | breach_changed | 外 |
| gameplay/run_session.gd | 114 | intel_gained | 外 |
| gameplay/run_session.gd | 133 | breach_changed | 外 |
| gameplay/run_session.gd | 162 | run_outcome_changed | 外 |
| gameplay/run_session.gd | 163 | interact_feedback | 外 |
| gameplay/run_session.gd | 175 | run_outcome_changed | 外 |
| gameplay/run_session.gd | 176 | interact_feedback | 外 |
| gameplay/staff_actor.gd | 136 | day_changed | 外 |
| gameplay/staff_actor.gd | 299 | interact_feedback | 外 |
| gameplay/staff_actor.gd | 422 | interact_feedback | 外 |
| gameplay/staff_actor.gd | 517 | interact_feedback | 外 |
| gameplay/staff_actor.gd | 572 | interact_feedback | 外 |
| gameplay/staff_actor.gd | 718 | interact_feedback | 外 |
| gameplay/staff_actor.gd | 807 | interact_feedback | 外 |
| gameplay/staff_actor.gd | 1051 | interact_feedback | 外 |
| gameplay/staff_actor.gd | 1076 | interact_feedback | 外 |
| gameplay/trace/trace_marker.gd | 63 | interact_feedback | 外 |
| gameplay/trace/trace_service.gd | 11 | day_changed | 外 |
| gameplay/trace/trace_service.gd | 12 | day_changed | 外 |
| prototypes/p0_playtest.gd | 14 | interact_feedback | 外 |
| prototypes/p0_regression.gd | 15 | interact_feedback | 外 |
| prototypes/p0_walkthrough.gd | 23 | interact_feedback | 外 |
| prototypes/p2_alert_tiers.gd | 29 | interact_feedback | 外 |
| prototypes/p2_alert_tiers.gd | 334 | phase_changed | 外 |
| prototypes/p2_alert_tiers.gd | 337 | phase_changed | 外 |
| prototypes/p2_capture.gd | 12 | interact_feedback | 外 |
| prototypes/p2_confiscate.gd | 30 | interact_feedback | 外 |
| prototypes/p2_day_cycle.gd | 16 | day_summary | 外 |
| prototypes/p2_full_loop.gd | 27 | interact_feedback | 外 |
| prototypes/p2_noise_tools.gd | 31 | interact_feedback | 外 |
| prototypes/p2_route_clear.gd | 76 | interact_feedback | 外 |
| prototypes/p2_route_clear.gd | 94 | interact_feedback | 外 |
| prototypes/p2_route_work.gd | 14 | interact_feedback | 外 |
| prototypes/p2_stash.gd | 122 | interact_feedback | 外 |
| prototypes/p2_stash.gd | 128 | interact_feedback | 外 |
| prototypes/p2_stash.gd | 156 | interact_feedback | 外 |
| prototypes/p2_stash.gd | 158 | interact_feedback | 外 |
| prototypes/p2_ui.gd | 50 | interact_feedback | 外 |

合計37個檔案、177個來源行，全部位於目標閉包外。舊檔案保留，但舊世界與其回歸不屬本次可執行目標。

### FormLab headless 載入

- 命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/borrowed-shapes-stage2/step-combined-final-FormLab.log --quit-after 120 res://scenes/forms/form_lab.tscn`
- 退出碼：0。
- 結果：通過；無 ERROR／WARNING。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
```

### MovementLab headless 載入

- 命令：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --log-file /tmp/borrowed-shapes-stage2/step-combined-final-MovementLab.log --quit-after 120 res://scenes/traversal/movement_lab.tscn`
- 退出碼：0。
- 結果：通過；無 ERROR／WARNING。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org
```

## 合併步驟完成與最終閉包

- project.godot只註冊Bus；Game、Clock、Alert、OfficeStorage、CaptureFlow僅取消註冊，檔案未刪除。
- Bus只保留noise_made；形態狀態／冷卻／成功與拒絕回饋仍沿用FormController與Lab的本地訊號及文字鏈。
- 最終兩個Lab在沙盒外各載入120幀，退出碼均0，無ERROR／WARNING。未套用任何白名單。
- 重新遞迴計算：36個實質檔案＋25個UID＝61檔。與先前61檔情境的路徑集合一致，新增0／移除0。
- 閉包內不含Game、Clock、Alert、OfficeStorage、CaptureFlow檔案，亦無對它們的符號／資源引用；不含AnimalDef、AnimalActor、RunSession、KitIds、GameConst、PartyController、PatrolNetwork、StaffActor、IntelIds、RouteExposure、CompanionFollowParams。
- 員工診斷相關檔案保持原樣：StaffReadabilityMetrics、StaffReadabilityParams、StaffAiParams與readability_staff_ai_params.tres仍在閉包。
- migration-manifest.txt按scripts／resources／scenes／config分組，一個檔案路徑一行，包含全部UID。
- 沿用先前目標閉包口徑：保留MovementLab與FormLab兩個種子場景，project.godot作主入口／輸入／必要Autoload設定載體；應用圖示icon.svg及其匯入中繼資料未列入61檔。manifest是此階段核心遷移範圍，不是已封裝發行包；將來原樣搬整份project.godot時仍需處理其config/icon路徑。
- 閉包外舊世界與舊回歸保留原檔，但仍引用已移除訊號／Autoload；本輪不宣稱舊遊戲或全套舊回歸可執行。本輪驗收範圍為兩個Lab，未執行預期依賴舊接口的全量套件。

分組數量：scripts=50, resources=7, scenes=3, config=1。

## 完整性核對

- 核心與員工相關檔案未變：通過。
- 鏡頭目標API與數學逐字未變：通過。
- 面板／重置／複製／員工診斷函式逐字未變：通過。
- 只改動授權既有檔案：通過。
- 沒有刪除追蹤檔案：通過。

## Borrowed Shapes 名稱與封存內容清理

- 使用者確認正式名稱Borrowed Shapes，授權刪除舊動物園模組及其專用測試；保留61檔核心、開發工具與歷史證據。
- 刪除前兩次靜態檢查：保留程式／資源／場景對候選檔案的執行依賴為0；核心manifest重疊為0。
- 本輪刪除207個檔案（含UID）：
  - content/animal_def.gd
  - content/animal_def.gd.uid
  - content/animals/monkey.tres
  - content/animals/raccoon.tres
  - content/balance/action_cost_table.gd
  - content/balance/action_cost_table.gd.uid
  - content/balance/action_cost_table.tres
  - content/balance/alert_params.gd
  - content/balance/alert_params.gd.uid
  - content/balance/alert_params.tres
  - content/balance/day_cycle_params.gd
  - content/balance/day_cycle_params.gd.uid
  - content/balance/day_cycle_params.tres
  - content/balance/material_budget.gd
  - content/balance/material_budget.gd.uid
  - content/balance/route_work_check.gd
  - content/balance/route_work_check.gd.uid
  - content/balance/route_work_params.gd
  - content/balance/route_work_params.gd.uid
  - content/balance/route_work_params.tres
  - content/follow/default_companion_follow_params.tres
  - content/game_const.gd
  - content/game_const.gd.uid
  - content/intel_ids.gd
  - content/intel_ids.gd.uid
  - content/interactables/gather_point.gd
  - content/interactables/gather_point.gd.uid
  - content/interactables/kit_pickup.gd
  - content/interactables/kit_pickup.gd.uid
  - content/interactables/observe_point.gd
  - content/interactables/observe_point.gd.uid
  - content/interactables/staff_cart.gd
  - content/interactables/staff_cart.gd.uid
  - content/item_def.gd
  - content/item_def.gd.uid
  - content/items/metal.tres
  - content/items/rope.tres
  - content/items/route_kit.tres
  - content/items/wood.tres
  - content/kit_ids.gd
  - content/kit_ids.gd.uid
  - content/levels/zoo_p0_gather.gd
  - content/levels/zoo_p0_gather.gd.uid
  - content/levels/zoo_p0_geometry.gd
  - content/levels/zoo_p0_geometry.gd.uid
  - content/levels/zoo_p0_intel.gd
  - content/levels/zoo_p0_intel.gd.uid
  - content/levels/zoo_p0_patrol.gd
  - content/levels/zoo_p0_patrol.gd.uid
  - content/levels/zoo_p0_spawns.gd
  - content/levels/zoo_p0_spawns.gd.uid
  - content/levels/zoo_world.gd
  - content/levels/zoo_world.gd.uid
  - content/ui/day_banner.gd
  - content/ui/day_banner.gd.uid
  - content/ui/game_hud.gd
  - content/ui/game_hud.gd.uid
  - content/ui/guidance_model.gd
  - content/ui/guidance_model.gd.uid
  - content/ui/guidance_params.gd
  - content/ui/guidance_params.gd.uid
  - content/ui/guidance_params.tres
  - content/ui/hint_director.gd
  - content/ui/hint_director.gd.uid
  - content/ui/pause_menu.gd
  - content/ui/pause_menu.gd.uid
  - content/ui/run_result.gd
  - content/ui/run_result.gd.uid
  - content/ui/start_select.gd
  - content/ui/start_select.gd.uid
  - core/autoload/game.gd
  - core/autoload/game.gd.uid
  - gameplay/alert.gd
  - gameplay/alert.gd.uid
  - gameplay/animal_actor.gd
  - gameplay/animal_actor.gd.uid
  - gameplay/capture_flow.gd
  - gameplay/capture_flow.gd.uid
  - gameplay/clock.gd
  - gameplay/clock.gd.uid
  - gameplay/companion_follow_params.gd
  - gameplay/companion_follow_params.gd.uid
  - gameplay/interaction/breach_builder.gd
  - gameplay/interaction/breach_builder.gd.uid
  - gameplay/interaction/cage_dependency_check.gd
  - gameplay/interaction/cage_dependency_check.gd.uid
  - gameplay/interaction/interactable.gd
  - gameplay/interaction/interactable.gd.uid
  - gameplay/items/ground_item.gd
  - gameplay/items/ground_item.gd.uid
  - gameplay/items/thrown_stone.gd
  - gameplay/items/thrown_stone.gd.uid
  - gameplay/office_chest.gd
  - gameplay/office_chest.gd.uid
  - gameplay/office_storage.gd
  - gameplay/office_storage.gd.uid
  - gameplay/party_controller.gd
  - gameplay/party_controller.gd.uid
  - gameplay/route_exposure.gd
  - gameplay/route_exposure.gd.uid
  - gameplay/run_lifecycle.gd
  - gameplay/run_lifecycle.gd.uid
  - gameplay/run_session.gd
  - gameplay/run_session.gd.uid
  - gameplay/staff/patrol_network.gd
  - gameplay/staff/patrol_network.gd.uid
  - gameplay/staff/staff_debug_draw.gd
  - gameplay/staff/staff_debug_draw.gd.uid
  - gameplay/staff/staff_sense.gd
  - gameplay/staff/staff_sense.gd.uid
  - gameplay/staff_actor.gd
  - gameplay/staff_actor.gd.uid
  - gameplay/trace/trace_marker.gd
  - gameplay/trace/trace_marker.gd.uid
  - gameplay/trace/trace_service.gd
  - gameplay/trace/trace_service.gd.uid
  - prototypes/p0_climb_fly_repro.gd
  - prototypes/p0_climb_fly_repro.gd.uid
  - prototypes/p0_climb_fly_repro.tscn
  - prototypes/p0_enclosure_check.gd
  - prototypes/p0_enclosure_check.gd.uid
  - prototypes/p0_enclosure_check.tscn
  - prototypes/p0_playtest.gd
  - prototypes/p0_playtest.gd.uid
  - prototypes/p0_playtest.tscn
  - prototypes/p0_regression.gd
  - prototypes/p0_regression.gd.uid
  - prototypes/p0_regression.tscn
  - prototypes/p0_walkthrough.gd
  - prototypes/p0_walkthrough.gd.uid
  - prototypes/p0_walkthrough.tscn
  - prototypes/p1_win_routes.gd
  - prototypes/p1_win_routes.gd.uid
  - prototypes/p1_win_routes.tscn
  - prototypes/p2_action_cost.gd
  - prototypes/p2_action_cost.gd.uid
  - prototypes/p2_action_cost.tscn
  - prototypes/p2_alert_tiers.gd
  - prototypes/p2_alert_tiers.gd.uid
  - prototypes/p2_alert_tiers.tscn
  - prototypes/p2_capture.gd
  - prototypes/p2_capture.gd.uid
  - prototypes/p2_capture.tscn
  - prototypes/p2_cart.gd
  - prototypes/p2_cart.gd.uid
  - prototypes/p2_cart.tscn
  - prototypes/p2_confiscate.gd
  - prototypes/p2_confiscate.gd.uid
  - prototypes/p2_confiscate.tscn
  - prototypes/p2_day_cycle.gd
  - prototypes/p2_day_cycle.gd.uid
  - prototypes/p2_day_cycle.tscn
  - prototypes/p2_exposure.gd
  - prototypes/p2_exposure.gd.uid
  - prototypes/p2_exposure.tscn
  - prototypes/p2_follow_trail.gd
  - prototypes/p2_follow_trail.gd.uid
  - prototypes/p2_follow_trail.tscn
  - prototypes/p2_full_loop.gd
  - prototypes/p2_full_loop.gd.uid
  - prototypes/p2_full_loop.tscn
  - prototypes/p2_gather.gd
  - prototypes/p2_gather.gd.uid
  - prototypes/p2_gather.tscn
  - prototypes/p2_guidance.gd
  - prototypes/p2_guidance.gd.uid
  - prototypes/p2_guidance.tscn
  - prototypes/p2_intel.gd
  - prototypes/p2_intel.gd.uid
  - prototypes/p2_intel.tscn
  - prototypes/p2_noise_tools.gd
  - prototypes/p2_noise_tools.gd.uid
  - prototypes/p2_noise_tools.tscn
  - prototypes/p2_outer_walls.gd
  - prototypes/p2_outer_walls.gd.uid
  - prototypes/p2_outer_walls.tscn
  - prototypes/p2_rescue_rendezvous.gd
  - prototypes/p2_rescue_rendezvous.gd.uid
  - prototypes/p2_rescue_rendezvous.tscn
  - prototypes/p2_route_clear.gd
  - prototypes/p2_route_clear.gd.uid
  - prototypes/p2_route_clear.tscn
  - prototypes/p2_route_work.gd
  - prototypes/p2_route_work.gd.uid
  - prototypes/p2_route_work.tscn
  - prototypes/p2_run_reset.gd
  - prototypes/p2_run_reset.gd.uid
  - prototypes/p2_run_reset.tscn
  - prototypes/p2_staff_patrol.gd
  - prototypes/p2_staff_patrol.gd.uid
  - prototypes/p2_staff_patrol.tscn
  - prototypes/p2_stash.gd
  - prototypes/p2_stash.gd.uid
  - prototypes/p2_stash.tscn
  - prototypes/p2_ui.gd
  - prototypes/p2_ui.gd.uid
  - prototypes/p2_ui.tscn
  - prototypes/route_helper.gd
  - prototypes/route_helper.gd.uid
  - prototypes/zb_check.gd
  - prototypes/zb_check.gd.uid
  - scenes/actors/animal.tscn
  - scenes/boot/main.tscn
  - scenes/boot/start_select.tscn
  - scenes/ui/run_result.tscn
  - scenes/world/zoo_p0.tscn
  - scenes/world/zoo_p0_geometry.tscn

- 現行README、設計／架構／技術／範圍與代理指引對齊擬態核心；歷史文件／QA證據原文保留。
- 專案品牌改為Borrowed Shapes；猴形態資源／id不改；員工診斷型別、統計、參數與AI配置不改。
- 核心門禁更新為兩個Lab載入與五個保留回歸；WARNING維持失敗，任何失敗立即停止。
- 尚未進行新專案移植，未提交／推送。驗證待執行。

### 名稱／內容清理後 headless import

- 退出碼：0。
- 結果：通過，無ERROR／WARNING。

```text
Godot Engine v4.7.stable.official.5b4e0cb0f - https://godotengine.org

[   0% ] [90m[1mfirst_scan_filesystem[22m | Started 项目初始化 (5 steps)[39m[0m
[   0% ] [90m[1mfirst_scan_filesystem[22m | 正在扫描文件结构……[39m[0m
[  16% ] [90m[1mfirst_scan_filesystem[22m | 正在加载全局类名……[39m[0m
[  33% ] [90m[1mfirst_scan_filesystem[22m | 正在校验 GDExtension……[39m[0m
[  50% ] [90m[1mfirst_scan_filesystem[22m | 正在创建自动加载脚本……[39m[0m
[  66% ] [90m[1mfirst_scan_filesystem[22m | 正在初始化插件……[39m[0m
[  83% ] [90m[1mfirst_scan_filesystem[22m | 正在启动文件扫描……[39m[0m
[92m[ DONE ][39m [1mfirst_scan_filesystem[22m
[0m
[   0% ] [90m[1mupdate_scripts_classes[22m | Started 正在注册全局类…… (5 steps)[39m[0m
[   0% ] [90m[1mupdate_scripts_classes[22m | EventNames[39m[0m
[  16% ] [90m[1mupdate_scripts_classes[22m | ProximityLabel[39m[0m
[  33% ] [90m[1mupdate_scripts_classes[22m | FormDef[39m[0m
[  50% ] [90m[1mupdate_scripts_classes[22m | GroundFormActor[39m[0m
[  66% ] [90m[1mupdate_scripts_classes[22m | [39m[0m
[92m[ DONE ][39m [1mupdate_scripts_classes[22m
[0m
[   0% ] [90m[1mloading_editor_layout[22m | Started 正在加载编辑器 (5 steps)[39m[0m
[   0% ] [90m[1mloading_editor_layout[22m | 正在加载编辑器布局……[39m[0m
[  16% ] [90m[1mloading_editor_layout[22m | 正在加载停靠面板……[39m[0m
[  33% ] [90m[1mloading_editor_layout[22m | 正在重新打开场景……[39m[0m
[  50% ] [90m[1mloading_editor_layout[22m | 正在加载中央编辑器布局……[39m[0m
[  66% ] [90m[1mloading_editor_layout[22m | 正在加载插件窗口布局……[39m[0m
[  83% ] [90m[1mloading_editor_layout[22m | 编辑器布局就绪。[39m[0m
[92m[ DONE ][39m [1mloading_editor_layout[22m
[0m
```

### 名稱／內容清理後核心門禁：失敗，已停止

```text
✓ form_lab                   
✓ movement_lab               
✗ p2_traversal               exit=1 === P2 TRAVERSAL SUMMARY pass=148 fail=1 ===
    FAIL 測試場景退出清除專用按鍵
RED: p2_traversal — logs: /tmp/borrowed-shapes-cleanup/tests
```

- headless import通過；FormLab與MovementLab載入通過。
- p2_traversal：148 pass／1 fail，退出碼1。失敗斷言「測試場景退出清除專用按鍵」仍要求移除traversal_jump；目前Input Map已永久定義該action，MovementLab只會移除自己新增的action。未改動此斷言或角色行為來繞過門禁。
- 依失敗立即停止規則，p2_forms、p2_staff_readability、p2_staff_awareness、p2_hygiene未執行；沒有宣稱本輪全綠。
- 實際刪除207檔；61檔核心缺失0；移動／形態核心行為腳本內容變動0；保留員工來源／配置內容變動0。
- 本輪改動保留在工作區供檢視，沒有自行回復或繼續修補，未提交／推送。
- 下一步需確認回歸應改驗「工程既有action退出仍保留、場景自行新增action退出才移除」；本輪尚未修改。

### 輸入生命週期回歸修正：2026-10-16

- 使用者授權僅修改測試：prototypes/p2_traversal.gd、prototypes/p2_forms.gd。兩者新增既有 action 不覆寫／不移除、缺少 action 時由場景建立且退出清除、測試後恢復原鍵位與 deadzone 的檢查。未修改控制器、場景、Input Map 或員工診斷。
- 沙盒外執行 tools/run_tests.sh，退出碼 1；完整輸出 /tmp/borrowed-shapes-input-lifecycle/tests.stdout.txt，各套件輸出 /tmp/borrowed-shapes-input-lifecycle/tests/。

```text
✓ form_lab                   
✓ movement_lab               
✓ p2_traversal               === P2 TRAVERSAL SUMMARY pass=156 fail=0 ===
✓ p2_forms                   === P2 FORMS A SUMMARY pass=113 fail=0 ===
✗ p2_staff_readability       exit=1 === P2 STAFF READABILITY SUMMARY pass=96 fail=1 ===
    FAIL F3 合併員工與凍結移動統計
RED: p2_staff_readability — logs: /tmp/borrowed-shapes-input-lifecycle/tests
```

- form_lab、movement_lab、p2_traversal（156/156）、p2_forms（113/113）通過。p2_staff_readability（96 pass／1 fail）在「F3 合併員工與凍結移動統計」失敗，依門禁立即停止；p2_staff_awareness、p2_hygiene 未執行。未自行修補失敗項，未提交或推送。

### 員工統計標題回歸修正：2026-10-16

- 使用者授權更新 prototypes/p2_staff_readability.gd:205，將舊標題比對改為「移動統計｜來源：」，仍要求報告同時包含員工與移動統計。未修改員工診斷、參數、AI、場景或遊戲行為。
- 沙盒外完整七項門禁退出碼 0；無 ERROR、WARNING、FAIL、FINDING 或 TIMEOUT。完整輸出 /tmp/borrowed-shapes-title-regression/tests.stdout.txt。

```text
✓ form_lab                   
✓ movement_lab               
✓ p2_traversal               === P2 TRAVERSAL SUMMARY pass=156 fail=0 ===
✓ p2_forms                   === P2 FORMS A SUMMARY pass=113 fail=0 ===
✓ p2_staff_readability       === P2 STAFF READABILITY SUMMARY pass=97 fail=0 ===
✓ p2_staff_awareness         === P2 STAFF AWARENESS SUMMARY pass=12 fail=0 ===
✓ p2_hygiene                 === P2 HYGIENE SUMMARY pass=5 fail=0 ===

ALL GREEN (7 checks) — logs: /tmp/borrowed-shapes-title-regression/tests
```

- git diff --check 通過。未提交或推送。headless 結果不替代實機視覺與手感驗收。

### 舊名稱殘留整理：2026-10-16

- prototypes/p2_traversal.gd：四個新測試產物的 /tmp/zoo_ 前綴改為 /tmp/borrowed_shapes_；未搬移或改寫既有產物。
- docs/MOVEMENT_SLICE.md、docs/STAFF_READABILITY.md、docs/FORMS_SLICE.md：同步 FormLab 主入口與獨立回歸入口，將已刪模組及被取代方案標為歷史；不改驗收規則。
- docs/qa_reports/latest_report.md：舊產品問題改為歷史索引，原說明保留為引用。歷史文件、驗證輸出、遠端URL、專案目錄名稱與工具指引未變更。
- 沙盒外 tools/run_tests.sh 退出碼 0，無 ERROR、WARNING、FAIL、FINDING 或 TIMEOUT；git diff --check 通過。完整輸出 /tmp/borrowed-shapes-residue-cleanup/tests.stdout.txt。

```text
✓ form_lab                   
✓ movement_lab               
✓ p2_traversal               === P2 TRAVERSAL SUMMARY pass=156 fail=0 ===
✓ p2_forms                   === P2 FORMS A SUMMARY pass=113 fail=0 ===
✓ p2_staff_readability       === P2 STAFF READABILITY SUMMARY pass=97 fail=0 ===
✓ p2_staff_awareness         === P2 STAFF AWARENESS SUMMARY pass=12 fail=0 ===
✓ p2_hygiene                 === P2 HYGIENE SUMMARY pass=5 fail=0 ===

ALL GREEN (7 checks) — logs: /tmp/borrowed-shapes-residue-cleanup/tests
```

- 未修改遊戲行為、員工診斷／參數／AI、設定或場景；未新增場景、刪除檔案、提交或推送。
