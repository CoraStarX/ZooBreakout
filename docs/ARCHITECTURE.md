# Borrowed Shapes — 架構

依賴只允許Content → GamePlay → Core。GamePlay可讀共用資料型別／Resource；Core不得引用具體玩法角色、關卡或內容腳本。

| 層 | 現行責任 |
|---|---|
| Core | 單一噪音Bus、跟隨鏡頭、世界標籤、偏好工具 |
| GamePlay | 移動／攀爬／跨越、形態規則與控制器、局部感知與診斷資料 |
| Content | 形態／移動Resource、灰盒宿主、UIKit與診斷面板 |

## 資料與接線

- project.godot提供Input Map；唯一Autoload是Bus，唯一訊號是noise_made。
- FormLab繼承MovementLab並建立FormController；FormSetup指定開局、可用形態與出生位置。
- FormDef提供能力、尺寸、速度及移動設定；FormParams提供冷卻與有界擺放參數。
- FormController按能力建立TraversalActor或GroundFormActor，不按形態id分支。
- MovementLab建立攀爬面／跨越連結、鏡頭、陰影與HUD；FormLab替換角色後明確呼叫set_follow_target。
- form_changed／transform_committed／feedback與移動診斷均為本地訊號，不需全域遊戲狀態。
- DebugHUD只接受移動與可選員工統計；保留Panel/MovementStats、F3、重置與複製。
- 員工診斷型別與配置保留原樣，未接入FormLab；不宣稱整合潛行迴路已驗收。

## 已驗收邊界

保持45°正交、接地投影與遮擋淡出。鏡頭目標API與數學、移動、變形、攀爬、跨越行為不得因命名整理而變動。

新Shader、鏡頭數學、Autoload／全域狀態機須先提方案。幾何資料留在Resource，規則不嵌入具體場景名稱。

## 驗證與移植

統一門禁為tools/run_tests.sh；p2_hygiene檢查分層與Bus事件登記。核心閉包為36個實質檔案＋25個UID，見[migration-manifest.txt](migration-manifest.txt)。

兩個Lab共用實作，但場景入口不同：FormLab是產品主入口，MovementLab保留作回歸夾具。應用圖示與開發工具不在61檔目標閉包內，實際移植尚未進行。

歷史架構裁決以版本封存及既有驗證證據查閱，不重新帶入現行核心。
