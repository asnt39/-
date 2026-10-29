extends Node2D

const SPEED := 145.0
var player := Vector2(470, 330)
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
var stick_touch := -1
var stick_mouse := false
var stick_vector := Vector2.ZERO
var hint_time := 0.0
var action_feedback := 0.0
var notice := ""
var help_open := true
var camera := Vector2(480, 270)
const ZOOM := 1.25
var fade := 0.0

func controls() -> Dictionary:
	return {"action": Rect2(820, 405, 110, 110), "save": Rect2(750, 12, 90, 48), "load": Rect2(850, 12, 98, 48), "help": Rect2(870, 70, 75, 45), "yes": Rect2(335, 385, 135, 48), "no": Rect2(490, 385, 135, 48)}

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
	if c.help.has_point(pos): help_open = true; return
	if c.save.has_point(pos): save_game(); return
	if c.load.has_point(pos): load_game(); return
	if dialogue != "":
		if choices:
			if c.yes.has_point(pos): choose(true)
			elif c.no.has_point(pos): choose(false)
		elif c.action.has_point(pos): dialogue = ""
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
		if event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if choices: choose(true)
			elif dialogue != "": dialogue = ""
			else: interact()
		elif choices and event.keycode == KEY_2: choose(false)

func _process(delta: float) -> void:
	fade = maxf(0.0, fade - delta * 2.5)
	action_feedback = maxf(0.0, action_feedback - delta)
	hint_time = maxf(0.0, hint_time - delta)
	var d := Vector2(int(Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D)) - int(Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A)), int(Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S)) - int(Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W)))
	if d == Vector2.ZERO and stick_vector.length() >= 12: d = stick_vector.normalized()
	elif d != Vector2.ZERO: d = d.normalized()
	moving = false
	if dialogue == "" and not help_open and d != Vector2.ZERO:
		facing = d.normalized()
		var step := d * SPEED * minf(delta, 0.05)
		var before := player
		if can_move(player + Vector2(step.x, 0)): player.x += step.x
		if can_move(player + Vector2(0, step.y)): player.y += step.y
		moving = player.distance_squared_to(before) > 0.001
	if moving: walk += delta * 9.0
	else: walk = 0.0
	var half := Vector2(960, 540) / (2.0 * ZOOM)
	var desired := player.clamp(half, Vector2(960, 540) - half)
	camera = camera.lerp(desired, 1.0 - exp(-delta * 7.0))
	queue_redraw()

func can_move(pos: Vector2) -> bool:
	if pos.x < 30 or pos.x > 930 or pos.y < 65 or pos.y > 500: return false
	if map_id == "outside":
		if Rect2(290, 95, 380, 155).has_point(pos): return false
		if Rect2(655, 295, 80, 65).has_point(pos): return false
	else:
		if Rect2(355, 145, 250, 65).has_point(pos): return false
		if Rect2(630, 260, 70, 65).has_point(pos): return false
	return true

func target() -> String:
	var objects := [{"id":"door", "pos":Vector2(480, 257)}, {"id":"object", "pos":Vector2(695, 328)}, {"id":"npc", "pos":Vector2(245, 330)}] if map_id == "outside" else [{"id":"door", "pos":Vector2(480, 470)}, {"id":"object", "pos":Vector2(665, 295)}]
	var best := ""
	var best_score := -999.0
	for item in objects:
		var offset: Vector2 = item.pos - player
		var distance := offset.length()
		if distance < 1.0 or distance > 85.0: continue
		var alignment := facing.dot(offset / distance)
		if alignment < 0.65: continue
		var score := alignment * 100.0 - distance * 0.6
		if score > best_score: best_score = score; best = item.id
	return best

func interact() -> void:
	match target():
		"door":
			if map_id == "outside": map_id = "inside"; player = Vector2(480, 410); facing = Vector2.UP
			else: map_id = "outside"; player = Vector2(480, 290); facing = Vector2.DOWN
			fade = 0.8
		"object":
			inspected = true; dialogue = "테스트 물건을 살펴보았습니다."
		"npc":
			dialogue = "[테스트 인물] 다시 만났네요." if met else "[테스트 인물] 잠시 이야기할까요?"
			choices = not met
		_: message("대상 쪽을 바라보고 가까이 다가가세요.")

func choose(yes: bool) -> void:
	choices = false
	met = yes
	dialogue = "[테스트 인물] 이야기를 나눴습니다." if yes else "[테스트 인물] 다음에 이야기해요."

func save_game() -> void:
	if dialogue != "" or help_open:
		message("대화를 마친 뒤 저장할 수 있습니다."); return
	var file := FileAccess.open("user://prototype_save.json", FileAccess.WRITE)
	if file == null: message("저장하지 못했습니다."); return
	file.store_string(JSON.stringify({"version": 1, "map": map_id, "x": player.x, "y": player.y, "met": met, "inspected": inspected, "facing_x": facing.x, "facing_y": facing.y}))
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
	if not data is Dictionary or data.get("version") != 1 or data.get("map") not in ["outside", "inside"] or not (data.get("x") is float or data.get("x") is int) or not (data.get("y") is float or data.get("y") is int) or not data.get("met", false) is bool or not data.get("inspected", false) is bool:
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
	fade = 0.8; message("불러왔습니다.")

func rect(r: Rect2, col: String) -> void: draw_rect(r, Color(col))
func label(pos: Vector2, value: String, size: int = 18, col: Color = Color.WHITE) -> void: draw_string(font, pos, value, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)
func person(pos: Vector2, dir: Vector2, phase: float, color: Color) -> void:
	var p := pos.round() + Vector2(-15, -42)
	var outline := Color("39495a")
	var swing := int(round(sin(phase))) if phase != 0.0 else 0
	var bob: int = absi(swing)
	p.y -= bob * 2
	draw_rect(Rect2(p + Vector2(6, 0), Vector2(18, 18)), outline)
	draw_rect(Rect2(p + Vector2(9, 3), Vector2(12, 12)), color)
	draw_rect(Rect2(p + Vector2(6, 18), Vector2(18, 17)), outline)
	draw_rect(Rect2(p + Vector2(9, 18), Vector2(12, 14)), color.darkened(0.1))
	if dir.y < -0.5: draw_rect(Rect2(p + Vector2(9, 3), Vector2(12, 7)), color.darkened(0.2))
	elif absf(dir.x) > absf(dir.y): draw_rect(Rect2(p + Vector2(9 if dir.x < 0 else 18, 6), Vector2(3, 3)), outline)
	else:
		draw_rect(Rect2(p + Vector2(9, 7), Vector2(3, 3)), outline)
		draw_rect(Rect2(p + Vector2(18, 7), Vector2(3, 3)), outline)
	draw_rect(Rect2(p + Vector2(2, 19 + swing * 2), Vector2(5, 13)), outline)
	draw_rect(Rect2(p + Vector2(23, 19 - swing * 2), Vector2(5, 13)), outline)
	draw_rect(Rect2(p + Vector2(7, 34), Vector2(7, 10 + swing * 3)), outline)
	draw_rect(Rect2(p + Vector2(16, 34), Vector2(7, 10 - swing * 3)), outline)

func _draw() -> void:
	var s := Vector2(960, 540)
	draw_set_transform(s / 2.0 - camera * ZOOM, 0.0, Vector2.ONE * ZOOM)
	rect(Rect2(Vector2.ZERO, s), "526b61" if map_id == "outside" else "665e57")
	for x in range(0, int(s.x), 40): draw_line(Vector2(x, 0), Vector2(x, s.y), Color(1, 1, 1, 0.07))
	for y in range(0, int(s.y), 40): draw_line(Vector2(0, y), Vector2(s.x, y), Color(1, 1, 1, 0.07))
	if map_id == "outside":
		rect(Rect2(285, 85, 390, 165), "344858"); rect(Rect2(300, 105, 360, 145), "c7b5a0")
		rect(Rect2(285, 85, 390, 30), "7d6260"); rect(Rect2(445, 175, 70, 75), "4c5360")
		rect(Rect2(455, 185, 50, 65), "8c7263"); rect(Rect2(320, 135, 65, 45), "96bbc1"); rect(Rect2(575, 135, 65, 45), "96bbc1")
		rect(Rect2(665, 305, 60, 45), "8a725b"); rect(Rect2(670, 310, 50, 12), "c2a581")
		person(Vector2(245, 330), Vector2.DOWN, 0.0, Color("c9bdad"))
	else:
		rect(Rect2(355, 145, 250, 65), "8a705b"); rect(Rect2(365, 150, 230, 35), "b7a084")
		rect(Rect2(640, 270, 50, 45), "94775b"); rect(Rect2(645, 275, 40, 10), "c7ac84")
		rect(Rect2(440, 470, 80, 28), "927b67")
	person(player, facing, walk if moving else 0.0, Color("dce5e4"))
	var arrow_center := player + facing * 27.0 + Vector2(0, -17)
	var side := Vector2(-facing.y, facing.x)
	draw_colored_polygon(PackedVector2Array([arrow_center + facing * 6, arrow_center - facing * 4 + side * 4, arrow_center - facing * 4 - side * 4]), Color(0.9, 0.94, 0.75, 0.8))
	draw_set_transform(Vector2.ZERO)
	if fade > 0: draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, fade))
	var c := controls()
	draw_circle(stick_center(), 80, Color(0.08, 0.13, 0.17, 0.55))
	draw_arc(stick_center(), 78, 0, TAU, 48, Color(0.75, 0.85, 0.82, 0.5), 2)
	draw_circle(stick_center() + stick_vector, 32, Color(0.68, 0.79, 0.76, 0.85 if stick_vector != Vector2.ZERO else 0.6))
	draw_circle(c.action.get_center(), 51, Color(0.32, 0.55, 0.53, 0.98) if action_feedback > 0 else Color(0.16, 0.35, 0.36, 0.94))
	draw_arc(c.action.get_center(), 48, 0, TAU, 48, Color(0.75, 0.87, 0.82, 0.8), 2)
	label(c.action.get_center() + Vector2(-19, 7), "확인", 19)
	for key in ["save", "load", "help"]:
		draw_rect(c[key], Color(0.08, 0.13, 0.17, 0.88))
		label(c[key].position + Vector2(10, 30), "저장" if key == "save" else ("불러오기" if key == "load" else "도움말"), 16)
	label(Vector2(20, 30), "테스트 맵 · " + ("바깥" if map_id == "outside" else "실내"), 18)
	if dialogue == "" and not help_open:
		label(Vector2(250, 35), "확인: 상호작용" if target() != "" else "대상을 바라보고 가까이 가세요", 16, Color("e6ead9"))
	if dialogue != "":
		draw_rect(Rect2(230, 290, 500, 155), Color(0.07, 0.11, 0.15, 0.96))
		draw_rect(Rect2(230, 290, 500, 3), Color("90b2a9"))
		label(Vector2(250, 335), dialogue, 19)
		if choices:
			for key in ["yes", "no"]: draw_rect(c[key], Color("426c68"))
			label(Vector2(380, 416), "네", 18); label(Vector2(525, 416), "아니요", 18)
		else: label(Vector2(250, 410), "확인 버튼으로 계속", 16, Color("b9c9c5"))
	if hint_time > 0:
		draw_rect(Rect2(240, 70, 480, 40), Color(0.08, 0.13, 0.17, 0.95))
		label(Vector2(255, 97), notice, 17)
	if help_open:
		draw_rect(Rect2(180, 120, 600, 255), Color(0.06, 0.1, 0.14, 0.97))
		label(Vector2(210, 165), "조작 안내", 24)
		label(Vector2(210, 210), "왼쪽 조이스틱을 움직여 이동하세요.", 19)
		label(Vector2(210, 245), "대상을 바라본 채 가까이에서 확인을 누르세요.", 19)
		label(Vector2(210, 280), "키보드: 방향키 또는 WASD, 확인: E / Enter", 18)
		label(Vector2(210, 335), "화면을 누르면 닫힙니다.", 18, Color("b8d0c8"))
