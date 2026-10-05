extends Node2D
## One peasant. This base script is a peasant without a job, who spends the
## day at leisure; each job has a script that extends it (gatherer.gd,
## builder.gd). Nobody ever just stands and waits: a peasant with nothing to
## do calls _relax(), and strolls, chats with another, plays ball with them
## or goes to the tavern.
## Peasants walk on the ground and on the castle's floors, and get from one
## to the other by its stairs (see castle.gd).
## Placeholder shapes until we have real art.

const JobData = preload("res://scripts/job_data.gd")
const CastleData = preload("res://scripts/castle_data.gd")
const LEGS := Color(0.30, 0.24, 0.20)
const LEG_HEIGHT := 2.0
const HOP_TIME := 0.35
## Climbing a ladder is slower than walking; stairs are in between.
const CLIMB_SPEED := 0.6
const STAIR_SPEED := 0.85
## Peasants on the curtain wall are drawn behind the courtyard buildings
## (castle.gd draws those at z 2), everyone else in front of them.
const BACK_Z := 1
const FRONT_Z := 3

## What a peasant at leisure is doing: nothing yet, walking somewhere,
## visiting another peasant, being visited, or sitting in the tavern.
enum Leisure { NONE, STROLL, VISIT, HOST, TAVERN }
## How far apart two peasants stand to talk or play.
const MEET_GAP := 10.0
const BUBBLE := Color(0.97, 0.96, 0.90)
const BALL := Color(0.80, 0.25, 0.22)
const BANDAGE := Color(0.97, 0.97, 0.94)
## How big a child is next to a grown-up.
const CHILD_SIZE := 0.65

## The job id from JobData.JOBS, or "" for idle.
var job := ""
## Trained peasants do their job twice as well and wear a hat.
var trained := false
## The person this peasant is (see GameState.people): their name and trait.
var person: Dictionary = {}
var home_x := 0.0
var speed := 50.0
## The Workers node, which knows where things are in the world.
var world: Node2D

var _walking := false
## Seconds since this peasant appeared; they hop once as they arrive.
var _age := 0.0
var _last_position := Vector2.ZERO
## The steps still to take to where the peasant is going (see castle.route).
var _route: Array = []
var _route_to := Vector2.INF
var _route_version := -1
## True while inside a building: on its stairs, or asleep.
var _inside := false
## True while on a flight of stairs: the peasant finishes it before going anywhere else.
var _on_stair := false
var _back := false
## Where this peasant sleeps tonight (INF during the day), and whether they are asleep there.
var _bed := Vector2.INF
var _asleep := false
## True if the peasant came to rest inside a building (in a room of the keep).
var _rest_inside := false
var _leisure := Leisure.NONE
## Seconds left of what the peasant is doing at leisure, and where.
var _leisure_time := 0.0
var _leisure_spot := Vector2.ZERO
## The peasant being visited, or visiting.
var _partner: Node2D
## True if the two are playing ball rather than talking.
var _playing := false
## The last frame this peasant was at leisure, and was standing with their partner.
var _leisure_frame := -10
var _met_frame := -10


func _process(delta: float) -> void:
	# Still inside for as long as they are on the stairs or in a room,
	# whatever else they decide.
	_inside = _on_stair or _rest_inside
	_asleep = false
	if GameState.is_night() and _sleeps():
		# Everyone goes in at the nearest door and sleeps inside until dawn:
		# in a bed in the keep, if that is where they are.
		if _bed == Vector2.INF:
			_bed = world.bed_spot(self)
		if _go_to(_bed, delta):
			_inside = true
			_asleep = true
	else:
		_bed = Vector2.INF
		_work(delta)
	# Out of sight inside a building, unless the player is looking into it.
	visible = not _inside or world.castle.shows_inside(position)
	z_index = BACK_Z if _back else FRONT_Z
	_age += delta
	_walking = not position.is_equal_approx(_last_position)
	_last_position = position
	queue_redraw()


## True while on the stairs inside a building, or asleep in one.
func is_inside() -> bool:
	return _inside


func tunic() -> Color:
	return JobData.JOBS[job].color if job != "" else JobData.IDLE_COLOR


## Jobs that keep going through the night return false.
func _sleeps() -> bool:
	return true


## What the peasant does each frame. Without a job, the day is their own.
func _work(delta: float) -> void:
	_relax(delta)


# --- Leisure ---

## True if this peasant has nothing to do right now.
func at_leisure() -> bool:
	return Engine.get_process_frames() - _leisure_frame <= 1


## Another peasant asks to come over to talk or play. Returns true if this
## one stays put for them.
func invite(by: Node2D, seconds: float, playing: bool) -> bool:
	if not at_leisure() or not visible or position.y < -0.5:
		return false
	if _leisure == Leisure.VISIT or _leisure == Leisure.HOST or _leisure == Leisure.TAVERN:
		return false
	_leisure = Leisure.HOST
	_partner = by
	_playing = playing
	# Long enough for them to walk over, too.
	_leisure_time = seconds + 30.0
	return true


## The visitor has arrived and is standing with this peasant.
func meet() -> void:
	_met_frame = Engine.get_process_frames()


## Spends a frame at leisure. Jobs call this whenever there is no work.
## Peasants who must stay near their work pass where, and how far they may go.
func _relax(delta: float, near_x := NAN, reach := 0.0) -> void:
	if not at_leisure():
		# Back from work: start afresh.
		_leisure = Leisure.NONE
	_leisure_frame = Engine.get_process_frames()
	match _leisure:
		Leisure.NONE:
			_pick_leisure(near_x, reach)
		Leisure.STROLL:
			if _go_to(_leisure_spot, delta):
				_leisure_time -= delta
				if _leisure_time <= 0.0:
					_leisure = Leisure.NONE
		Leisure.VISIT:
			if not is_instance_valid(_partner) or not _partner.at_leisure() or _partner._partner != self:
				_leisure = Leisure.NONE
				return
			var side := 1.0 if position.x >= _partner.position.x else -1.0
			if _walk_to(_partner.position.x + side * MEET_GAP, delta):
				_met_frame = Engine.get_process_frames()
				_partner.meet()
				_leisure_time -= delta
				if _leisure_time <= 0.0:
					_partner._leisure = Leisure.NONE
					_leisure = Leisure.NONE
		Leisure.HOST:
			_leisure_time -= delta
			if _leisure_time <= 0.0 or not is_instance_valid(_partner) or not _partner.at_leisure():
				_leisure = Leisure.NONE
		Leisure.TAVERN:
			if _walk_to(_leisure_spot.x, delta):
				_inside = true
				_leisure_time -= delta
				if _leisure_time <= 0.0:
					_leisure = Leisure.NONE


func _pick_leisure(near_x: float, reach: float) -> void:
	var free := is_nan(near_x)
	var roll := randf()
	if roll < 0.4:
		var friend: Node2D = world.leisure_partner(self, INF if free else reach * 2.0)
		var playing := randf() < 0.4
		var seconds := randf_range(6.0, 14.0)
		if friend != null and friend.invite(self, seconds, playing):
			_leisure = Leisure.VISIT
			_partner = friend
			_playing = playing
			_leisure_time = seconds
			return
	if free and roll > 0.85 and GameState.part_levels.tavern > 0:
		_leisure = Leisure.TAVERN
		_leisure_spot = Vector2(CastleData.TAVERN_X, 0)
		_leisure_time = randf_range(6.0, 12.0)
		return
	_leisure = Leisure.STROLL
	_leisure_spot = world.stroll_spot(home_x) if free else Vector2(near_x + randf_range(-reach, reach), 0)
	_leisure_time = randf_range(2.0, 7.0)


## A speech bubble while talking, or the ball while playing.
func _draw_leisure() -> void:
	if not at_leisure() or Engine.get_process_frames() - _met_frame > 1 or not is_instance_valid(_partner):
		return
	var seconds := Time.get_ticks_msec() / 1000.0
	if _playing:
		if _leisure == Leisure.VISIT:
			# The ball goes back and forth in an arc between the two.
			var along := pingpong(seconds * 0.9, 1.0)
			var gap: float = _partner.position.x - position.x
			draw_rect(Rect2(gap * along - 1.0, -8.0 - sin(along * PI) * 10.0, 3, 3), BALL)
		return
	# The two take turns to speak.
	var mine := int(seconds / 1.6) % 2 == (0 if _leisure == Leisure.VISIT else 1)
	if mine:
		draw_rect(Rect2(-5, -26, 11, 7), BUBBLE)
		draw_rect(Rect2(-1, -19, 2, 2), BUBBLE)
		for dot in 3:
			draw_rect(Rect2(-3 + dot * 3, -23 - (1 if int(seconds * 4.0) % 3 == dot else 0), 1, 1), LEGS)


func _draw() -> void:
	if _asleep and position.y < -0.5:
		# In bed: lying down under the sheet.
		draw_rect(Rect2(-5, -8, 11, 3), tunic())
		draw_rect(Rect2(-8, -8, 3, 3), Color(0.93, 0.76, 0.62))
		return
	var bob := _bob()
	var hop := -sin(clampf(_age / HOP_TIME, 0.0, 1.0) * PI) * 7.0
	# Children are drawn smaller.
	var grown := Vector2.ONE * (CHILD_SIZE if person.get("child", false) else 1.0)
	draw_set_transform(Vector2(0, hop), 0.0, grown)
	# Legs: while walking, they take turns stepping.
	var step := int(Time.get_ticks_msec() / 140.0 + position.x) % 2 if _walking else -1
	draw_rect(Rect2(-2, -3, 2, 2 if step == 0 else 3), LEGS)
	draw_rect(Rect2(1, -3, 2, 2 if step == 1 else 3), LEGS)
	# The body sits on top of the legs.
	draw_set_transform(Vector2(0, hop - LEG_HEIGHT * grown.y), 0.0, grown)
	draw_rect(Rect2(-3, bob - 10, 6, 10), tunic())
	draw_rect(Rect2(-2, bob - 14, 4, 4), Color(0.93, 0.76, 0.62))
	if trained:
		draw_rect(Rect2(-3, bob - 16, 6, 2), JobData.TRAINED_HAT)
	if person.get("hurt", false):
		# A bandage round the head.
		draw_rect(Rect2(-3, bob - 13, 6, 2), BANDAGE)
		draw_rect(Rect2(2, bob - 12, 2, 2), BANDAGE)
	_draw_extra(bob)
	draw_set_transform(Vector2.ZERO)
	_draw_leisure()


## How far the body is lifted this frame (negative = up), for work animations.
func _bob() -> float:
	return 0.0


## Jobs draw what the peasant carries or holds here.
func _draw_extra(_bob_y: float) -> void:
	pass


## How well the peasant does their job: twice as well when trained, and
## better or worse for their trait.
func _skill() -> float:
	var raising: float = GameState.PeopleData.RAISING_WORK if person.get("raising", false) else 1.0
	return (GameState.TRAINED_MULT if trained else 1.0) * _trait().get("work", 1.0) * _hurt_pace() * raising


## Slower while hurt (see the "accident" event).
func _hurt_pace() -> float:
	return GameState.EventData.HURT_PACE if person.get("hurt", false) else 1.0


## The peasant's trait (see PeopleData.TRAITS), or an empty Dictionary.
func _trait() -> Dictionary:
	return GameState.PeopleData.TRAITS.get(person.get("trait", ""), {})


## How much faster than their own speed the peasant moves.
func _pace() -> float:
	return GameState.peasant_speed_mult()


## Moves along the ground towards x and returns true once there.
func _walk_to(x: float, delta: float) -> bool:
	return _go_to(Vector2(x, 0), delta)


## Moves towards a point on the ground or on one of the castle's floors,
## taking the stairs where needed. Returns true once there.
func _go_to(target: Vector2, delta: float) -> bool:
	var castle: Node2D = world.castle
	if absf(position.x - target.x) < 0.01 and absf(position.y - target.y) < 0.5:
		_route.clear()
		return true
	if _route.is_empty() or (not _on_stair and (_route_version != castle.version or not target.is_equal_approx(_route_to))):
		_route = castle.route(position, target)
		_route_to = target
		_route_version = castle.version
	var step: Dictionary = _route[0]
	var pace := speed * _pace() * _hurt_pace() * delta
	var there := false
	_on_stair = step.get("stair", false)
	if _on_stair:
		# A flight of stairs inside a building.
		position = position.move_toward(step.pos, pace * STAIR_SPEED)
		there = position.is_equal_approx(step.pos)
	elif absf(step.pos.x - position.x) < 0.01:
		# Up or down a ladder.
		position.y = move_toward(position.y, step.pos.y, pace * CLIMB_SPEED)
		there = is_equal_approx(position.y, step.pos.y)
	else:
		# Along the ground or a floor, following its surface.
		position.x = move_toward(position.x, step.pos.x, pace)
		if position.y < -0.5:
			position.y = castle.surface_at(position)
		there = is_equal_approx(position.x, step.pos.x)
	_inside = step.hidden
	_back = step.back
	if there:
		_route.pop_front()
		_on_stair = not _route.is_empty() and _route[0].get("stair", false)
		_rest_inside = step.hidden and not step.get("stair", false)
	# The way can end short of the target, if there is nothing to stand on there.
	return _route.is_empty()
