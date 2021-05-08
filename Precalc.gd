extends Spatial

# Each bike takes 4 pixels of precalc storage per frame (one vec3 for position, one mat3x3 for translation)
const NO_BIKES: int = 5
const PRECALC_TICKS: int = 160

var image: Image = Image.new()
var bikes: Array
var tick: int = 0

signal precalc_done

func _ready():
	# Hacky skippy boi for dev
	tick = PRECALC_TICKS
	queue_free()
	get_parent().find_node("MarchTarget").call_deferred("play", null)

	# Non skippy, put back for release, duh!
	image.create(PRECALC_TICKS, PRECALC_TICKS, false, Image.FORMAT_RGBF);
	image.lock()
	bikes.append(find_node("Bike1"))
	bikes.append(find_node("Bike2"))
	bikes.append(find_node("Bike3"))
	bikes.append(find_node("Bike4"))
	bikes.append(find_node("Bike5"))

func _physics_process(_delta):
	if tick >= PRECALC_TICKS:
		return

	var width = self.image.data["width"]
	var stream = StreamPeerBuffer.new()
	stream.data_array = self.image.data["data"]
	stream.seek(tick * 4 * 3 * width)
	for i in range(bikes.size()):
		var p = bikes[i].global_transform.origin
		stream.put_float(-p.x) # ¯\_(ツ)_/¯
		stream.put_float(p.y)
		stream.put_float(p.z)
		var t = bikes[i].global_transform.basis
		# I have no bloody clue what I'm doing here, if the order is correct,
		# if I should invert X here as well or not, but this is what looks
		# the least bad.
		stream.put_float(-t.x.x)
		stream.put_float(-t.y.x)
		stream.put_float(-t.z.x)
		stream.put_float(t.x.y)
		stream.put_float(t.y.y)
		stream.put_float(t.z.y)
		stream.put_float(t.x.z)
		stream.put_float(t.y.z)
		stream.put_float(t.z.z)

	# For some reason you have to put it back on the image? Idk.. Godot..
	self.image.data["data"] = stream.data_array

	tick += 1
	$ColorRect/ProgressBar.value = tick / float(PRECALC_TICKS) * 100
	if tick >= PRECALC_TICKS:
		var texture = ImageTexture.new()
		texture.create_from_image(image, 0);
		queue_free()
		emit_signal("precalc_done", texture)
