extends ColorRect
class_name Demo

onready var time_start: int = OS.get_ticks_usec()

func elapsed() -> float:
	return (OS.get_ticks_usec() - time_start) / 1000000.0;

func _process(delta: float) -> void:
	self.material.set_shader_param("iTime", elapsed());
