## Under construction
extends Node2D
class_name Bokobody2D

# TODO: functions turn, move need a rework.
signal moved(moved_to: Vector2)
signal turned(turned_to: float)
signal move_end(has_moved_by: Vector2)
signal turn_end(has_turned_by: float)
signal move_stopped()
signal turn_stopped()

@export var movement_time: float = 0.1 ## Movement time.
@export var movement_strength: int = 1 ## How many grid it'll move, [code]1 = 64.0, -2 = -128.0[/code], etc. 
@export var rotation_strength: int = 1 ## How many angular turns it'll move, [code]1 = 1 turn, -2 = 2 turn opposite, etc. 
@export var apply_color: bool = false ## @experimental
@export var just_dont: bool = false ## Don't, okay?

var moves_made: Array ## dynamic for now 
var blocks: Array[Bokoblock2D] ## An [Array] of child [Bokoblock2D] nodes. Assigned at runtime.
var is_moving: bool: ## Returns [code]true[/code] if [Bokobody2D] is currently moving, [code]false[/code] if otherwise.
	set(value):
		is_moving = value
		if !value:
			PlayerInput.somebody_stopped.emit()
var is_rotating: bool: ## Returns [code]true[/code] if [Bokobody2D] is currently turning, [code]false[/code] if otherwise.
	set(value):
		is_rotating = value
		if !value:
			PlayerInput.somebody_stopped.emit()
var _old_pos: Vector2
var _old_rot: float

var _can_set_record: bool
var _tween_move: Tween
var _tween_rot: Tween

## @experimental
## Tile size.
const TILE_SIZE = 45.0 


func _ready() -> void:
	if just_dont:
		print_rich("[font_size=25.0][wave amp=50.0 freq=5.0 connected=1][color=green][b]Fart Fart Fart")
	
	PlayerInput.current_bodies.append(self)
	
	for child: Node in get_children():
		if child is Bokoblock2D:
			blocks.append(child as Bokoblock2D)
			
			(child as Area2D).area_entered.connect(func(area: Area2D):
				if area is Bokoblock2D:
					_stop_making_move()
				)
			(child as Area2D).body_entered.connect(func(body: Node2D):
				if (body is TileMapLayer || body is SleepingBlock):
					_stop_making_move()
				)
	
	position = position.snapped(Vector2.ONE * TILE_SIZE)
	position += (Vector2.ONE * TILE_SIZE) / 2
	
	PlayerInput.input_undo.connect(undo)
	PlayerInput.input_move.connect(move)
	PlayerInput.input_turn.connect(turn)


func _process(_delta: float) -> void:
	if rotation_degrees > 360.0: # ehh?
		rotation_degrees += -360.0
	elif rotation_degrees < -360.0:
		rotation_degrees += 360.0


func try_move() -> void: ## @experimental
	pass
	

func try_turn() -> void: ## @experimental
	pass


## Undos previous moves.
func undo() -> void:
	if moves_made.is_empty():
		await get_tree().create_timer(0.1).timeout
		PlayerInput.somebody_stopped.emit()
		return
	
	var last_move = moves_made[0]
	
	match typeof(last_move):
	
		TYPE_VECTOR2:
			moves_made.pop_front()
			await move(last_move * -1, true, false)
			
		TYPE_FLOAT:
			moves_made.pop_front()
			await turn(last_move * 90.0 * -1, true, false)
			
	PlayerInput.somebody_stopped.emit()


## @experimental
## Turns [Bokobody2D]. [br][br][param disable_colli] disables [Bokobody2D] collision during the turn. [param set_record] pushes the turn record to [member moves_made].
func turn(rotate_deg_to: float, disable_colli: bool = false, set_record: bool = true) -> void:
	var rot_to := deg_to_rad(rotate_deg_to) * rotation_strength
	_old_rot = rotation
	_can_set_record = set_record
	
	if disable_colli: # Doing a check to avoid runtime slowdown
		_disable_colli(true)
		
	turned.emit(sign(rotate_deg_to))
	
	is_rotating = true
	_tween_rot = get_tree().create_tween()
	_tween_rot.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	_tween_rot.tween_property(self,"rotation",rotation + rot_to,movement_time)
	
	await _tween_rot.finished
	await get_tree().create_timer(movement_time).timeout
	
	turn_end.emit(sign(rotate_deg_to))
	if set_record:
		moves_made.push_front(sign(rot_to))
	if disable_colli: # Doing a check to avoid runtime slowdown
		_disable_colli(false)
	is_rotating = false
	

## @experimental
## Moves [Bokobody2D]. [br][br][param disable_colli] disables [Bokobody2D] collision during the move. [param set_record] pushes the move record to [member moves_made].
func move(direction: Vector2, disable_colli: bool = false, set_record: bool = true) -> void:
	var move_to: Vector2 = TILE_SIZE * direction * movement_strength
	_old_pos = position
	_can_set_record = set_record
	if disable_colli: # Doing a check to avoid runtime slowdown
		_disable_colli(true)
		
	moved.emit(direction)
	
	is_moving = true
	_tween_move = get_tree().create_tween()
	_tween_move.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	_tween_move.tween_property(self,"position",position + move_to,movement_time)
	
	await _tween_move.finished
	await get_tree().create_timer(movement_time).timeout
	
	move_end.emit(direction)
	if set_record:
		moves_made.push_front(sign(move_to))
	if disable_colli: # Doing a check to avoid runtime slowdown
		_disable_colli(false)
	is_moving = false


## Stops current [Bokobody2D] movement, and returns to previous position.[br][br] This function is called by [signal Bokoblock2D.area_entered], [signal Bokoblock2D.body_entered].
func stop_moving() -> void:
	if _tween_move:
		_tween_move.kill()
	
	move_stopped.emit()
	position = _old_pos
	
	if _can_set_record:
		moves_made.push_front(Vector2.ZERO)
	_disable_colli(false)
	is_moving = false
	

## Stops current [Bokobody2D] rotation, and returns to previous position.[br][br]
## This function is called by [signal Bokoblock2D.area_entered], [signal Bokoblock2D.body_entered].
func stop_turning() -> void:
	if _tween_rot:
		_tween_rot.kill()
	
	turn_stopped.emit()
	
	_tween_rot = create_tween()
	_tween_rot.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween_rot.tween_property(self,"rotation",_old_rot,movement_time*2.0)
	await _tween_rot.finished
	
	if _can_set_record:
		moves_made.push_front(0.0)
	_disable_colli(false)
	is_rotating = false
	

## [method print]s [member moves_made].
func view_move_history() -> void:
	print(moves_made)


## Returns [member moves_made].
func get_move_history() -> Array:
	return moves_made


## Returns [code]true[/code] if [Bokobody2D] is not making a move/turn, [code]false[/code] if otherwise.
func is_idle() -> bool:
	return !(is_moving || is_rotating)


func _stop_making_move() -> void:
	if is_moving:
		stop_moving()
		
	if is_rotating:
		stop_turning()
	
	
func _disable_colli(disable: bool) -> void:
	for block: Area2D in blocks:
		(block.get_node("CollisionShape2D") as CollisionShape2D).set_deferred("disabled", disable)
	
	
