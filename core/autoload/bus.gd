extends Node
## 核心噪音事件；形態與移動回饋沿用各節點的本地訊號。
## position、loudness 0~1+、kind（jump / climb / landing / transform）。
signal noise_made(position: Vector3, loudness: float, kind: StringName)
