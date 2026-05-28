class_name FeedbackService
extends Node

@export var max_shake_offset := 10.0
@export var trauma_decay := 5.5
@export var master_volume_db := -8.0

var camera: Camera2D
var effects_parent: Node
var trauma := 0.0
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.randomize()
	add_to_group("feedback_service")

func configure(target_camera: Camera2D, target_effects_parent: Node) -> void:
	camera = target_camera
	effects_parent = target_effects_parent

func _process(delta: float) -> void:
	if camera == null:
		return

	if trauma <= 0.0:
		camera.offset = Vector2.ZERO
		return

	trauma = maxf(trauma - trauma_decay * delta, 0.0)
	var strength: float = trauma * trauma
	camera.offset = Vector2(
		rng.randf_range(-max_shake_offset, max_shake_offset),
		rng.randf_range(-max_shake_offset, max_shake_offset)
	) * strength

func weapon_fired(at_position: Vector2) -> void:
	_play_tone(420.0, 0.035, 0.18, 0.15)
	spawn_muzzle_spark(at_position)

func enemy_hit(at_position: Vector2, result: Dictionary) -> void:
	var damage := float(result.get("final_damage", 0.0))
	var critical := bool(result.get("critical", false))
	shake(0.08 if not critical else 0.14)
	_play_tone(250.0 if not critical else 560.0, 0.06, 0.28, 0.22)
	spawn_damage_number(at_position, damage, critical)

func player_hit(at_position: Vector2, result: Dictionary) -> void:
	shake(0.28)
	_play_tone(120.0, 0.11, 0.36, 0.4)
	spawn_damage_number(at_position, float(result.get("final_damage", 0.0)), false, Color(1.0, 0.34, 0.26))

func enemy_died(at_position: Vector2, color: Color) -> void:
	shake(0.18)
	_play_tone(95.0, 0.16, 0.45, 0.3, true)
	spawn_death_burst(at_position, color)

func boss_phase_transition(at_position: Vector2, color: Color) -> void:
	shake(0.32)
	_play_tone(180.0, 0.22, 0.48, 0.32, true)
	spawn_death_burst(at_position, color)

func forge_result(success: bool) -> void:
	if success:
		shake(0.1)
		_play_tone(680.0, 0.16, 0.32, 0.18)
	else:
		shake(0.16)
		_play_tone(150.0, 0.18, 0.35, 0.35, true)

func shake(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)

func spawn_muzzle_spark(at_position: Vector2) -> void:
	var parent := _effects_parent()
	if parent == null:
		return

	var spark := Polygon2D.new()
	spark.color = Color(1.0, 0.84, 0.38)
	spark.polygon = PackedVector2Array([Vector2(-5, -2), Vector2(6, 0), Vector2(-5, 2)])
	spark.global_position = at_position
	parent.add_child(spark)

	var tween := spark.create_tween()
	tween.tween_property(spark, "scale", Vector2(1.8, 1.8), 0.06)
	tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.08)
	tween.tween_callback(spark.queue_free)

func spawn_damage_number(at_position: Vector2, amount: float, critical: bool, color := Color(1.0, 0.92, 0.58)) -> void:
	var parent := _effects_parent()
	if parent == null:
		return

	var label := Label.new()
	label.text = "%d" % roundi(amount)
	label.modulate = color
	label.z_index = 40
	label.add_theme_font_size_override("font_size", 18 if critical else 14)
	label.global_position = at_position + Vector2(-10, -28)
	parent.add_child(label)

	var lift := Vector2(rng.randf_range(-10.0, 10.0), -34.0)
	var tween := label.create_tween()
	tween.tween_property(label, "global_position", label.global_position + lift, 0.35).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.35)
	tween.tween_callback(label.queue_free)

func spawn_death_burst(at_position: Vector2, color: Color) -> void:
	var parent := _effects_parent()
	if parent == null:
		return

	for index in range(9):
		var shard := Polygon2D.new()
		shard.color = color.lightened(0.18)
		shard.polygon = PackedVector2Array([Vector2(0, -4), Vector2(5, 2), Vector2(-4, 3)])
		shard.global_position = at_position
		shard.rotation = rng.randf_range(0.0, TAU)
		shard.z_index = 30
		parent.add_child(shard)

		var direction := Vector2.RIGHT.rotated(float(index) / 9.0 * TAU + rng.randf_range(-0.25, 0.25))
		var distance := rng.randf_range(22.0, 54.0)
		var tween := shard.create_tween()
		tween.tween_property(shard, "global_position", at_position + direction * distance, 0.34).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(shard, "rotation", shard.rotation + rng.randf_range(-2.6, 2.6), 0.34)
		tween.parallel().tween_property(shard, "modulate:a", 0.0, 0.34)
		tween.tween_callback(shard.queue_free)

func _play_tone(frequency: float, duration: float, volume: float, decay: float, noise := false) -> void:
	if not is_inside_tree():
		return

	var player := AudioStreamPlayer.new()
	player.volume_db = master_volume_db
	player.stream = _make_wave(frequency, duration, volume, decay, noise)
	add_child(player)
	player.finished.connect(player.queue_free)
	player.play()

func _make_wave(frequency: float, duration: float, volume: float, decay: float, noise := false) -> AudioStreamWAV:
	var sample_rate := 22050
	var sample_count := maxi(roundi(duration * sample_rate), 1)
	var bytes := PackedByteArray()
	bytes.resize(sample_count)

	for index in range(sample_count):
		var t := float(index) / float(sample_rate)
		var envelope := exp(-t / maxf(decay, 0.001))
		var sample := sin(TAU * frequency * t)
		if noise:
			sample = sample * 0.55 + rng.randf_range(-0.45, 0.45)
		var value := clampi(roundi(128.0 + sample * 127.0 * volume * envelope), 0, 255)
		bytes[index] = value

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_8_BITS
	stream.mix_rate = sample_rate
	stream.stereo = false
	stream.data = bytes
	return stream

func _effects_parent() -> Node:
	if effects_parent != null:
		return effects_parent
	return get_tree().current_scene
