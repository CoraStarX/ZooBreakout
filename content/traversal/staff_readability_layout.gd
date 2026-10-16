class_name StaffReadabilityLayout
extends Resource
@export var player_spawn: Vector3 = Vector3(-8.8,0.04,5)
@export var spawn: Vector3 = Vector3(-7.4,0,2.6)
@export var route: Array[Vector3] = [Vector3(-3,0,2.6),Vector3(1.3,0,2.6),Vector3(1.3,0,-6),Vector3(-7.4,0,-6),Vector3(-7.4,0,2.6)]
@export var anchors: Array[Dictionary] = [
	{"region":"Building","position":Vector3(-3,0,1.7)},
	{"region":"Building","position":Vector3(-6.8,0,-2)},
	{"region":"Building","position":Vector3(0.8,0,-2)},
	{"region":"Building","position":Vector3(-3,0,-5.3)},
	{"region":"LandingPlatform","position":Vector3(3.7,0,1.7)},
	{"region":"LandingPlatform","position":Vector3(2.2,0,-2)},
	{"region":"LandingPlatform","position":Vector3(7.8,0,-2)},
	{"region":"LandingPlatform","position":Vector3(5,0,-5.3)}
]
