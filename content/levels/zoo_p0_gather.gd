extends RefCounted
## Content: daytime gather points for zoo_p0. Data only — the geometry node instantiates them.
## mat: KitIds material id yielded. cap: CapabilityIds.Id the rich stash needs (0 = none).
## rich/poor = amount with / without the verb. Metal is scarce and sits near staff (or on their cart).

const POINTS: Array[Dictionary] = [
	{"name": "饲料柜", "pos": Vector3(-6.8, 0.05, -4.2), "mat": &"wood", "cap": 1, "rich": 2, "poor": 1, "hint": "上锁的柜子"},
	{"name": "高处树杈", "pos": Vector3(7.4, 0.05, -1.9), "mat": &"wood", "cap": 2, "rich": 2, "poor": 1, "hint": "挂在高处"},
	{"name": "南侧杂物堆", "pos": Vector3(2.5, 0.05, -9.0), "mat": &"wood", "cap": 0, "rich": 1, "poor": 1, "hint": "地上捡"},
	{"name": "晾衣架", "pos": Vector3(-10.5, 0.05, -5.0), "mat": &"rope", "cap": 2, "rich": 2, "poor": 1, "hint": "挂在高处"},
	{"name": "游客遗落的绳", "pos": Vector3(0.0, 0.05, 3.0), "mat": &"rope", "cap": 0, "rich": 1, "poor": 1, "hint": "地上捡"},
	{"name": "垃圾桶（铁罐）", "pos": Vector3(-3.5, 0.05, 5.5), "mat": &"metal", "cap": 0, "rich": 1, "poor": 1, "hint": "翻翻看"},
	{"name": "职员工具间", "pos": Vector3(6.6, 0.05, 3.6), "mat": &"metal", "cap": 1, "rich": 3, "poor": 1, "hint": "职员巡逻路线旁，油水多"},
]
