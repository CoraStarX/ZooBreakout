extends RefCounted
## Content: observation points for zoo_p0 (data only). "reward" is an IntelIds id.
## Closer to the patrol loop = easier to see, easier to get spotted.

const POINTS: Array[Dictionary] = [
	{"name": "了望坡（看歇岗）", "pos": Vector3(-2.0, 0.05, 3.2), "reward": &"rest_time"},
	{"name": "东侧树丛（看路线）", "pos": Vector3(10.5, 0.05, 3.5), "reward": &"patrol_route"},
]
