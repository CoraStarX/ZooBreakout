class_name MaterialBudget
extends RefCounted
## Material supply vs route demand (docs/COST_REFACTOR.md「材料预算」). Pure data in, numbers out.
## supply: {"once": {mat: n}, "kits": n, "repeat": [{"mat", "yield", "daily_cap", "run_cap"}]}
## line:   {"name", "tiers", "kit_tiers", "tier_cost": Array[StringName], "kit_id"}


static func line_from(i: Interactable) -> Dictionary:
	return {
		"name": i.display_name,
		"tiers": i.tiers,
		"kit_tiers": GameConst.KIT_TIERS if i.route_kit_id != &"" else 0,
		"tier_cost": i.tier_cost.duplicate(),
		"kit_id": i.route_kit_id,
	}


static func supply_from(points: Array, cart_loot: int, kits: int) -> Dictionary:
	var once := {}
	var repeat: Array = []
	var cost := GameConst.action_cost()
	for p in points:
		var gp := p as GatherPoint
		if gp.refresh_mode == GatherPoint.RefreshMode.REPEATABLE:
			repeat.append({
				"mat": gp.material, "yield": cost.gather_repeat_yield,
				"daily_cap": cost.gather_repeat_daily_cap, "run_cap": cost.gather_repeat_run_cap,
			})
		else:
			once[gp.material] = int(once.get(gp.material, 0)) + gp.once_supply()
	once[KitIds.METAL] = int(once.get(KitIds.METAL, 0)) + cart_loot
	return {"once": once, "kits": kits, "repeat": repeat}


## Materials one line still needs; `use_kit` = the kit pays its `kit_tiers`.
static func need(line: Dictionary, use_kit: bool) -> Dictionary:
	var paid := int(line["tiers"]) - (int(line["kit_tiers"]) if use_kit else 0)
	var out := {}
	for m in line["tier_cost"]:
		out[m] = int(out.get(m, 0)) + maxi(paid, 0)
	return out


## Units the repeatable points can give over `days` daytimes (bounded by daily and run caps).
static func fallback(supply: Dictionary, days: int) -> Dictionary:
	var out := {}
	for r in supply["repeat"]:
		var finds := int(r["daily_cap"]) * maxi(days, 0)
		if int(r["run_cap"]) > 0:
			finds = mini(finds, int(r["run_cap"]))
		out[r["mat"]] = int(out.get(r["mat"], 0)) + finds * int(r["yield"])
	return out


static func covers(want: Dictionary, have: Dictionary) -> bool:
	for m in want:
		if int(want[m]) > int(have.get(m, 0)):
			return false
	return true


static func total(supply: Dictionary, fallback_days: int) -> Dictionary:
	var out: Dictionary = (supply["once"] as Dictionary).duplicate()
	var fb := fallback(supply, fallback_days)
	for m in fb:
		out[m] = int(out.get(m, 0)) + int(fb[m])
	return out


static func line_feasible(line: Dictionary, supply: Dictionary, fallback_days: int) -> bool:
	var have := total(supply, fallback_days)
	if int(supply["kits"]) > 0 and int(line["kit_tiers"]) > 0 and covers(need(line, true), have):
		return true
	return covers(need(line, false), have)


## Every way of handing out the kits (at most one per line) — true if some split builds both lines.
static func both_feasible(a: Dictionary, b: Dictionary, supply: Dictionary, fallback_days: int) -> bool:
	var have := total(supply, fallback_days)
	var kits := int(supply["kits"])
	for ka in [false, true]:
		for kb in [false, true]:
			if (int(ka) + int(kb)) > kits:
				continue
			if (ka and int(a["kit_tiers"]) == 0) or (kb and int(b["kit_tiers"]) == 0):
				continue
			var want := need(a, ka)
			var wb := need(b, kb)
			for m in wb:
				want[m] = int(want.get(m, 0)) + int(wb[m])
			if covers(want, have):
				return true
	return false


## Load-time guard: each line must be buildable from the map's supply plus the fallback over the run.
static func validate(lines: Array, supply: Dictionary, fallback_days: int) -> PackedStringArray:
	var errors := PackedStringArray()
	var have := total(supply, fallback_days)
	for line in lines:
		if not line_feasible(line, supply, fallback_days):
			errors.append("材料不足：%s 即使用上套件也凑不齐（需 %s，全图+保底 %d 天共 %s）" % [
				line["name"], need(line, int(supply["kits"]) > 0), fallback_days, have
			])
	return errors
