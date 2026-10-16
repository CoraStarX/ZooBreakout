class_name GuidanceModel
extends RefCounted
## 純呈現函式：輸入唯讀快照與上次推薦，輸出文字及路線；不讀場景或修改玩法。

static func choose_route(routes: Array, previous: String, params: GuidanceParams) -> Dictionary:
	var ordered := routes.duplicate()
	ordered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a.id) < String(b.id))
	var best: Dictionary = {}
	for route: Dictionary in ordered:
		if bool(route.get("ready", false)):
			continue
		# 已投入的推薦線保持穩定，不因換控、距離或背包波動而跳線。
		if params.retain_invested_route and String(route.id) == previous and bool(route.get("invested", false)):
			return route
		if best.is_empty() or float(route.get("progress", 0.0)) > float(best.get("progress", 0.0)):
			best = route
		elif float(route.get("progress", 0.0)) == float(best.get("progress", 0.0)) and bool(route.get("invested", false)) and not bool(best.get("invested", false)):
			best = route
	return best


static func derive(state: Dictionary, previous: String, params: GuidanceParams) -> Dictionary:
	var routes: Array = state.get("routes", [])
	var route := choose_route(routes, previous, params)
	var id := String(route.get("id", previous))
	var result := {"stage": &"gather", "title": "收集材料", "detail": "白天搜集材料，夜間施工。", "route": id}
	for gate in params.priority:
		match gate:
			&"finished":
				if bool(state.get("finished", false)):
					return _result(&"finished", "查看結算", String(state.get("outcome_reason", "本局已結束。")), id)
			&"detained":
				if bool(state.get("detained", false)):
					return _result(&"detained", "被拘留：等待釋放", "可在籠內活動；有可控制同伴時，按 Tab 切換。", id)
			&"search":
				if bool(state.get("full_search", false)):
					return _result(&"search", "全園搜查：避開員工", "施工已中止；等待警戒降低後再施工。", id)
			&"rescue":
				if bool(state.get("pending_rescue", false)):
					return _result(&"rescue", "救出同伴", "靠近同伴籠門按 E 開鎖；若仍在自己的展區，先打開籠門。", id)
			&"exit":
				for r: Dictionary in routes:
					if bool(r.get("ready", false)):
						return _result(&"exit", "全員前往出口", "經由%s出園；按 F 讓同伴跟隨。所有同伴都必須獲救且到達出口，被關押者也須先獲釋。" % r.name, id)
			&"route":
				if route.is_empty():
					continue
				var name := String(route.name)
				if bool(state.get("night", false)):
					if bool(route.get("can_work", false)):
						return _result(&"work", "夜間施工：%s" % name, "靠近按 E；%s" % ("可直接使用背包材料，不必先存料。Soft 較安全。" if bool(route.get("soft_ready", false)) else "目前需強行（Hard）：較慢、較吵且留下痕跡；也可白天補料後用 Soft。"), id)
					return _result(&"gather", "收集材料：%s" % name, "目前無人能支付本檔；白天補齊材料或套件，再回來施工。", id)
				if params.suggest_day_deposit and bool(route.get("deposit_useful", false)):
					return _result(&"deposit", "存入施工點：%s" % name, "靠近施工點按 X 存料；這是運輸建議，夜間也能直接從背包支付。", id)
				if bool(route.get("soft_ready", false)):
					return _result(&"wait", "等待夜晚施工：%s" % name, "本檔已具備施工條件；白天可繼續偵察或準備後續材料。", id)
				return _result(&"gather", "收集材料：%s" % name, "白天搜集本檔材料或套件；施工點存料可與實際施工者背包合併支付。", id)
	return result


static func _result(stage: StringName, title: String, detail: String, route: String) -> Dictionary:
	return {"stage": stage, "title": title, "detail": detail, "route": route}
