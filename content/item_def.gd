class_name ItemDef
extends Resource
## Data for one inventory item (route kit or raw material). One .tres per id under content/items/.

@export var id: StringName = &""
## Carrying any heavy item: move speed × ActionCostTable.heavy_speed_mult, climb disabled.
@export var heavy: bool = false
