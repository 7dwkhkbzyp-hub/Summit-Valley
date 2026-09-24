extends Node3D

# Summit Valley — Godot ski-resort tycoon foundation.
# Original systems and procedural geometry, inspired by the ski-resort-tycoon genre.

const MAP_SIZE := 180.0
const GRID := 70
const START_CASH := 250000.0

var cash := START_CASH
var reputation := 62.0
var guest_count := 85
var ticket_price := 72.0
var paused := false
var snow_depth := 1.0
var day := 1
var time_of_day := 9.0

var camera: Camera3D
var sun: DirectionalLight3D
var terrain_mesh: MeshInstance3D
var piste_root := Node3D.new()
var lift_root := Node3D.new()
var building_root := Node3D.new()
var guest_root := Node3D.new()

var hud: Label
var mode_label: Label
var toast_label: Label

var mode := "SELECT"
var painting := false
var paint_points := PackedVector3Array()
var pistes: Array = []
var lifts: Array = []
var buildings: Array = []
var guests: Array = []
var rng := RandomNumberGenerator.new()
var mobile_bar: HBoxContainer
var mobile_buttons: Array[Button] = []

func _ready() -> void:
    rng.seed = 90210
    piste_root.name = "Pistes"
    lift_root.name = "Lifts"
    building_root.name = "Buildings"
    guest_root.name = "Guests"
    add_child(piste_root)
    add_child(lift_root)
    add_child(building_root)
    add_child(guest_root)
    _environment()
    _terrain()
    _initial_resort()
    _spawn_guests(85)
    _ui()
    _set_mode("SELECT")
    get_viewport().size_changed.connect(_layout_ui)
    _layout_ui()

func _process(delta: float) -> void:
    if paused:
        return
    time_of_day += delta * 0.045
    if time_of_day >= 24.0:
        time_of_day -= 24.0
        day += 1
    snow_depth = clamp(snow_depth + sin(Time.get_ticks_msec() * 0.00007) * 0.00002, 0.45, 2.2)
    cash += (guest_count * ticket_price * 0.00012 + buildings.size() * 0.25) * delta
    reputation = clamp(reputation + (snow_depth - 0.8) * 0.00015 * delta, 0.0, 100.0)
    _animate_guests(delta)
    _update_sun()
    _update_hud()

func terrain_height(x: float, z: float) -> float:
    var a = 42.0 * exp(-((x + 38.0) ** 2 / 1900.0 + (z - 15.0) ** 2 / 2600.0))
    var b = 58.0 * exp(-((x - 30.0) ** 2 / 2100.0 + (z + 22.0) ** 2 / 3300.0))
    var c = 35.0 * exp(-((x + 4.0) ** 2 / 900.0 + (z + 48.0) ** 2 / 1500.0))
    var valley = -18.0 * exp(-(x ** 2 / 1100.0 + (z - 18.0) ** 2 / 1700.0))
    return max(0.0, 6.0 + a + b + c + valley + 7.0 * sin(x * 0.055) * cos(z * 0.045))

func _environment() -> void:
    var world := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#9fc5e8")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#c7dcf0")
    env.ambient_light_energy = 0.75
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world.environment = env
    add_child(world)

    sun = DirectionalLight3D.new()
    sun.light_energy = 1.6
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 260.0
    add_child(sun)

    camera = Camera3D.new()
    camera.position = Vector3(92, 82, 112)
    camera.look_at(Vector3(0, 24, 0), Vector3.UP)
    camera.fov = 52.0
    add_child(camera)

func _terrain() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_material(_mat(Color("#e8eef2"), 0.92))
    for z in range(GRID - 1):
        for x in range(GRID - 1):
            var x0 = -MAP_SIZE * 0.5 + x * MAP_SIZE / float(GRID - 1)
            var x1 = -MAP_SIZE * 0.5 + (x + 1) * MAP_SIZE / float(GRID - 1)
            var z0 = -MAP_SIZE * 0.5 + z * MAP_SIZE / float(GRID - 1)
            var z1 = -MAP_SIZE * 0.5 + (z + 1) * MAP_SIZE / float(GRID - 1)
            var p00 = Vector3(x0, terrain_height(x0,z0), z0)
            var p10 = Vector3(x1, terrain_height(x1,z0), z0)
            var p01 = Vector3(x0, terrain_height(x0,z1), z1)
            var p11 = Vector3(x1, terrain_height(x1,z1), z1)
            st.add_vertex(p00); st.add_vertex(p10); st.add_vertex(p01)
            st.add_vertex(p10); st.add_vertex(p11); st.add_vertex(p01)
    st.generate_normals()
    terrain_mesh = MeshInstance3D.new()
    terrain_mesh.mesh = st.commit()
    terrain_mesh.name = "AlpineMountain"
    add_child(terrain_mesh)

    for i in 260:
        var x = rng.randf_range(-88.0,88.0)
        var z = rng.randf_range(-88.0,88.0)
        var y = terrain_height(x,z)
        if y < 12.0 or y > 54.0:
            continue
        _tree(Vector3(x,y,z))

    for p in [Vector3(-38,42,15),Vector3(30,57,-22),Vector3(0,38,-48)]:
        var cap = _cone(12.0,8.0,Color("#fbfdff"))
        cap.position = p
        add_child(cap)

func _tree(pos: Vector3) -> void:
    var n := Node3D.new()
    n.position = pos
    var trunk = _box(Vector3(0.7,3.0,0.7),Color("#4b3225"))
    trunk.position.y = 1.5
    n.add_child(trunk)
    for j in 3:
        var crown = _cone(3.0 - j * 0.5,4.6,Color("#174436"))
        crown.position.y = 3.0 + j * 2.0
        n.add_child(crown)
    add_child(n)

func _initial_resort() -> void:
    _building("Alpine Grand Hotel",Vector3(-8,terrain_height(-8,24),24),65000.0)
    _building("Mountain Restaurant",Vector3(22,terrain_height(22,-4),-4),32000.0)
    _building("Rental Centre",Vector3(-24,terrain_height(-24,42),42),22000.0)

    _piste([Vector3(-20,terrain_height(-20,-40)+0.35,-40),Vector3(-12,28,-22),Vector3(0,20,4),Vector3(-8,terrain_height(-8,24)+0.35,24)],"BLUE")
    _piste([Vector3(30,terrain_height(30,-42)+0.35,-42),Vector3(24,37,-25),Vector3(18,29,-6),Vector3(22,terrain_height(22,-4)+0.35,-4)],"RED")

    _lift(Vector3(-8,terrain_height(-8,24)+2,24),Vector3(-20,terrain_height(-20,-40)+2,-40),"HIGH-SPEED CHAIR")
    _lift(Vector3(22,terrain_height(22,-4)+2,-4),Vector3(30,terrain_height(30,-42)+2,-42),"GONDOLA")

func _piste(points: Array, difficulty: String) -> void:
    var d = {"points":PackedVector3Array(points),"difficulty":difficulty,"condition":100.0}
    pistes.append(d)
    _render_piste(d)

func _render_piste(d: Dictionary) -> void:
    var pts: PackedVector3Array = d["points"]
    if pts.size() < 2:
        return
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var col = {"GREEN":Color("#54c879"),"BLUE":Color("#49a5ff"),"RED":Color("#ed5757"),"BLACK":Color("#303038")}.get(d["difficulty"],Color.WHITE)
    st.set_material(_mat(col,0.35))
    for i in range(pts.size()-1):
        var a=pts[i]; var b=pts[i+1]
        var side=(b-a).cross(Vector3.UP).normalized()
        var w=3.7
        st.add_vertex(a+side*w); st.add_vertex(b+side*w); st.add_vertex(a-side*w)
        st.add_vertex(a-side*w); st.add_vertex(b+side*w); st.add_vertex(b-side*w)
    var mi:=MeshInstance3D.new()
    mi.mesh=st.commit()
    piste_root.add_child(mi)

func _lift(a: Vector3,b: Vector3,type_name: String) -> void:
    lifts.append({"a":a,"b":b,"type":type_name,"open":true})
    lift_root.add_child(_beam(a+Vector3.UP*9,b+Vector3.UP*9,0.13,Color("#25282c")))
    for i in range(9):
        var t=float(i)/8.0
        var p=a.lerp(b,t)+Vector3.UP*9.0
        var tower=_box(Vector3(0.65,8.0,0.65),Color("#626a70"))
        tower.position=p-Vector3.UP*4.0
        lift_root.add_child(tower)
    for i in range(14):
        var t=(float(i)+0.2)/14.0
        var chair=_box(Vector3(1.8,0.22,1.05),Color("#b9c0c5"))
        chair.position=a.lerp(b,t)+Vector3.UP*8.7
        lift_root.add_child(chair)

func _building(title: String,pos: Vector3,cost: float) -> void:
    buildings.append({"name":title,"pos":pos,"cost":cost})
    var root:=Node3D.new()
    root.position=pos
    var base=_box(Vector3(12,7,9),Color("#956745"))
    base.position.y=3.5
    root.add_child(base)
    var roof=_box(Vector3(13,1.2,10),Color("#3b2c27"))
    roof.position.y=8.0
    root.add_child(roof)
    for x in [-3.8,-1.3,1.3,3.8]:
        var win=_box(Vector3(1.5,1.5,0.18),Color("#ffd77a"))
        win.position=Vector3(x,4.1,-4.6)
        root.add_child(win)
    var label:=Label3D.new()
    label.text=title
    label.font_size=34
    label.outline_size=8
    label.position.y=10.0
    root.add_child(label)
    building_root.add_child(root)

func _spawn_guests(count: int) -> void:
    for i in range(count):
        var n=_skier(i)
        var route=rng.randi_range(0,max(0,pistes.size()-1))
        guests.append({"node":n,"route":route,"t":rng.randf(),"speed":rng.randf_range(0.018,0.034)})
        guest_root.add_child(n)

func _skier(i: int) -> Node3D:
    var n:=Node3D.new()
    var body=_box(Vector3(0.55,1.25,0.42),Color.from_hsv(fmod(i*0.071,1.0),0.72,0.92))
    body.position.y=1.1
    n.add_child(body)
    var head=_sphere(0.42,Color("#f0c7a8"))
    head.position.y=2.05
    n.add_child(head)
    var helmet=_sphere(0.45,Color("#20262c"))
    helmet.scale=Vector3(1,0.65,1)
    helmet.position.y=2.28
    n.add_child(helmet)
    var board=_box(Vector3(0.35,0.08,2.0),Color("#dfe6eb"))
    board.position.y=0.12
    n.add_child(board)
    return n

func _animate_guests(delta: float) -> void:
    if pistes.is_empty():
        return
    for g in guests:
        g["t"]=fmod(g["t"]+g["speed"]*delta,1.0)
        var pts:PackedVector3Array=pistes[g["route"]]["points"]
        var segments=max(1,pts.size()-1)
        var f=g["t"]*segments
        var idx=min(int(f),segments-1)
        var lt=f-idx
        var p=pts[idx].lerp(pts[idx+1],lt)
        g["node"].position=p
        g["node"].rotation.y=atan2(pts[idx+1].x-pts[idx].x,pts[idx+1].z-pts[idx].z)

func _ui() -> void:
    var layer:=CanvasLayer.new()
    add_child(layer)
    var panel:=ColorRect.new()
    panel.color=Color(0.03,0.05,0.07,0.84)
    panel.position=Vector2(18,18)
    panel.size=Vector2(330,150)
    layer.add_child(panel)
    hud=Label.new()
    hud.position=Vector2(34,30)
    hud.add_theme_font_size_override("font_size",20)
    layer.add_child(hud)

    mode_label=Label.new()
    mode_label.position=Vector2(20,670)
    mode_label.add_theme_font_size_override("font_size",22)
    layer.add_child(mode_label)

    toast_label=Label.new()
    toast_label.position=Vector2(410,28)
    toast_label.add_theme_font_size_override("font_size",21)
    layer.add_child(toast_label)

    var help:=Label.new()
    help.text="B Build   P Paint Piste   L Lift   SPACE Pause\nMouse click/drag = construct resort"
    help.position=Vector2(20,585)
    help.add_theme_font_size_override("font_size",16)
    layer.add_child(help)

    mobile_bar = HBoxContainer.new()
    mobile_bar.name = "MobileControls"
    mobile_bar.add_theme_constant_override("separation", 10)
    layer.add_child(mobile_bar)
    for item in [["SELECT","SELECT"],["BUILD","BUILD"],["PISTE","PISTE"],["LIFT","LIFT"],["PAUSE","PAUSE"]]:
        var b := Button.new()
        b.text = item[0]
        b.custom_minimum_size = Vector2(118,58)
        b.add_theme_font_size_override("font_size",18)
        b.pressed.connect(_mobile_action.bind(item[1]))
        mobile_bar.add_child(b)
        mobile_buttons.append(b)

func _mobile_action(action: String) -> void:
    if action == "PAUSE":
        paused = !paused
        return
    _set_mode(action)

func _layout_ui() -> void:
    if not mobile_bar or not hud:
        return
    var size := get_viewport().get_visible_rect().size
    var compact := size.x < 900.0 or size.y < 700.0
    mobile_bar.position = Vector2(max(12.0,(size.x-mobile_bar.size.x)*0.5), max(12.0,size.y-78.0))
    mobile_bar.visible = compact
    mode_label.position = Vector2(20, max(160.0,size.y-125.0))
    var help = get_node_or_null("CanvasLayer/KeyboardHelp")
    if help:
        help.visible = not compact

func _update_hud() -> void:
    if hud:
        var mins=int(fmod(time_of_day*60.0,60.0))
        hud.text="SUMMIT VALLEY\n$%0.0f   Guests %d   Rep %d\nDay %d   Snow %0.2fm   %02d:%02d" % [cash,guest_count,int(reputation),day,snow_depth,int(time_of_day),mins]

func _set_mode(m: String) -> void:
    mode=m
    if mode_label:
        mode_label.text="MODE: "+m+"   |   "+("Drag to paint a piste" if m=="PISTE" else "Click to place a building" if m=="BUILD" else "Click to place a lift" if m=="LIFT" else "Select / inspect")
    if toast_label:
        toast_label.text="SUMMIT VALLEY — Godot rebuild"

func _unhandled_input(event: InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            if mode == "PISTE":
                painting = true
                paint_points.clear()
                var tp = _screen_ground(event.position)
                if tp != Vector3.INF:
                    paint_points.append(tp + Vector3.UP * 0.35)
            elif mode == "BUILD":
                _place_building(event.position)
            elif mode == "LIFT":
                _place_lift(event.position)
        elif painting:
            painting = false
            if paint_points.size() >= 2:
                _piste(paint_points, "BLUE")
                toast_label.text = "NEW BLUE PISTE — terrain carving system is next."
            paint_points.clear()
        return
    if event is InputEventScreenDrag and painting:
        var sp = _screen_ground(event.position)
        if sp != Vector3.INF and (paint_points.is_empty() or paint_points[-1].distance_to(sp) > 2.0):
            paint_points.append(sp + Vector3.UP * 0.35)
        return
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_B:
            _set_mode("BUILD")
            return
        if event.keycode == KEY_P:
            _set_mode("PISTE")
            return
        if event.keycode == KEY_L:
            _set_mode("LIFT")
            return
        if event.keycode == KEY_SPACE:
            paused=!paused
            return
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
        if mode=="PISTE":
            painting=true
            paint_points.clear()
            var p=_screen_ground(event.position)
            if p!=Vector3.INF:
                paint_points.append(p+Vector3.UP*0.35)
        elif mode=="BUILD":
            _place_building(event.position)
        elif mode=="LIFT":
            _place_lift(event.position)
    elif event is InputEventMouseMotion and painting:
        var p=_screen_ground(event.position)
        if p!=Vector3.INF and (paint_points.is_empty() or paint_points[-1].distance_to(p)>2.0):
            paint_points.append(p+Vector3.UP*0.35)
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed and painting:
        painting=false
        if paint_points.size()>=2:
            _piste(paint_points,"BLUE")
            toast_label.text="NEW BLUE PISTE — terrain carving system is next."
        paint_points.clear()

func _place_building(screen: Vector2) -> void:
    var p=_screen_ground(screen)
    if p==Vector3.INF or cash<25000:
        return
    cash-=25000
    _building("New Alpine Lodge",p,25000)

func _place_lift(screen: Vector2) -> void:
    var p=_screen_ground(screen)
    if p==Vector3.INF:
        return
    _lift(p+Vector3.UP*2,p+Vector3(18,20,-36)+Vector3.UP*2,"CHAIRLIFT")

func _screen_ground(pos: Vector2) -> Vector3:
    var origin=camera.project_ray_origin(pos)
    var dir=camera.project_ray_normal(pos)
    if abs(dir.y)<0.001:
        return Vector3.INF
    var t=(8.0-origin.y)/dir.y
    if t<0:
        return Vector3.INF
    var p=origin+dir*t
    p.y=terrain_height(p.x,p.z)
    return p

func _update_sun() -> void:
    var angle=(time_of_day-12.0)*7.5
    sun.rotation_degrees=Vector3(-35,angle,-20)
    sun.light_energy=clamp(1.5-abs(time_of_day-13.0)*0.08,0.18,1.5)

func _mat(color: Color,rough: float)->StandardMaterial3D:
    var m:=StandardMaterial3D.new()
    m.albedo_color=color
    m.roughness=rough
    return m

func _box(size: Vector3,color: Color)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var b:=BoxMesh.new()
    b.size=size
    m.mesh=b
    m.material_override=_mat(color,0.75)
    return m

func _sphere(radius: float,color: Color)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var s:=SphereMesh.new()
    s.radius=radius
    s.height=radius*2.0
    m.mesh=s
    m.material_override=_mat(color,0.65)
    return m

func _cone(radius: float,height: float,color: Color)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var c:=CylinderMesh.new()
    c.top_radius=0.0
    c.bottom_radius=radius
    c.height=height
    m.mesh=c
    m.material_override=_mat(color,0.9)
    return m

func _beam(a: Vector3,b: Vector3,radius: float,color: Color)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var c:=CylinderMesh.new()
    c.top_radius=radius
    c.bottom_radius=radius
    c.height=a.distance_to(b)
    m.mesh=c
    m.material_override=_mat(color,0.45)
    m.position=(a+b)*0.5
    m.look_at(b,Vector3.UP)
    m.rotate_object_local(Vector3.RIGHT,PI*0.5)
    return m
