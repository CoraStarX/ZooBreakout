class_name GameConst
extends RefCounted
## Compatibility facade over balance Resources. Prefer editing `.tres` under `content/balance/`.
## Call sites may keep `GameConst.X`; values resolve from Params / ActionCostTable at runtime.

const _DAY_PATH := "res://content/balance/day_cycle_params.tres"
const _ROUTE_PATH := "res://content/balance/route_work_params.tres"
const _ALERT_PATH := "res://content/balance/alert_params.tres"
const _COST_PATH := "res://content/balance/action_cost_table.tres"

static var _day: DayCycleParams
static var _route: RouteWorkParams
static var _alert: AlertParams
static var _cost: ActionCostTable


static func day_cycle() -> DayCycleParams:
	if _day == null:
		_day = load(_DAY_PATH) as DayCycleParams
	return _day


static func route_work() -> RouteWorkParams:
	if _route == null:
		_route = load(_ROUTE_PATH) as RouteWorkParams
	return _route


static func alert_params() -> AlertParams:
	if _alert == null:
		_alert = load(_ALERT_PATH) as AlertParams
	return _alert


static func action_cost() -> ActionCostTable:
	if _cost == null:
		_cost = load(_COST_PATH) as ActionCostTable
	return _cost


## --- DayCycleParams ---
static var MAX_ALERT_LEVEL: int:
	get:
		return alert_params().max_alert_level

static var NIGHT_PATROL_BASE_SEC: float:
	get:
		return day_cycle().night_patrol_base_sec

static var NIGHT_PATROL_PER_ALERT_SEC: float:
	get:
		return day_cycle().night_patrol_per_alert_sec

static var NIGHT_QUIET_SEC: float:
	get:
		return day_cycle().night_quiet_sec

static var OPEN_PHASE_SEC: float:
	get:
		return day_cycle().open_phase_sec

static var CLOSE_PHASE_SEC: float:
	get:
		return day_cycle().close_phase_sec

static var DEADLINE_DAY: int:
	get:
		return day_cycle().deadline_day

## --- ActionCostTable / interact ---
static var SOFT_INTERACT_SEC: float:
	get:
		return action_cost().soft_interact_sec

static var HARD_INTERACT_SEC: float:
	get:
		return action_cost().hard_interact_sec

## Still local until Capture / sense params land (not in knife-1 Resources).
const GRAVITY := 22.0
const DETENTION_SEC := 15.0
const REINFORCE_EXTRA_MATERIALS := 1
const REINFORCE_TIME_MULT := 2.0
const OBSERVE_SEC := 4.0
const OBSERVE_VIEW_RANGE := 13.0
## 工具车金属整局只有这么多（不每天补货）。
const CART_LOOT_PER_RUN := 1
const STEAL_SEC := 1.6
const CART_TRAIL_DIST := 1.4
const STAFF_DWELL_SEC := 4.0

static var SHOUT_COOLDOWN_SEC: float:
	get:
		return action_cost().shout_cooldown_sec

static var SHOUT_LOUDNESS: float:
	get:
		return action_cost().shout_loudness

const FOOTSTEP_NOISE_LOUDNESS := 0.22
const FOOTSTEP_NOISE_INTERVAL_SEC := 0.55
const RUN_SPEED_FOR_FOOTSTEP_NOISE := 2.4

static var GATHER_SEC: float:
	get:
		return action_cost().gather_sec

static var GATHER_POOR_SEC: float:
	get:
		return action_cost().gather_poor_sec

const STAFF_VISION_PER_DAY := 0.5
const STAFF_SPEED_PER_DAY := 0.12
const STAFF_SCALE_MAX_DAYS := 4

## --- RouteWorkParams ---
static var ROUTE_TIERS: int:
	get:
		return route_work().route_tiers

static var KIT_TIERS: int:
	get:
		return route_work().kit_tiers

static var TIER_SOFT_SEC: float:
	get:
		return route_work().tier_soft_sec

static var TIER_HARD_SEC: float:
	get:
		return route_work().tier_hard_sec
