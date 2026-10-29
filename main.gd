extends Node2D

const SPEED := 145.0
const StoryData = preload("res://story_data.gd")
var story_flags := {"rumor": false, "field": false, "slime": false, "prologue_done": false}
var event_id := ""
var event_index := 0
var player := Vector2(310, 330)
var facing := Vector2.DOWN
var walk := 0.0
var moving := false
var touches: Dictionary = {}
var mouse_down := false
var mouse_pos := Vector2.ZERO
var map_id := "outside"
var met := false
var inspected := false
var dialogue := ""
var choices := false
var font: Font = preload("res://assets/NotoSansKR.otf")
var chanyu: Texture2D = preload("res://assets/chanyu.png")
var stick_touch := -1
var stick_mouse := false
var stick_vector := Vector2.ZERO
var hint_time := 0.0
var action_feedback := 0.0
var notice := ""
var help_open := true
var camera := Vector2(480, 270)
const ZOOM := 2.0
var fade := 0.0
var monster := Vector2(650, 350)
var monster_hp := 3
var health := 5
# The second member is a prototype fixture, not a story recruitment decision.
var party := [{"id":"chanyu", "hp":5, "max_hp":5, "gauge":0.0, "joined":true}, {"id":"jeongwoo", "hp":5, "max_hp":5, "gauge":0.0, "joined":false}, {"id":"yechan", "hp":5, "max_hp":5, "gauge":0.0, "joined":false}, {"id":"seojin", "hp":5, "max_hp":5, "gauge":0.0, "joined":false}]
var region_enemies := {"field":3, "forest":3, "mountain":3, "approach":3}
var special_time := 0.0
var special_cooldown := 0.0
var special_direction := Vector2.RIGHT
var special_origin := Vector2.ZERO
var projectile_pos := Vector2.ZERO
var projectile_alive := false
var special_kind := 0
var active_member := 0
var follower := Vector2(440, 350)
var game_over := false
var dash_time := 0.0
var dash_cooldown := 0.0
var dash_dir := Vector2.ZERO
var move_input := Vector2.ZERO
var punch_time := 0.0
var punch_direction := Vector2.DOWN
var punch_hit := false
var impact_position := Vector2.ZERO
var impact_time := 0.0
var punch_cooldown := 0.0
var enemy_cooldown := 0.0
var hurt_time := 0.0
var monster_hurt := 0.0
var shake_time := 0.0
var shake_strength := 0.0

func controls() -> Dictionary:
	return {"special": Rect2(660, 300, 76, 76), "party3": Rect2(175, 100, 72, 60), "party4": Rect2(255, 100, 72, 60), "dash": Rect2(665, 400, 72, 72), "party1": Rect2(15, 100, 72, 60), "party2": Rect2(95, 100, 72, 60), "attack": Rect2(755, 315, 80, 80), "action": Rect2(820, 405, 110, 110), "save": Rect2(750, 12, 90, 48), "load": Rect2(850, 12, 98, 48), "help": Rect2(870, 70, 75, 45), "yes": Rect2(335, 385, 135, 48), "no": Rect2(490, 385, 135, 48)}

func stick_center() -> Vector2: return Vector2(115, 425)
func update_stick(pos: Vector2) -> void:
	var offset := pos - stick_center()
	stick_vector = offset.limit_length(62.0)
	if stick_vector.length() < 12.0: stick_vector = Vector2.ZERO

func message(text: String) -> void:
	notice = text
	hint_time = 2.6

func tap(pos: Vector2) -> void:
	var c := controls()
	if c.action.has_point(pos): action_feedback = 0.2
	if help_open:
		help_open = false
		return
	if game_over:
		restart_game(); return
	if c.party1.has_point(pos): switch_member(0); return
	if c.party2.has_point(pos): switch_member(1); return
	if c.party3.has_point(pos): switch_member(2); return
	if c.party4.has_point(pos): switch_member(3); return
	if c.special.has_point(pos): special_attack(); return
	if c.dash.has_point(pos): start_dash(); return
	if c.attack.has_point(pos): punch(); return
	if c.help.has_point(pos): help_open = true; return
	if c.save.has_point(pos): save_game(); return
	if c.load.has_point(pos): load_game(); return
	if dialogue != "":
		if choices:
			if c.yes.has_point(pos): choose(true)
			elif c.no.has_point(pos): choose(false)
		elif c.action.has_point(pos): advance_dialogue()
	elif c.action.has_point(pos): interact()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if not help_open and stick_touch == -1 and event.position.distance_to(stick_center()) <= 95:
				stick_touch = event.index; update_stick(event.position)
			else: tap(event.position)
		elif event.index == stick_touch:
			stick_touch = -1; stick_vector = Vector2.ZERO
	elif event is InputEventScreenDrag and event.index == stick_touch: update_stick(event.position)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			if not help_open and event.position.distance_to(stick_center()) <= 95:
				stick_mouse = true; update_stick(event.position)
			else: tap(event.position)
		else: stick_mouse = false; stick_vector = Vector2.ZERO
	elif event is InputEventMouseMotion and stick_mouse: update_stick(event.position)
	elif event is InputEventKey and event.pressed and not event.echo:
		if help_open: help_open = false; return
		if game_over:
			restart_game(); return
		if event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if choices: choose(true)
			elif dialogue != "": advance_dialogue()
			else: interact()
		elif choices and event.keycode == KEY_1: choose(true)
		elif choices and event.keycode == KEY_2: choose(false)
		elif dialogue == "" and event.keycode >= KEY_1 and event.keycode <= KEY_4: switch_member(event.keycode - KEY_1)
		elif event.keycode == KEY_J or event.keycode == KEY_F: punch()
		elif event.keycode == KEY_SHIFT: start_dash()
		elif event.keycode == KEY_K: special_attack()

func _process(delta: float) -> void:
	fade = maxf(0.0, fade - delta * 2.5)
	action_feedback = maxf(0.0, action_feedback - delta)
	hint_time = maxf(0.0, hint_time - delta)
	punch_time = maxf(0.0, punch_time - delta)
	impact_time = maxf(0.0, impact_time - delta)
	if punch_time > 0 and punch_time <= 0.17 and not punch_hit:
		punch_hit = true
		if dialogue == "" and not help_open: resolve_punch()
	punch_cooldown = maxf(0.0, punch_cooldown - delta)
	hurt_time = maxf(0.0, hurt_time - delta)
	monster_hurt = maxf(0.0, monster_hurt - delta)
	shake_time = maxf(0.0, shake_time - delta)
	special_time = maxf(0.0, special_time - delta)
	special_cooldown = maxf(0.0, special_cooldown - delta)
	if projectile_alive and dialogue == "" and not help_open and not game_over:
		var previous := projectile_pos
		projectile_pos += special_direction * 380 * delta
		if monster_hp > 0 and is_combat_map() and Geometry2D.get_closest_point_to_segment(monster, previous, projectile_pos).distance_to(monster) < 25:
			projectile_alive = false; damage_enemy(1)
		if projectile_pos.distance_to(special_origin) > 260 or not Rect2(0, 0, 960, 540).has_point(projectile_pos): projectile_alive = false
	if is_combat_map() and monster_hp > 0 and dialogue == "" and not help_open and not game_over:
		enemy_cooldown = maxf(0.0, enemy_cooldown - delta)
		var away := player - monster
		if away.length() < 230 and away.length() > 32:
			var next := monster + away.normalized() * 48.0 * minf(delta, 0.05)
			if can_move(next): monster = next
		if away.length() < 38 and enemy_cooldown <= 0:
			health -= 1; enemy_cooldown = 1.6; hurt_time = 0.45
			haptic(35); shake_time = 0.16; shake_strength = 3.0
			party[active_member].hp = health
			if health <= 0:
				var replacement := -1
				for i in range(party.size()):
					if party[i].joined and party[i].hp > 0: replacement = i; break
				if replacement < 0: game_over = true; message("모두 쓰러졌습니다.")
				else: switch_member(replacement); message("동료가 전투를 이어갑니다.")
	var d := Vector2(int(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)), int(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
	if d == Vector2.ZERO and stick_vector.length() >= 12: d = stick_vector.normalized()
	elif d != Vector2.ZERO: d = d.normalized()
	move_input = d
	dash_cooldown = maxf(0.0, dash_cooldown - delta)
	var is_dashing := dash_time > 0.0
	dash_time = maxf(0.0, dash_time - delta)
	if is_dashing: d = dash_dir
	moving = false
	if dialogue == "" and not help_open and not game_over and d != Vector2.ZERO:
		if punch_time <= 0: facing = d.normalized()
		var step := d * (375.0 if is_dashing else SPEED * (0.55 if punch_time > 0 else 1.0)) * minf(delta, 0.05)
		var before := player
		if can_move(player + Vector2(step.x, 0)): player.x += step.x
		if can_move(player + Vector2(0, step.y)): player.y += step.y
		moving = player.distance_squared_to(before) > 0.001
	if follower.distance_to(player) > 45:
		var fstep := follower.direction_to(player) * minf(follower.distance_to(player) - 45, delta * 125.0)
		if can_move(follower + fstep): follower += fstep
	if moving: walk += delta * 9.0
	else: walk = 0.0
	var half := Vector2(960, 540) / (2.0 * ZOOM)
	var desired := player.clamp(half, Vector2(960, 540) - half)
	camera = camera.lerp(desired, 1.0 - exp(-delta * 7.0))
	queue_redraw()

func switch_member(index: int) -> void:
	if index < 0 or index >= party.size() or not party[index].joined or party[index].hp <= 0 or dialogue != "" or help_open or game_over: return
	party[active_member].hp = health
	active_member = index; health = party[index].hp
	projectile_alive = false; special_time = 0.0
	punch_time = 0.0; dash_time = 0.0

func start_dash() -> void:
	if dash_cooldown > 0 or dialogue != "" or help_open or game_over: return
	dash_dir = move_input.normalized() if move_input.length() > 0.1 else facing
	dash_time = 0.16; dash_cooldown = 0.8; punch_time = 0.0

func restart_game() -> void:
	for member in party: member.hp = member.max_hp
	game_over = false; active_member = 0; health = party[0].hp
	player = Vector2(470, 330); follower = Vector2(440, 350)
	map_id = "outside"; monster = Vector2(650, 350); monster_hp = 0 if story_flags.slime else 3; enemy_cooldown = 1.0

func haptic(duration_ms: int) -> void:
	if OS.has_feature("web"):
		JavaScriptBridge.eval("if (navigator.vibrate) navigator.vibrate(%d);" % duration_ms)
	elif OS.has_feature("android"):
		Input.vibrate_handheld(duration_ms)

func punch() -> void:
	if dialogue != "" or help_open or punch_cooldown > 0 or dash_time > 0 or game_over: return
	punch_time = 0.32; punch_cooldown = 0.42; punch_direction = facing; punch_hit = false

func is_combat_map() -> bool:
	return map_id in ["field", "forest", "mountain", "approach"]

func damage_enemy(amount: int) -> void:
	if not is_combat_map() or monster_hp <= 0: return
	monster_hp = maxi(0, monster_hp - amount); region_enemies[map_id] = monster_hp; monster_hurt = 0.25
	impact_position = monster + Vector2(0, -18); impact_time = 0.22
	haptic(20); shake_time = 0.12; shake_strength = 2.0
	if monster_hp <= 0:
		if map_id == "field" and not story_flags.slime:
			story_flags.slime = true; start_event("victory")
		else: message("몬스터를 물리쳤습니다.")

func resolve_punch() -> void:
	if is_combat_map() and monster_hp > 0:
		var offset := monster - player
		if offset.length() < 66 and (offset.length() < 14 or punch_direction.dot(offset.normalized()) > 0.45): damage_enemy(1)

func special_attack() -> void:
	if dialogue != "" or help_open or game_over or special_cooldown > 0: return
	special_cooldown = 1.0; special_time = 0.3; special_direction = facing; special_origin = player; special_kind = active_member
	if active_member == 1 or active_member == 2:
		projectile_pos = player; projectile_alive = true
	else:
		var offset := monster - player
		var forward := offset.dot(facing)
		var lateral := absf(offset.cross(facing))
		if is_combat_map() and monster_hp > 0 and forward >= 0 and forward < (95 if active_member == 0 else 260) and lateral < (40 if active_member == 0 else 22): damage_enemy(1)

func change_region(id: String, entry: Vector2, dir: Vector2) -> void:
	if is_combat_map(): region_enemies[map_id] = monster_hp
	map_id = id; player = entry; facing = dir; follower = player + Vector2(-30, 20)
	monster = Vector2(650, 350); monster_hp = region_enemies.get(id, 0); enemy_cooldown = 1.0
	projectile_alive = false; special_time = 0; fade = 0.8

func can_move(pos: Vector2) -> bool:
	if pos.x < 30 or pos.x > 930 or pos.y < 65 or pos.y > 500: return false
	if map_id == "outside":
		if Rect2(290, 95, 380, 155).has_point(pos): return false
		if Rect2(655, 295, 80, 65).has_point(pos): return false
	elif map_id == "inside":
		if Rect2(355, 145, 250, 65).has_point(pos): return false
		if Rect2(630, 260, 70, 65).has_point(pos): return false
	return true

func target() -> String:
	var objects: Array = []
	if map_id == "outside":
		objects = [{"id":"door", "pos":Vector2(480, 250), "radius":22.0}, {"id":"object", "pos":Vector2(695, 328), "radius":27.0}, {"id":"npc", "pos":Vector2(245, 330), "radius":14.0}, {"id":"exit", "pos":Vector2(920, 350), "radius":20.0}]
	elif map_id == "inside":
		objects = [{"id":"door", "pos":Vector2(480, 470), "radius":22.0}, {"id":"object", "pos":Vector2(665, 295), "radius":24.0}]
	else:
		objects = [{"id":"return", "pos":Vector2(40, 350), "radius":20.0}, {"id":"next", "pos":Vector2(920, 350), "radius":20.0}]
		if map_id in ["forest", "mountain", "approach"]:
			objects.append({"id":"recruit", "pos":Vector2(400, 330), "radius":14.0})
	var best := ""
	var best_score := -999.0
	for item in objects:
		var offset: Vector2 = item.pos - player
		var distance := offset.length()
		var reach: float = maxf(0.0, distance - item.radius)
		if reach > 62.0: continue
		var alignment := facing.dot(offset.normalized()) if distance > 0.1 else 1.0
		# At point-blank range, allow a small amount of sideways overlap.
		if alignment < (0.0 if reach < 12.0 else 0.45): continue
		var score := alignment * 50.0 - reach
		if score > best_score: best_score = score; best = item.id
	return best

func interact() -> void:
	punch_time = 0.0
	match target():
		"door":
			if map_id == "outside": map_id = "inside"; player = Vector2(480, 410); facing = Vector2.UP
			else: map_id = "outside"; player = Vector2(480, 290); facing = Vector2.DOWN
			follower = player + Vector2(-30, 20)
			fade = 0.8
		"object":
			inspected = true; dialogue = "물건을 살펴보았지만 특별한 것은 없었다."
		"npc":
			if not story_flags.rumor: start_event("rumor")
			else:
				dialogue = "마을 사람: 다시 만났네요." if met else "마을 사람: 잠시 이야기할까요?"
				choices = not met
		"exit":
			if not story_flags.rumor: message("떠나기 전에 마을 사람과 이야기하자.")
			else:
				change_region("field", Vector2(85, 350), Vector2.RIGHT)
				if not story_flags.field: start_event("field")
		"return":
			var previous := {"field":"outside", "forest":"field", "mountain":"forest", "approach":"mountain"}.get(map_id, "outside") as String
			change_region(previous, Vector2(865, 350), Vector2.LEFT)
		"next":
			if map_id == "field":
				if not story_flags.slime: message("슬라임이 앞길을 막고 있다.")
				elif not story_flags.prologue_done: start_event("end")
				else: change_region("forest", Vector2(85, 350), Vector2.RIGHT)
			elif map_id == "forest" and party[1].joined: change_region("mountain", Vector2(85, 350), Vector2.RIGHT)
			elif map_id == "mountain" and party[2].joined: change_region("approach", Vector2(85, 350), Vector2.RIGHT)
			elif map_id == "approach": message("마왕성은 아직 준비 중입니다.")
			else: message("먼저 이곳의 동료를 만나세요.")
		"recruit":
			var index := {"forest":1, "mountain":2, "approach":3}.get(map_id, 0) as int
			if not party[index].joined: start_event("join%d" % index)
			else: dialogue = "이미 함께하고 있습니다."
		_: message("대상 쪽을 바라보고 가까이 다가가세요.")

func start_event(id: String) -> void:
	if not StoryData.EVENTS.has(id): return
	event_id = id; event_index = 0; choices = false
	dialogue = StoryData.EVENTS[id][0]

func advance_dialogue() -> void:
	if event_id == "": dialogue = ""; return
	event_index += 1
	if event_index < StoryData.EVENTS[event_id].size():
		dialogue = StoryData.EVENTS[event_id][event_index]
		return
	match event_id:
		"rumor": story_flags.rumor = true
		"field": story_flags.field = true
		"end": story_flags.prologue_done = true
		"join1": party[1].joined = true
		"join2": party[2].joined = true
		"join3": party[3].joined = true
	event_id = ""; dialogue = ""

func objective() -> String:
	if not story_flags.rumor: return StoryData.OBJECTIVES[0]
	if not story_flags.field: return StoryData.OBJECTIVES[1]
	if not story_flags.slime: return StoryData.OBJECTIVES[2]
	if not story_flags.prologue_done: return StoryData.OBJECTIVES[3]
	if not party[1].joined: return "숲에서 동료를 만나자"
	if not party[2].joined: return "산길에서 동료를 만나자"
	if not party[3].joined: return "성 앞에서 동료를 만나자"
	return "마왕성을 향하자"

func choose(yes: bool) -> void:
	choices = false
	met = yes
	dialogue = "마을 사람: 조심해서 다녀오세요." if yes else "마을 사람: 필요하면 언제든 들르세요."

func save_game() -> void:
	if dialogue != "" or help_open:
		message("대화를 마친 뒤 저장할 수 있습니다."); return
	var file := FileAccess.open("user://prototype_save.json", FileAccess.WRITE)
	if file == null: message("저장하지 못했습니다."); return
	party[active_member].hp = health
	file.store_string(JSON.stringify({"story_flags": story_flags, "region_enemies": region_enemies, "slime_hp": region_enemies.field, "party": party, "active_member": active_member, "version": 1, "map": map_id, "x": player.x, "y": player.y, "met": met, "inspected": inspected, "facing_x": facing.x, "facing_y": facing.y}))
	file.close()
	message("저장했습니다.")

func load_game() -> void:
	if dialogue != "" or help_open:
		message("대화를 마친 뒤 불러올 수 있습니다."); return
	if not FileAccess.file_exists("user://prototype_save.json"):
		message("저장된 데이터가 없습니다."); return
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string("user://prototype_save.json")) != OK:
		message("저장 데이터가 손상되어 불러올 수 없습니다."); return
	var data = parser.data
	if not data is Dictionary or data.get("version") != 1 or data.get("map") not in ["outside", "inside", "field", "forest", "mountain", "approach"] or not (data.get("x") is float or data.get("x") is int) or not (data.get("y") is float or data.get("y") is int) or not data.get("met", false) is bool or not data.get("inspected", false) is bool:
		message("저장 데이터가 손상되어 불러올 수 없습니다."); return
	var old_map := map_id
	map_id = data.map
	var position := Vector2(data.x, data.y)
	if not position.is_finite() or not can_move(position):
		map_id = old_map; message("저장 위치가 올바르지 않습니다."); return
	player = position; met = data.get("met", false); inspected = data.get("inspected", false)
	var fx = data.get("facing_x", 0.0); var fy = data.get("facing_y", 1.0)
	if (fx is float or fx is int) and (fy is float or fy is int):
		var loaded_facing := Vector2(fx, fy)
		if loaded_facing.is_finite() and loaded_facing.length() > 0.1: facing = loaded_facing.normalized()
	# Older saves lack party state; restore the prototype defaults.
	for member in party:
		member.hp = member.max_hp; member.gauge = 0.0; member.joined = member.id == "chanyu"
	var saved_party = data.get("party", [])
	if saved_party is Array:
		for i in range(mini(saved_party.size(), party.size())):
			var member = saved_party[i]
			if member is Dictionary and (member.get("hp") is int or member.get("hp") is float) and member.get("joined") is bool and member.get("gauge", 0.0) is float:
				party[i].hp = clampi(int(member.hp), 0, party[i].max_hp); party[i].joined = member.joined if (i == 0 or (saved_party.size() == 4 and member.get("id", "") == party[i].id)) else false; party[i].gauge = clampf(member.get("gauge", 0.0), 0.0, 1.0)
	var selected = data.get("active_member", 0)
	active_member = int(selected) if (selected is int or selected is float) and int(selected) >= 0 and int(selected) < party.size() and party[int(selected)].joined and party[int(selected)].hp > 0 else 0
	health = party[active_member].hp
	game_over = health <= 0; follower = player + Vector2(-30, 20)
	var saved_flags = data.get("story_flags", {})
	for key in story_flags:
		story_flags[key] = saved_flags.get(key, false) if saved_flags is Dictionary and saved_flags.get(key, false) is bool else false
	var saved_hp = data.get("slime_hp", 3)
	region_enemies = {"field":3, "forest":3, "mountain":3, "approach":3}
	var saved_enemies = data.get("region_enemies", {})
	if saved_enemies is Dictionary:
		for key in region_enemies:
			var n = saved_enemies.get(key, 3)
			if n is float or n is int: region_enemies[key] = clampi(int(n), 0, 3)
	else: saved_enemies = {}
	if not saved_enemies.has("field") and (saved_hp is float or saved_hp is int): region_enemies.field = clampi(int(saved_hp), 0, 3)
	if story_flags.slime: region_enemies.field = 0
	monster_hp = region_enemies.get(map_id, 0)
	monster = Vector2(650, 350)
	fade = 0.8; message("불러왔습니다.")

func panel(area: Rect2, fill: Color, border: Color) -> void:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(9)
	style.shadow_color = Color(0, 0, 0, 0.25)
	style.shadow_size = 6
	style.shadow_offset = Vector2(0, 4)
	draw_style_box(style, area)

func draw_ellipse_shadow(pos: Vector2) -> void:
	var points := PackedVector2Array()
	for i in range(24): points.append(pos + Vector2(cos(i * TAU / 24) * 17, sin(i * TAU / 24) * 5))
	draw_colored_polygon(points, Color(0.08, 0.15, 0.14, 0.3))

func rect(r: Rect2, col: String) -> void: draw_rect(r, Color(col))
func label(pos: Vector2, value: String, size: int = 18, col: Color = Color.WHITE) -> void: draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
func draw_chanyu(pos: Vector2, dir: Vector2, phase: float, hurt: bool) -> void:
	draw_ellipse_shadow(pos)
	var row := 0
	if absf(dir.x) > absf(dir.y): row = 1 if dir.x < 0 else 2
	elif dir.y < 0: row = 3
	var column := 0
	if phase != 0.0: column = 1 if sin(phase) >= 0 else 2
	var source := Rect2(column * 181, row * 181 + 10, 181, 171)
	var tint := Color(1.0, 0.65, 0.65) if hurt else Color.WHITE
	draw_texture_rect_region(chanyu, Rect2(pos + Vector2(-31, -59), Vector2(62, 58.5)), source, tint)

func person(pos: Vector2, dir: Vector2, phase: float, color: Color) -> void:
	draw_ellipse_shadow(pos)
	var p := pos.round() + Vector2(-15, -42)
	var outline := Color("39495a")
	var swing := int(round(sin(phase))) if phase != 0.0 else 0
	var bob: int = absi(swing)
	p.y -= bob * 2
	draw_rect(Rect2(p + Vector2(6, 0), Vector2(18, 18)), outline)
	draw_rect(Rect2(p + Vector2(9, 3), Vector2(12, 12)), color)
	draw_rect(Rect2(p + Vector2(6, 18), Vector2(18, 17)), outline)
	draw_rect(Rect2(p + Vector2(9, 18), Vector2(12, 14)), color.darkened(0.1))
	draw_rect(Rect2(p + Vector2(9, 18), Vector2(12, 3)), color.lightened(0.12))
	draw_rect(Rect2(p + Vector2(12, 24), Vector2(6, 3)), color.darkened(0.22))
	if dir.y < -0.5: draw_rect(Rect2(p + Vector2(9, 3), Vector2(12, 7)), color.darkened(0.2))
	elif absf(dir.x) > absf(dir.y): draw_rect(Rect2(p + Vector2(9 if dir.x < 0 else 18, 6), Vector2(3, 3)), outline)
	else:
		draw_rect(Rect2(p + Vector2(9, 7), Vector2(3, 3)), outline)
		draw_rect(Rect2(p + Vector2(18, 7), Vector2(3, 3)), outline)
	draw_rect(Rect2(p + Vector2(2, 19 + swing * 2), Vector2(5, 13)), outline)
	draw_rect(Rect2(p + Vector2(23, 19 - swing * 2), Vector2(5, 13)), outline)
	draw_rect(Rect2(p + Vector2(7, 34), Vector2(7, 10 + swing * 3)), outline)
	draw_rect(Rect2(p + Vector2(5, 42 + swing * 3), Vector2(9, 3)), Color("24343d"))
	draw_rect(Rect2(p + Vector2(16, 34), Vector2(7, 10 - swing * 3)), outline)
	draw_rect(Rect2(p + Vector2(16, 42 - swing * 3), Vector2(9, 3)), Color("24343d"))

func _draw() -> void:
	var s := Vector2(960, 540)
	var camera_draw := camera
	if shake_time > 0.0:
		var offset := Vector2(sin(shake_time * 100.0), cos(shake_time * 131.0)) * shake_strength * minf(shake_time / 0.08, 1.0)
		var half := s / (2.0 * ZOOM)
		camera_draw = (camera + offset).clamp(half, s - half)
	draw_set_transform(s / 2.0 - camera_draw * ZOOM, 0.0, Vector2.ONE * ZOOM)
	rect(Rect2(Vector2.ZERO, s), "415951" if map_id != "inside" else "55514d")
	if map_id != "inside":
		# Stone walkway, inset curb, and quiet vegetation.
		rect(Rect2(0, 275, 960, 125), "687273")
		rect(Rect2(0, 280, 960, 115), "89918a")
		rect(Rect2(425, 245, 110, 295), "89918a")
		for y in range(284, 390, 27):
			for x in range(0, 960, 48):
				draw_rect(Rect2(x + (24 if y % 2 == 0 else 0), y, 46, 25), Color("a2a79a"), false, 1)
		for i in range(32):
			var q := Vector2(40 + (i * 79) % 880, 425 + (i * 17) % 90)
			if absf(q.x - 480) < 65: continue
			draw_line(q, q + Vector2(-3, -6), Color("6a8470"), 2)
			draw_line(q, q + Vector2(4, -5), Color("617b68"), 2)
		for x in [210, 750]:
			draw_circle(Vector2(x, 260), 23, Color("30483f"))
			draw_circle(Vector2(x - 5, 251), 16, Color("63806a"))
			draw_circle(Vector2(x + 10, 255), 13, Color("76907a"))
	else:
		for y in range(60, 540, 28):
			for x in range(0, 960, 96):
				draw_rect(Rect2(x, y, 94, 26), Color("756b60"), false, 1)
		rect(Rect2(390, 290, 180, 135), "415e5e")
		draw_rect(Rect2(398, 298, 164, 119), Color("9bafa2"), false, 2)
	if map_id in ["forest", "mountain", "approach"]:
		var terrain := {"forest":Color("375344"), "mountain":Color("666a68"), "approach":Color("49434f")}[map_id] as Color
		for i in range(8):
			var x := 70.0 + i * 120.0
			if map_id == "forest":
				draw_rect(Rect2(x, 100, 18, 70), Color("50483d")); draw_circle(Vector2(x + 9, 100), 35, terrain)
			elif map_id == "mountain":
				draw_colored_polygon(PackedVector2Array([Vector2(x - 30, 210), Vector2(x + 10, 105), Vector2(x + 55, 210)]), terrain)
			else:
				draw_rect(Rect2(x, 110, 85, 95), terrain); draw_rect(Rect2(x + 30, 135, 24, 55), Color("262e38"))
	if map_id == "outside":
		rect(Rect2(298, 100, 390, 160), "30423e"); rect(Rect2(285, 85, 390, 165), "344858"); rect(Rect2(300, 105, 360, 145), "c7b5a0")
		rect(Rect2(285, 85, 390, 30), "7d6260"); rect(Rect2(445, 175, 70, 75), "4c5360")
		rect(Rect2(455, 185, 50, 65), "8c7263"); rect(Rect2(320, 135, 65, 45), "96bbc1"); rect(Rect2(575, 135, 65, 45), "96bbc1")
		rect(Rect2(458, 190, 44, 3), "ad9981"); rect(Rect2(491, 217, 4, 5), "e1cc99")
		for x in [350, 605]:
			rect(Rect2(x, 135, 4, 45), "d9d2bd"); rect(Rect2(x - 30, 155, 65, 3), "d9d2bd")
		rect(Rect2(285, 112, 390, 5), "645758")
		for x in [304, 647]:
			rect(Rect2(x, 116, 10, 134), "a39483"); rect(Rect2(x, 116, 3, 134), "e1d2b6")
		rect(Rect2(438, 165, 84, 10), "6e6158")
		rect(Rect2(437, 248, 86, 8), "b3b7a4")
		for x in [417, 539]:
			rect(Rect2(x, 184, 5, 24), "405251")
			rect(Rect2(x - 3, 181, 11, 12), "e4d4a1")
		for x in range(310, 650, 40): rect(Rect2(x, 87, 18, 3), "ad8e83")
		rect(Rect2(665, 305, 60, 45), "8a725b"); rect(Rect2(670, 310, 50, 12), "c2a581"); rect(Rect2(680, 325, 30, 3), "d8c6a1"); rect(Rect2(690, 336, 8, 4), "d8c6a1")
		person(Vector2(245, 330), Vector2.DOWN, 0.0, Color("c9bdad"))
	elif map_id == "inside":
		rect(Rect2(355, 145, 250, 65), "8a705b"); rect(Rect2(365, 150, 230, 35), "b7a084")
		rect(Rect2(640, 270, 50, 45), "94775b"); rect(Rect2(645, 275, 40, 10), "c7ac84")
		rect(Rect2(440, 470, 80, 28), "927b67"); rect(Rect2(448, 474, 64, 3), "c4ad88")
	if map_id == "outside":
		label(Vector2(850, 320), "동쪽 길 →", 18)
	elif is_combat_map():
		label(Vector2(20, 310), "← 돌아가기", 18)
		label(Vector2(845, 310), "숲 →", 18)
	if is_combat_map() and monster_hp > 0:
		var m := monster.round()
		draw_ellipse_shadow(m)
		draw_circle(m + Vector2(0, -12), 19, Color("e8c49b") if monster_hurt > 0 else Color("374c53"))
		draw_circle(m + Vector2(0, -14), 15, Color("a7bbb0"))
		draw_circle(m + Vector2(-5, -21), 5, Color("d7e0c7"))
		draw_rect(Rect2(m + Vector2(-5, -7), Vector2(10, 2)), Color("506d66"))
		draw_circle(m + Vector2(-5, -16), 2, Color("273b40")); draw_circle(m + Vector2(5, -16), 2, Color("273b40"))
		draw_rect(Rect2(m + Vector2(-18, -40), Vector2(36, 4)), Color("344449"))
		draw_rect(Rect2(m + Vector2(-18, -40), Vector2(12 * monster_hp, 4)), Color("c7d6a8"))
	var attack_amount := 0.0
	if punch_time > 0:
		var elapsed := 0.32 - punch_time
		if elapsed < 0.08: attack_amount = -sin(elapsed / 0.08 * PI / 2) * 0.18
		elif elapsed < 0.15: attack_amount = lerpf(-0.18, 1.0, (elapsed - 0.08) / 0.07)
		else: attack_amount = pow(punch_time / 0.17, 2.0)
	var pose := player + punch_direction * attack_amount * 4
	for i in range(party.size()):
		if i == active_member or not party[i].joined or party[i].hp <= 0: continue
		var follower_pos := follower + Vector2(-20 * i, 13 * i)
		if i == 0: draw_chanyu(follower_pos, facing, walk if moving else 0.0, false)
		else: person(follower_pos, facing, walk if moving else 0.0, Color("aeb9c9"))
	if special_time > 0 and special_kind == 0:
		var blade_side := Vector2(-special_direction.y, special_direction.x)
		var end := special_origin + special_direction * 60 + blade_side * (special_time - 0.15) * 160
		draw_line(special_origin + Vector2(0, -18), end + Vector2(0, -18), Color("e1efdc"), 5)
	elif special_time > 0 and special_kind == 3:
		draw_line(special_origin + Vector2(0, -18), special_origin + special_direction * 260 + Vector2(0, -18), Color("c6e5f2"), 9)
	if projectile_alive:
		draw_circle(projectile_pos + Vector2(0, -18), 9, Color("b0ded5") if special_kind == 1 else Color("c9d989"))
	if map_id in ["forest", "mountain", "approach"]:
		var idx := {"forest":1, "mountain":2, "approach":3}[map_id] as int
		if not party[idx].joined: person(Vector2(400, 330), Vector2.DOWN, 0.0, Color("c7b6a3"))
	if dash_time > 0:
		draw_circle(player - dash_dir * 20 + Vector2(0, -20), 11, Color(0.75, 0.9, 0.85, 0.25))
	if active_member == 0: draw_chanyu(pose, facing, walk if moving and punch_time <= 0 else 0.0, hurt_time > 0)
	else: person(pose, facing, walk if moving and punch_time <= 0 else 0.0, Color("e6a99c") if hurt_time > 0 else Color("aeb9c9"))
	if punch_time > 0:
		var side_arm := Vector2(-punch_direction.y, punch_direction.x)
		var shoulder := pose + Vector2(0, -22) + side_arm * 7
		var elbow := shoulder + punch_direction * (8 + attack_amount * 11) + side_arm * (5 - attack_amount * 5)
		var fist := shoulder + punch_direction * (14 + attack_amount * 32)
		draw_line(shoulder, elbow, Color("3d5059"), 9)
		draw_line(elbow, fist, Color("dce5e4"), 7)
		draw_rect(Rect2(fist - Vector2(6, 6), Vector2(13, 12)), Color("344953"))
		draw_rect(Rect2(fist - Vector2(4, 4), Vector2(10, 8)), Color("f0e1c9"))
		if attack_amount > 0.7:
			draw_line(fist - punch_direction * 18 + side_arm * 10, fist + side_arm * 10, Color(0.95, 0.94, 0.8, 0.6), 2)
	if impact_time > 0:
		var spread := (0.22 - impact_time) * 60
		for i in range(6):
			var ray := Vector2.from_angle(i * TAU / 6)
			draw_line(impact_position + ray * (4 + spread), impact_position + ray * (10 + spread), Color(1, 0.92, 0.66, impact_time / 0.22), 2)
	var arrow_center := player + facing * 27.0 + Vector2(0, -17)
	var side := Vector2(-facing.y, facing.x)
	draw_colored_polygon(PackedVector2Array([arrow_center + facing * 6, arrow_center - facing * 4 + side * 4, arrow_center - facing * 4 - side * 4]), Color(0.9, 0.94, 0.75, 0.8))
	draw_set_transform(Vector2.ZERO)
	if fade > 0: draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, fade))
	var c := controls()
	panel(Rect2(14, 12, 210, 69), Color("182b30"), Color("47635e"))
	draw_circle(stick_center() + Vector2(0, 4), 80, Color(0, 0, 0, 0.15))
	draw_circle(stick_center(), 80, Color(0.08, 0.13, 0.17, 0.68))
	draw_arc(stick_center(), 56, 0, TAU, 48, Color(0.7, 0.8, 0.75, 0.15), 1)
	for angle in [0.0, PI / 2, PI, PI * 1.5]:
		var tick := Vector2.from_angle(angle)
		draw_line(stick_center() + tick * 67, stick_center() + tick * 73, Color("a3b7ac"), 2)
	draw_arc(stick_center(), 78, 0, TAU, 48, Color(0.75, 0.85, 0.82, 0.5), 2)
	draw_circle(stick_center() + stick_vector, 32, Color(0.68, 0.79, 0.76, 0.85 if stick_vector != Vector2.ZERO else 0.6))
	for i in range(party.size()):
		if not party[i].joined: continue
		var r: Rect2 = c["party%d" % (i + 1)]
		panel(r, Color("34544f") if active_member == i else Color("182b30"), Color("a2c3a9") if active_member == i else Color("54736b"))
		label(r.position + Vector2(8, 23), ["찬유", "정우", "예찬", "서진"][i], 16)
		label(r.position + Vector2(8, 48), "%d / %d" % [party[i].hp, party[i].max_hp], 14)
	draw_circle(c.special.get_center(), 36, Color("496e76") if special_cooldown <= 0 else Color("39484d"))
	label(c.special.get_center() + Vector2(-19, 6), "특수", 18)
	draw_circle(c.dash.get_center(), 34, Color("536d79") if dash_cooldown <= 0 else Color("39484d"))
	label(c.dash.get_center() + Vector2(-19, 6), "대시", 18)
	draw_circle(c.attack.get_center(), 38, Color("aa715f") if punch_time > 0 else Color("754d45"))
	draw_arc(c.attack.get_center(), 36, 0, TAU, 40, Color("e2c0a0"), 2)
	label(c.attack.get_center() + Vector2(-19, 6), "공격", 19)
	if not OS.has_feature("mobile"): label(c.attack.get_center() + Vector2(-4, 24), "J", 11, Color("dac3b3"))
	draw_circle(c.action.get_center(), 51, Color(0.32, 0.55, 0.53, 0.98) if action_feedback > 0 else Color(0.16, 0.35, 0.36, 0.94))
	draw_arc(c.action.get_center(), 48, 0, TAU, 48, Color(0.75, 0.87, 0.82, 0.8), 2)
	label(c.action.get_center() + Vector2(-19, 7), "확인", 19)
	for key in ["save", "load", "help"]:
		panel(c[key], Color("182b30"), Color("54736b"))
		label(c[key].position + Vector2(10, 30), "저장" if key == "save" else ("불러오기" if key == "load" else "도움말"), 16)
	for i in range(5):
		draw_circle(Vector2(28 + i * 18, 55), 6, Color("e7a99d") if i < health else Color("566465"))
	label(Vector2(20, 30), {"outside":"시작 마을", "inside":"마을 실내", "field":"마을 밖 들판", "forest":"숲길", "mountain":"산길", "approach":"마왕성 앞"}.get(map_id, ""), 18)
	if dialogue == "" and not help_open:
		label(Vector2(250, 35), "목표: " + objective(), 16, Color("e6ead9"))
	if dialogue != "":
		panel(Rect2(230, 290, 500, 155), Color("15272d"), Color("a2b3a0"))
		draw_rect(Rect2(230, 290, 500, 3), Color("90b2a9"))
		draw_rect(Rect2(236, 297, 2, 141), Color(0.5, 0.68, 0.63, 0.5))
		draw_multiline_string(font, Vector2(250, 325), dialogue, HORIZONTAL_ALIGNMENT_LEFT, 455, 18, 2)
		if choices:
			for key in ["yes", "no"]: panel(c[key], Color("34544f"), Color("6a8d7d"))
			label(Vector2(380, 416), "네", 18); label(Vector2(525, 416), "아니요", 18)
		else: label(Vector2(250, 410), "확인 버튼으로 계속", 16, Color("b9c9c5"))
	if hint_time > 0:
		draw_rect(Rect2(240, 70, 480, 40), Color(0.08, 0.13, 0.17, 0.95))
		label(Vector2(255, 97), notice, 17)
	if help_open:
		panel(Rect2(180, 120, 600, 255), Color("15272d"), Color("93afa0"))
		label(Vector2(210, 165), "조작 안내", 24)
		label(Vector2(210, 210), "왼쪽 조이스틱을 움직여 이동하세요.", 19)
		label(Vector2(210, 245), "대상을 바라본 채 가까이에서 확인을 누르세요.", 19)
		label(Vector2(210, 280), "WASD 이동 · J 공격 · K 특수 · E 확인", 18)
		label(Vector2(210, 335), "1~4 교체 · 화면을 눌러 닫기", 18, Color("b8d0c8"))

	if game_over:
		panel(Rect2(250, 190, 460, 150), Color("15272d"), Color("93afa0"))
		label(Vector2(365, 245), "모두 쓰러졌습니다", 24)
		label(Vector2(325, 295), "화면을 눌러 다시 시작", 18)
