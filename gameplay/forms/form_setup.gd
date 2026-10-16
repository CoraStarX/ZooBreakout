class_name FormSetup
extends Resource
@export var forms: Array[FormDef] = []
@export var base_form: FormDef
@export var starting_form: FormDef
## 過渡配置；形態獲得實作後改資料即可，不由測試臨時賦予能力。
@export var initial_unlocked_forms: Array[FormDef] = []
@export var spawn := Vector3(-8.8,0.04,5)
