extends ColorRect
class_name Demo

onready var camera: Spatial = get_parent().find_node("Camera")
onready var camera_target: Spatial = camera.find_node("Target")
onready var ball: Spatial = get_parent().find_node("Ball")
onready var animation_player: AnimationPlayer = get_parent().find_node("AnimationPlayer")
onready var music_player: AudioStreamPlayer = get_parent().find_node("AudioStreamPlayer")
onready var disc_two: ColorRect = get_parent().find_node("MarchTargetDisc2")

var run: bool = false
var elapsed: float = 0

# ¯\_(ツ)_/¯
func invX(vec: Vector3) -> Vector3:
	return vec * Vector3(-1, 1, 1)

func _process(delta: float) -> void:
	if not run:
		return

	update_material(self.material)
	update_material(self.disc_two.material)
	var step = 0.0166666666666667
	elapsed += step
	self.animation_player.advance(step)

func play(precalc_data: ImageTexture) -> void:
	self.material.set_shader_param("iPrecalcTexture", precalc_data);
	self.animation_player.play("Demo")
	self.run = true

func update_material(mtl: Material) -> void:
	mtl.set_shader_param("iTime", elapsed);
	mtl.set_shader_param("iCameraPosition", invX(camera.global_transform.origin));
	mtl.set_shader_param("iCameraLookAt", invX(camera_target.global_transform.origin));
	mtl.set_shader_param("iBallPosition", invX(ball.global_transform.origin));

func quit() -> void:
	get_tree().quit()
