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
var font := SystemFont.new()
var fade := 0.0

func _ready() -> void:
	font.font_names = PackedStringArray(["Noto Sans CJK KR", "Malgun Gothic", "Apple SD Gothic Neo", "sans-serif"])

func controls() -> Dictionary:
	var h := get_viewport_rect().size.y
	var c := Vector2(115, h - 110)
	return {"up": Rect2(c + Vector2(-28, -84), Vector2(56, 56)), "down": Rect2(c + Vector2(-28, 28), Vector2(56, 56)), "left": Rect2(c + Vector2(-84, -28), Vector2(56, 56)), "right": Rect2(c + Vector2(28, -28), Vector2(56, 56)), "action": Rect2(get_viewport_rect().size - Vector2(125, 105), Vector2(82, 82)), "save": Rect2(Vector2(get_viewport_rect().size.x - 174, 12), Vector2(75, 34)), "load": Rect2(Vector2(get_viewport_rect().size.x - 92, 12), Vector2(75, 34))}

func active(name: String) -> bool:
	var rect: Rect2 = controls()[name]
	for pos in touches.values():
		if rect.has_point(pos): return true
	return mouse_down and rect.has_point(mouse_pos)

func tap(pos: Vector2) -> void:
	var c := controls()
	if c.save.has_point(pos): save_game(); return
	if c.load.has_point(pos): load_game(); return
	if dialogue != "":
		if choices:
			var s := get_viewport_rect().size
			if Rect2(Vector2(s.x / 2 - 130, s.y - 144), Vector2(125, 42)).has_point(pos): choose(true)
			elif Rect2(Vector2(s.x / 2 + 5, s.y - 144), Vector2(125, 42)).has_point(pos): choose(false)
		elif c.action.has_point(pos): dialogue = ""
	elif c.action.has_point(pos): interact()

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			tap(event.position)
		else: touches.erase(event.index)
	elif event is InputEventScreenDrag: touches[event.index] = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		mouse_down = event.pressed
		mouse_pos = event.position
		if event.pressed: tap(event.position)
	elif event is InputEventMouseMotion: mouse_pos = event.position
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.keycode == KEY_E or event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			if choices: choose(true)
			elif dialogue != "": dialogue = ""
			else: interact()
		elif choices and event.keycode == KEY_2: choose(false)

func _process(delta: float) -> void:
	fade = maxf(0.0, fade - delta * 2.5)
	var d := Vector2(int(active("right") or Input.is_key_pressed(KEY_RIGHT)) - int(active("left") or Input.is_key_pressed(KEY_LEFT)), int(active("down") or Input.is_key_pressed(KEY_DOWN)) - int(active("up") or Input.is_key_pressed(KEY_UP)))
	if d.x != 0 and d.y != 0:
		if absf(facing.x) > 0: d.y = 0
		else: d.x = 0
	moving = false
	if dialogue == "" and d != Vector2.ZERO:
		facing = d
		var next := player + d * SPEED * minf(delta, 0.05)
		if can_move(next): player = next; moving = true
	if moving: walk += delta * 9.0
	else: walk = 0.0
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

func interact() -> void:
	if map_id == "outside":
		if player.distance_to(Vector2(480, 257)) < 67:
			map_id = "inside"; player = Vector2(480, 435); fade = 0.8
		elif player.distance_to(Vector2(700, 340)) < 85:
			inspected = true; dialogue = "[테스트 오브젝트] 조사했습니다."
		elif player.distance_to(Vector2(245, 330)) < 80:
			dialogue = "[테스트 인물] 다시 만났네요." if met else "[테스트 인물] 잠시 이야기할까요?"; choices = not met
		else: dialogue = "가까이 다가가서 상호작용해 보세요."
	else:
		if player.distance_to(Vector2(480, 470)) < 70:
			map_id = "outside"; player = Vector2(480, 285); fade = 0.8
		elif player.distance_to(Vector2(665, 330)) < 85:
			inspected = true; dialogue = "[테스트 오브젝트] 조사했습니다."
		else: dialogue = "출입구나 물건 가까이에서 상호작용하세요."

func choose(yes: bool) -> void:
	choices = false
	met = yes
	dialogue = "[테스트 인물] 이야기를 나눴습니다." if yes else "[테스트 인물] 다음에 이야기해요."

func save_game() -> void:
	var file := FileAccess.open("user://prototype_save.json", FileAccess.WRITE)
	if file == null: dialogue = "저장하지 못했습니다."; choices = false; return
	file.store_string(JSON.stringify({"version": 1, "map": map_id, "x": player.x, "y": player.y, "met": met, "inspected": inspected}))
	dialogue = "저장했습니다."; choices = false

func load_game() -> void:
	if not FileAccess.file_exists("user://prototype_save.json"):
		dialogue = "저장된 데이터가 없습니다."; choices = false; return
	var data = JSON.parse_string(FileAccess.get_file_as_string("user://prototype_save.json"))
	if not data is Dictionary or data.get("version") != 1 or data.get("map") not in ["outside", "inside"] or not data.get("x") is float or not data.get("y") is float:
		dialogue = "저장 데이터를 읽을 수 없습니다."; choices = false; return
	map_id = data.map; player = Vector2(data.x, data.y); met = data.get("met", false); inspected = data.get("inspected", false)
	dialogue = "불러왔습니다."; choices = false; fade = 0.8

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
	if dir == Vector2.UP: draw_rect(Rect2(p + Vector2(9, 3), Vector2(12, 7)), color.darkened(0.2))
	elif dir.x != 0: draw_rect(Rect2(p + Vector2(9 if dir.x < 0 else 18, 6), Vector2(3, 3)), outline)
	else:
		draw_rect(Rect2(p + Vector2(9, 7), Vector2(3, 3)), outline)
		draw_rect(Rect2(p + Vector2(18, 7), Vector2(3, 3)), outline)
	draw_rect(Rect2(p + Vector2(2, 19 + swing * 2), Vector2(5, 13)), outline)
	draw_rect(Rect2(p + Vector2(23, 19 - swing * 2), Vector2(5, 13)), outline)
	draw_rect(Rect2(p + Vector2(7, 34), Vector2(7, 10 + swing * 3)), outline)
	draw_rect(Rect2(p + Vector2(16, 34), Vector2(7, 10 - swing * 3)), outline)

func _draw() -> void:
	var s := get_viewport_rect().size
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
	if fade > 0: draw_rect(Rect2(Vector2.ZERO, s), Color(0, 0, 0, fade))
	var c := controls()
	for key in ["up", "down", "left", "right"]:
		var r: Rect2 = c[key]
		draw_circle(r.get_center(), 27, Color(0.08, 0.13, 0.18, 0.73 if not active(key) else 0.95))
		var v: Vector2 = {"up": Vector2.UP, "down": Vector2.DOWN, "left": Vector2.LEFT, "right": Vector2.RIGHT}[key]
		var side := Vector2(-v.y, v.x); var center := r.get_center()
		draw_colored_polygon(PackedVector2Array([center + v * 11, center - v * 7 + side * 8, center - v * 7 - side * 8]), Color("e4edf0"))
	draw_circle(c.action.get_center(), 41, Color(0.17, 0.34, 0.37, 0.9))
	label(c.action.get_center() + Vector2(-25, 6), "확인", 19)
	for key in ["save", "load"]:
		draw_rect(c[key], Color(0.08, 0.13, 0.18, 0.8))
		label(c[key].position + Vector2(10, 24), "저장" if key == "save" else "불러오기", 15)
	label(Vector2(20, 30), "테스트 맵 · " + ("바깥" if map_id == "outside" else "실내"), 18)
	if dialogue != "":
		draw_rect(Rect2(Vector2(180, s.y - 195), Vector2(s.x - 360, 95)), Color(0.08, 0.11, 0.16, 0.95))
		label(Vector2(200, s.y - 160), dialogue, 17)
		if choices:
			draw_rect(Rect2(Vector2(s.x / 2 - 130, s.y - 144), Vector2(125, 42)), Color("476d72"))
			draw_rect(Rect2(Vector2(s.x / 2 + 5, s.y - 144), Vector2(125, 42)), Color("475665"))
			label(Vector2(s.x / 2 - 112, s.y - 117), "네", 18)
			label(Vector2(s.x / 2 + 23, s.y - 117), "아니요", 18)
