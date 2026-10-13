class_name MaterialBudget
extends RefCounted
## Material supply vs route demand (docs/COST_REFACTOR.md「材料预算」). Pure data in, numbers out.
## supply: {"once": {mat: n}, "kits": n, "repeat": [{"mat", "yield", "daily_cap", "run_cap"}]}
## line:   {"name", "tiers", "kit_tiers", "tier_cost": Array[StringName], "kit_id"}
## Paths: Soft = every tier paid (kit or materials); Hard = non-final tiers forced for free, final tier Soft.


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


## Materials one line needs. `use_kit` = the kit pays its `kit_tiers`; `hard` = non-final tiers are forced (free).
static func need(line: Dictionary, use_kit: bool, hard: bool = false) -> Dictionary:
	var tiers := int(line["tiers"])
	var paid := 1 if hard else tiers - (int(line["kit_tiers"]) if use_kit else 0)
	var out := {}
	for m in line["tier_cost"]:
		out[m] = int(out.get(m, 0)) + clampi(paid, 0, tiers)
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


static func feasible_with_kit(line: Dictionary, supply: Dictionary, fallback_days: int) -> bool:
	return int(supply["kits"]) > 0 and int(line["kit_tiers"]) > 0 \
		and covers(need(line, true), total(supply, fallback_days))


static func feasible_soft_no_kit(line: Dictionary, supply: Dictionary, fallback_days: int) -> bool:
	return covers(need(line, false), total(supply, fallback_days))


static func feasible_hard(line: Dictionary, supply: Dictionary, fallback_days: int) -> bool:
	return covers(need(line, false, true), total(supply, fallback_days))


## Both lines on the Soft path (no forcing), trying every way of handing out the kits (≤ 1 per line).
static func both_soft_feasible(a: Dictionary, b: Dictionary, supply: Dictionary, fallback_days: int) -> bool:
	var have := total(supply, fallback_days)
	var kits := int(supply["kits"])
	for ka in [false, true]:
		for kb in [false, true]:
			if (int(ka) + int(kb)) > kits:
				continue
			if (ka and int(a["kit_tiers"]) == 0) or (kb and int(b["kit_tiers"]) == 0):
				continue
			if covers(_sum(need(a, ka), need(b, kb)), have):
				return true
	return false


static func both_hard_feasible(a: Dictionary, b: Dictionary, supply: Dictionary, fallback_days: int) -> bool:
	return covers(_sum(need(a, false, true), need(b, false, true)), total(supply, fallback_days))


static func _sum(x: Dictionary, y: Dictionary) -> Dictionary:
	var out := x.duplicate()
	for m in y:
		out[m] = int(out.get(m, 0)) + int(y[m])
	return out


## Load-time guard: (a) every line buildable with the kit AND without it via Hard; (b) Soft double over supply.
static func validate(lines: Array, supply: Dictionary, fallback_days: int) -> PackedStringArray:
	var errors := PackedStringArray()
	var have := total(supply, fallback_days)
	for line in lines:
		if not feasible_with_kit(line, supply, fallback_days):
			errors.append("材料不足：%s 用套件也凑不齐（需 %s，全图+保底 %d 天共 %s）" % [
				line["name"], need(line, true), fallback_days, have
			])
		if not feasible_hard(line, supply, fallback_days):
			errors.append("材料不足：%s 不用套件走强行也凑不齐最后一档（需 %s，共 %s）" % [
				line["name"], need(line, false, true), have
			])
	if lines.size() >= 2 and both_soft_feasible(lines[0], lines[1], supply, fallback_days):
		errors.append("材料过多：Soft 路径下两条线都能做完（%s）" % have)
	return errors
