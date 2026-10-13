extends RefCounted
## Content: daytime gather points for zoo_p0. Data only — the geometry node instantiates them.
## mat: KitIds material id yielded. cap: CapabilityIds.Id the rich stash needs (0 = none).
## rich = units at the point (taken all at once with the verb); poor = units per grab without it (rest stays).
## refresh: "once" (whole run, no restock) / "daily_pool" (R6, fields only) / "repeatable" (fallback, see ActionCostTable).
## daily_pool keys reserved for R6: "pool" (Array[Vector3] candidate spots), "pool_daily" (spawns per dawn),
## "pool_pity" (dry days before a forced spawn).
## Totals are budgeted: docs/COST_REFACTOR.md「材料预算」; checked at load by MaterialBudget.

const POINTS: Array[Dictionary] = [
	{"name": "饲料柜", "pos": Vector3(-6.8, 0.05, -4.2), "mat": &"wood", "cap": 1, "rich": 2, "poor": 1, "hint": "上锁的柜子", "refresh": "once"},
	{"name": "晾衣架", "pos": Vector3(-10.5, 0.05, -5.0), "mat": &"rope", "cap": 2, "rich": 1, "poor": 1, "hint": "挂在高处", "refresh": "once"},
	{"name": "游客遗落的绳", "pos": Vector3(0.0, 0.05, 3.0), "mat": &"rope", "cap": 0, "rich": 1, "poor": 1, "hint": "地上捡", "refresh": "once"},
	{"name": "垃圾桶（铁罐）", "pos": Vector3(-3.5, 0.05, 5.5), "mat": &"metal", "cap": 0, "rich": 1, "poor": 1, "hint": "翻翻看", "refresh": "repeatable"},
	{"name": "职员工具间", "pos": Vector3(6.6, 0.05, 3.6), "mat": &"metal", "cap": 1, "rich": 1, "poor": 1, "hint": "职员巡逻路线旁", "refresh": "once"},
]
