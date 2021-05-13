extends ColorRect
class_name Demo

onready var camera: Spatial = get_parent().find_node("Camera")
onready var camera_target: Spatial = camera.find_node("Target")
onready var ball: Spatial = get_parent().find_node("Ball")
onready var animation_player: AnimationPlayer = get_parent().find_node("AnimationPlayer")
onready var music_player: AudioStreamPlayer = get_parent().find_node("AudioStreamPlayer")
onready var disc_two: ColorRect = get_parent().find_node("MarchTargetDisc2")

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
	update_material(self.material)
	update_material(self.disc_two.material)
	elapsed += delta

func play(precalc_data: ImageTexture) -> void:
	self.material.set_shader_param("iPrecalcTexture", precalc_data);
	self.clear_elapsed = true
	self.animation_player.play("Demo")
	self.music_player.play()

func update_material(mtl: Material) -> void:
	if pause_time > 0:
		mtl.set_shader_param("iTime", pause_time);
	else:
		mtl.set_shader_param("iTime", elapsed);
		$LineEdit.text = String(elapsed)
	mtl.set_shader_param("iCameraPosition", invX(camera.global_transform.origin));
	mtl.set_shader_param("iCameraLookAt", invX(camera_target.global_transform.origin));
	mtl.set_shader_param("iBallPosition", invX(ball.global_transform.origin));

func quit() -> void:
	get_tree().quit()

# Seek stuff, remove for release
func pause() -> void:
	seek(String(elapsed))

func _ready():
	$PlayButton.connect("toggled", self, "pause_toggled")
	$LineEdit.connect("text_entered", self, "seek")

func seek(pos: String) -> void:
	music_player.stop()
	pause_time = float(pos)
	$LineEdit.text = String(pause_time)
	animation_player.seek(pause_time, true)
	animation_player.stop(false)

func pause_toggled(should_play: bool) -> void:
	if should_play:
		elapsed = pause_time
		pause_time = 0
		music_player.play(elapsed) # Borked, wont sync up
		animation_player.play("Demo")
		animation_player.seek(elapsed, true)
	else:
		pause()
