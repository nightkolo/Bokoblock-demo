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

var parent_bokobody: Bokobody2D
var is_on_endpoint: bool = false

var _tween: Tween
var _tween_anim_move: Tween
var _tween_anim_hit_block: Tween
var _current_move: Vector2

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
		parent_bokobody.move_stopped.connect(stop_anim_move)
		
		body_entered.connect(func(body: Node2D):
			if (body is TileMapLayer || body is SleepingBlock):
				anim_hit_block()
			)
	
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


func anim_move(moved_to: Vector2) -> void:
	if !_are_nodes_assgined():
		return
	
	var anim_to: Vector2
	var squash := 0.75
	var stretch := 1.25
	var dur := 0.5
	
	_current_move = moved_to
	
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
	
	if _tween_anim_move:
		_tween_anim_move.kill()
	_tween_anim_move = create_tween()
	_tween_anim_move.set_ease(Tween.EASE_OUT)
	_tween_anim_move.tween_property(sprite_node,"scale",anim_to,dur/6.0)
	_tween_anim_move.tween_property(sprite_node,"scale",Vector2.ONE,dur).set_trans(Tween.TRANS_BACK)


func anim_hit_block(in_direction: Vector2 = _current_move) -> void:
	if !_are_nodes_assgined():
		return
	
	var anim_to: Vector2
	var squash := 0.75
	var stretch := 1.25
	var dur := 0.8
	
	match in_direction:
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
	
	if _tween_anim_move:
		_tween_anim_move.kill()
	if _tween_anim_hit_block:
		_tween_anim_hit_block.kill()
	_tween_anim_hit_block = create_tween()
	_tween_anim_hit_block.set_ease(Tween.EASE_OUT)
	_tween_anim_hit_block.tween_property(sprite_node,"scale",anim_to,dur/10.0)
	_tween_anim_hit_block.tween_property(sprite_node,"scale",Vector2.ONE,dur).set_trans(Tween.TRANS_ELASTIC)


## @experimental: Needs refactoring
func anim_eyes(tranform: PlayerInput.TranformationType, transformed_to: Variant) -> void:
	if !_are_nodes_assgined() && parent_bokobody == null:
		return
	
	var move_eyes_to := 7.0
	
	# Godot keeps screaming at me, i no no wanna :((
	#
	#if _tween:
		#_tween.kill()
	#_tween = create_tween()
	
	match tranform:
		
		PlayerInput.TranformationType.MOVE:
			sprite_eyes.global_position += (transformed_to as Vector2) * move_eyes_to
			if _tween:
				_tween.kill()
			_tween = create_tween()
			_tween.tween_property(sprite_eyes,"position",Vector2.ZERO,parent_bokobody.movement_time*3.0).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_EXPO)
			
		PlayerInput.TranformationType.TURN:
			pass
			
		PlayerInput.TranformationType.UNDO:
			pass


func anim_standing_endpoint() -> void:
	if _are_nodes_assgined():
		sprite_node.modulate = Color(Color(1.25,1.25,1.25))
	

func anim_left_endpoint() -> void:
	if _are_nodes_assgined():
		sprite_node.modulate = Color(Color.WHITE)


func stop_anim_move() -> void:
	if _tween_anim_move:
		_tween_anim_move.kill()
	
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
		
	sprite_block.offset.y = -64.0
	sprite_block.position.y = 32.0
	
	# TODO: Global PlayerInput needs a different name probably.. (GameLogic)
	sprite_block.self_modulate = PlayerInput.set_boko_color(boko_color)


func _process(_delta: float) -> void:
	if sprite_eyes:
		sprite_eyes.global_rotation = 0.0
		sprite_eyes.position.x = clamp(sprite_eyes.position.x,-7.0,7.0)
		sprite_eyes.position.y = clamp(sprite_eyes.position.y,-7.0,7.0)
		

func _are_nodes_assgined() -> bool:
	return sprite_node != null && sprite_block != null && sprite_eyes != null
	

func _set_as_origin_block(is_origin: bool) -> void:
	if is_origin:
		sprite_block.texture = asset_origin_block
		self.z_index = 1
	else:
		sprite_block.texture = asset_block
		self.z_index = 0
