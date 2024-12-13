## Under construction
extends Area2D
class_name Bokoblock2D

## @deprecated: Use [enum PlayerInput.BokoColor].
enum BokoColor {AQUA = 0, RED = 1, BLUE = 2, YELLOW = 3, GREEN = 4, PINK = 5}

@export var boko_color: PlayerInput.BokoColor
@export_group("Modify")
@export var auto_check_origin: bool = true
@export var make_origin: bool = false
@export_category("Objects to Assign")
@export var asset_block: Texture2D = preload("res://assets/img/block-v05-greyscale.png")
@export var asset_origin_block: Texture2D = preload("res://assets/img/block-v05-origin-greyscale.png")
@export var sprite_node: Node2D
@export var sprite_eyes: Sprite2D
@export var sprite_block: Sprite2D
@export var sprite_star: Sprite2D

var parent_bokobody: Bokobody2D
var is_on_endpoint: bool = false
var limit_eye_movement: bool = true

var _current_transformation: Variant
var _tween_eyes: Tween
var _tween_move: Tween
var _tween_turn: Tween
var _tween_hit_block: Tween
var _tween_complete: Tween
var _tween_star: Tween


func _ready() -> void:
	_setup_node()
	_setup_sprite()
	check_state()
	
	if get_parent() is Bokobody2D:
		parent_bokobody = (get_parent() as Bokobody2D)
		
	else:
		push_warning("Recommended that " + str(self) + " must be a child of Bokobody2D.")
	
	if parent_bokobody:
		parent_bokobody.moved.connect(anim_move)
		parent_bokobody.turned.connect(anim_turn)
		
		parent_bokobody.turned.connect(func(_turn_by: float):
			pass
			#print(_turn_by)
			)
		parent_bokobody.turn_end.connect(func(_turn_by: float):
			pass
			#print(_turn_by)
			)
		
		parent_bokobody.move_stopped.connect(stop_anim_move)
		parent_bokobody.turn_stopped.connect(stop_anim_turn)
		
		body_entered.connect(func(body: Node2D):
			if (body is TileMapLayer || body is SleepingBlock):
				anim_hit_block()
			)
	
	# TODO: I should really change this global's name...
	PlayerInput.game_end.connect(anim_complete)
	PlayerInput.move_over.connect(check_state)
	PlayerInput.bodies_made_move.connect(anim_eyes)



func check_state() -> void:
	var areas := get_overlapping_areas()
	var has_stood_on_endpoint := areas.size() == 1 && areas[0] is Endpoint2D
	
	# TODO: Check if (areas[0] as Endpoint2D).what_im_happy_with == boko_color, then call anim_standing_endpoint
	
	if has_stood_on_endpoint && !is_on_endpoint:
		anim_standing_endpoint()
		is_on_endpoint = true
		
	elif !has_stood_on_endpoint && is_on_endpoint:
		anim_left_endpoint()
		is_on_endpoint = false


func anim_turn(turned_by: float) -> void:
	# TODO: Give up, remove triginometry and maths fuckery, and skew center.
	
	if !_are_nodes_assgined():
		return
	
	var dur := 10.0
	var wobble_to: float = deg_to_rad(30.0) * sign(turned_by)
	
	if parent_bokobody:
		dur = parent_bokobody.movement_time * 8.0
	
	sprite_block.global_rotation = 0.0
	_current_transformation = turned_by
	
	#var offsets := rad_to_vector(parent_bokobody.rotation + deg_to_rad(90.0 * turned_by))
	var offsets := rad_to_vector(sprite_block.global_rotation + deg_to_rad(90.0 * turned_by))
	var offset_offset := Vector2(offsets.y,offsets.x) * 45.0
	var offset_pos := Vector2(offsets.y,offsets.x) * -22.0
	#var offset_offset := offsets * -45.0
	#var offset_pos := offsets * 22.0
	
	## IT WORKSSSSSS FINALLY!!!!!!!!! and now I can't get to skew from bottom...
	sprite_block.position = Vector2.ZERO
	sprite_block.global_position += offset_pos
	sprite_block.offset = offset_offset
	sprite_block.skew = wobble_to
	
	if _tween_turn:
		_tween_turn.kill()
	_tween_turn = create_tween()
	_tween_turn.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_ELASTIC)
	#_tween_turn.tween_property(sprite_block,"skew",deg_to_rad(10.0),dur/10.0)
	_tween_turn.tween_property(sprite_block,"skew",0.0,dur)
	
	
func rad_to_vector(rad: float) -> Vector2:
	var x = cos(rad)
	var y = sin(rad)
	return Vector2(x, y)


func stop_anim_turn() -> void:
	pass
	#if _tween_turn:
		#_tween_turn.kill()
	#
	#sprite_block.skew = 0.0
	
	
func anim_move(moved_to: Vector2) -> void:
	if !_are_nodes_assgined():
		return
	
	var anim_to: Vector2
	var squash := 0.65
	var stretch := 1.35
	var dur := 0.5
	
	if parent_bokobody:
		dur = parent_bokobody.movement_time * 5.0
	
	_current_transformation = moved_to
	
	match moved_to:
		Vector2.RIGHT:
			anim_to = Vector2(stretch,squash)
		Vector2.LEFT:
			anim_to = Vector2(stretch,squash)
		Vector2.UP:
			anim_to = Vector2(squash,stretch)
		Vector2.DOWN:
			anim_to = Vector2(squash,stretch)
		_:
			anim_to = Vector2.ONE
	
	if _tween_move:
		_tween_move.kill()
	_tween_move = create_tween()
	_tween_move.set_ease(Tween.EASE_OUT)
	_tween_move.tween_property(sprite_node,"scale",anim_to,dur/6.0)
	_tween_move.tween_property(sprite_node,"scale",Vector2.ONE,dur).set_trans(Tween.TRANS_BACK)


func anim_hit_block(transformed_to: Variant = _current_transformation) -> void:
	if !_are_nodes_assgined():
		return
	
	var dur := 0.9
	var anim_to: Vector2
	
	match typeof(transformed_to):
		
		Variant.Type.TYPE_FLOAT: # Turn
			anim_to = Vector2.ONE/3.0
			
			if _tween_move:
				_tween_move.kill()
			if _tween_hit_block:
				_tween_hit_block.kill()
			
			_tween_hit_block = create_tween()
			_tween_hit_block.set_ease(Tween.EASE_OUT)
			_tween_hit_block.tween_property(sprite_node,"scale",anim_to,dur/20.0)
			_tween_hit_block.tween_property(sprite_node,"scale",Vector2.ONE,dur/1.1).set_trans(Tween.TRANS_ELASTIC)
			
		Variant.Type.TYPE_VECTOR2: # Move
			var squash := 0.65
			var stretch := 1.35
			
			match transformed_to:
				Vector2.UP:
					anim_to = Vector2(stretch,squash)
				Vector2.DOWN:
					anim_to = Vector2(stretch,squash)
				Vector2.RIGHT:
					anim_to = Vector2(squash,stretch)
				Vector2.LEFT:
					anim_to = Vector2(squash,stretch)
				_:
					anim_to = Vector2.ONE 
				
			if _tween_move:
				_tween_move.kill()
			if _tween_hit_block:
				_tween_hit_block.kill()
			
			_tween_hit_block = create_tween()
			_tween_hit_block.set_ease(Tween.EASE_OUT)
			_tween_hit_block.tween_property(sprite_node,"scale",anim_to,dur/10.0)
			_tween_hit_block.tween_property(sprite_node,"scale",Vector2.ONE,dur).set_trans(Tween.TRANS_ELASTIC)
				
		_:
			pass
	
	


## @experimental: Needs refactoring
func anim_eyes(tranform: PlayerInput.TranformationType, transformed_to: Variant) -> void:
	if !_are_nodes_assgined() && parent_bokobody == null:
		return
	
	var move_eyes_to := 7.0
	
	# Godot keeps screaming at me, i no no wanna :((
	#
	#if _tween_eyes:
		#_tween_eyes.kill()
	#_tween_eyes = create_tween()
	
	match tranform:
		
		PlayerInput.TranformationType.MOVE:
			sprite_eyes.global_position += (transformed_to as Vector2) * move_eyes_to
			if _tween_eyes:
				_tween_eyes.kill()
			_tween_eyes = create_tween()
			_tween_eyes.tween_property(sprite_eyes,"position",Vector2.ZERO,parent_bokobody.movement_time*4.5).set_ease(Tween.EASE_IN_OUT).set_trans(Tween.TRANS_EXPO)
			
		PlayerInput.TranformationType.TURN:
			pass
			
		PlayerInput.TranformationType.UNDO:
			pass


func anim_complete() -> void:
	if !_are_nodes_assgined():
		return
	
	var first_anim_dur := 0.25
	var sec_anim_dur := 0.6
	var zoom_to := Vector2.ONE * 1.25
	var modulate_to := Color(2.0,2.0,2.0)
	var rot_to := rad_to_deg(PI)
	
	limit_eye_movement = false
	sprite_node.modulate = Color(Color(2.0,2.0,2.0))
	
	_tween_complete = create_tween().set_parallel(true)
	
	# Oh dear, lord. Please just Alt+Z. 
	_tween_complete.tween_property(sprite_node,"scale",zoom_to,first_anim_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween_complete.tween_property(sprite_node,"modulate",modulate_to,first_anim_dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween_complete.tween_property(sprite_node,"scale",Vector2.ZERO,sec_anim_dur).set_delay(first_anim_dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween_complete.tween_property(sprite_node,"rotation_degrees",rot_to,sec_anim_dur).set_delay(first_anim_dur).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	_tween_complete.tween_callback(anim_star).set_delay(first_anim_dur*2.0)


func anim_star() -> void:
	if !_are_nodes_assgined():
		pass
	
	var rand := randf()/3.0
	var dur := 0.4
	
	await get_tree().create_timer(rand).timeout
	
	_tween_star = create_tween().set_parallel(true)
	_tween_star.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween_star.tween_property(sprite_star,"scale",Vector2.ONE/2.0,dur)
	_tween_star.tween_property(sprite_star,"self_modulate",Color(Color.WHITE,0.5),dur)
	_tween_star.tween_property(sprite_star,"self_modulate",Color(Color.WHITE,0.0),dur*1.25).set_delay(dur)


func anim_standing_endpoint() -> void:
	if _are_nodes_assgined():
		sprite_node.modulate = Color(Color(1.25,1.25,1.25))
	

func anim_left_endpoint() -> void:
	if _are_nodes_assgined():
		sprite_node.modulate = Color(Color.WHITE)


func stop_anim_move() -> void:
	if _tween_move:
		_tween_move.kill()
	
	sprite_node.scale = Vector2.ONE
	

func _setup_node() -> void:
	collision_layer = 1
	collision_mask = 7
	
	if !_are_nodes_assgined():
		return
		
	if auto_check_origin:
		_set_as_origin_block(self.position == Vector2.ZERO)
	else:
		_set_as_origin_block(make_origin)


func _setup_sprite() -> void:
	if !_are_nodes_assgined():
		return 
		
	sprite_block.offset.y = -45.0
	sprite_block.position.y = 22.5
	
	# TODO: Global PlayerInput needs a different name probably.. (GameLogic)
	sprite_block.self_modulate = PlayerInput.set_boko_color(boko_color)



func _process(_delta: float) -> void:
	if limit_eye_movement && sprite_eyes:
		sprite_eyes.global_rotation = 0.0
		sprite_eyes.position.x = clamp(sprite_eyes.position.x,-7.0,7.0)
		sprite_eyes.position.y = clamp(sprite_eyes.position.y,-7.0,7.0)
		

func _are_nodes_assgined() -> bool:
	return sprite_node != null && sprite_block != null && sprite_eyes != null && sprite_star != null
	

func _set_as_origin_block(is_origin: bool) -> void:
	if is_origin:
		sprite_block.texture = asset_origin_block
		self.z_index = 1
	else:
		sprite_block.texture = asset_block
		self.z_index = 0
