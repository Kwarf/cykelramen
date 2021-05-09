extends ColorRect
class_name Demo

onready var camera: Spatial = get_parent().find_node("Camera")
onready var camera_target: Spatial = camera.find_node("Target")
onready var ball: Spatial = get_parent().find_node("Ball")
onready var animation_player: AnimationPlayer = get_parent().find_node("AnimationPlayer")

var clear_elapsed: bool = true
var elapsed: float = 0
var pause_time: float = 0

# ¯\_(ツ)_/¯
func invX(vec: Vector3) -> Vector3:
	return vec * Vector3(-1, 1, 1)

func _process(delta: float) -> void:
	if clear_elapsed:
		elapsed = 0
		clear_elapsed = false
	if pause_time > 0:
		self.material.set_shader_param("iTime", pause_time);
	else:
		self.material.set_shader_param("iTime", elapsed);
	self.material.set_shader_param("iCameraPosition", invX(camera.global_transform.origin));
	self.material.set_shader_param("iCameraLookAt", invX(camera_target.global_transform.origin));
	self.material.set_shader_param("iBallPosition", invX(ball.global_transform.origin));
	elapsed += delta

func play(precalc_data: ImageTexture) -> void:
	self.material.set_shader_param("iPrecalcTexture", precalc_data);
	self.clear_elapsed = true
	self.animation_player.play("Demo")

func pause() -> void:
	pause_time = elapsed
