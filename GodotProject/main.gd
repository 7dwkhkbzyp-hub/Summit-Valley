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
var lift_clock := 0.0
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
    _animate_lifts(delta)
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

    # A small network of distinct pistes. Guests can choose different routes and lanes.
    _piste([Vector3(-20,terrain_height(-20,-40)+0.35,-40),Vector3(-16,35,-30),Vector3(-8,30,-17),Vector3(1,24,-5),Vector3(-2,terrain_height(-2,12)+0.35,12),Vector3(-8,terrain_height(-8,24)+0.35,24)],"GREEN")
    _piste([Vector3(-27,terrain_height(-27,-46)+0.35,-46),Vector3(-29,43,-30),Vector3(-20,34,-18),Vector3(-5,25,-2),Vector3(7,21,11),Vector3(0,terrain_height(0,14)+0.35,18)],"BLUE")
    _piste([Vector3(30,terrain_height(30,-42)+0.35,-42),Vector3(35,49,-30),Vector3(27,40,-20),Vector3(20,32,-8),Vector3(12,25,3),Vector3(22,terrain_height(22,-4)+0.35,-4)],"RED")
    _piste([Vector3(39,terrain_height(39,-45)+0.35,-45),Vector3(44,55,-28),Vector3(37,46,-13),Vector3(31,38,1),Vector3(25,31,10),Vector3(22,terrain_height(22,-4)+0.35,-4)],"BLACK")

    _lift(Vector3(-8,terrain_height(-8,24)+3,24),Vector3(-20,terrain_height(-20,-40)+3,-40),"HIGH-SPEED QUAD")
    _lift(Vector3(22,terrain_height(22,-4)+3,-4),Vector3(30,terrain_height(30,-42)+3,-42),"GONDOLA")
    _lift(Vector3(0,terrain_height(0,14)+2,18),Vector3(27,terrain_height(27,-20)+2,-20),"DETACHABLE SIX")


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
    var col = {"GREEN":Color("#55d27c"),"BLUE":Color("#4fa7ff"),"RED":Color("#ef5555"),"BLACK":Color("#25252a")}.get(d["difficulty"],Color.WHITE)
    st.set_material(_mat(col,0.26))
    for i in range(pts.size()-1):
        var a=pts[i]; var b=pts[i+1]
        var side=(b-a).cross(Vector3.UP).normalized()
        var w=4.8 if d["difficulty"] != "BLACK" else 4.1
        st.add_vertex(a+side*w); st.add_vertex(b+side*w); st.add_vertex(a-side*w)
        st.add_vertex(a-side*w); st.add_vertex(b+side*w); st.add_vertex(b-side*w)
    var mi:=MeshInstance3D.new()
    mi.mesh=st.commit()
    piste_root.add_child(mi)

    # Proper piste-side markers: repeated poles with coloured rectangular flags.
    var marker_col = col
    var step := 5.5
    var distance := 0.0
    for i in range(pts.size()-1):
        var a=pts[i]; var b=pts[i+1]
        var length=a.distance_to(b)
        var count=max(1,int(length/step))
        for j in range(count):
            var t=(float(j)+0.5)/float(count)
            var p=a.lerp(b,t)
            var tangent=(b-a).normalized()
            var side=tangent.cross(Vector3.UP).normalized()
            _piste_marker(p + side*5.8, marker_col, side)
            _piste_marker(p - side*5.8, marker_col, -side)
        distance += length

    var sign := Label3D.new()
    sign.text = d["difficulty"] + " PISTE"
    sign.font_size = 28
    sign.outline_size = 7
    sign.modulate = marker_col
    sign.position = pts[0] + Vector3.UP*2.8
    piste_root.add_child(sign)

func _piste_marker(pos: Vector3, col: Color, outward: Vector3) -> void:
    var pole := _cylinder(0.09,2.5,Color("#eef4f6"))
    pole.position = pos + Vector3.UP*1.25
    piste_root.add_child(pole)
    var flag := _box(Vector3(0.62,0.46,0.10),col)
    flag.position = pos + Vector3.UP*2.15 + outward*0.08
    flag.look_at(flag.position + outward, Vector3.UP)
    piste_root.add_child(flag)

func _lift(a: Vector3,b: Vector3,type_name: String) -> void:
    var data={"a":a,"b":b,"type":type_name,"open":true,"carriers":[],"phase":rng.randf_range(0.0,10.0)}
    lifts.append(data)

    # Two parallel cable runs with visible sag between substantial lift towers.
    var cable_col=Color("#25292d")
    var towers:=10
    for i in range(towers):
        var t=float(i)/float(towers-1)
        var p=a.lerp(b,t)
        var tower_h=9.0
        var tower=_box(Vector3(0.75,tower_h,0.75),Color("#68737a"))
        tower.position=p+Vector3.UP*(tower_h*0.5)
        lift_root.add_child(tower)
        var cross=_box(Vector3(5.2,0.32,0.42),Color("#525b61"))
        cross.position=p+Vector3.UP*tower_h
        lift_root.add_child(cross)
        for sx in [-1.0,1.0]:
            var sheave=_cylinder(0.38,0.22,Color("#1f2327"))
            sheave.position=p+Vector3(sx*2.0,tower_h-0.25,0)
            sheave.rotation_degrees.x=90
            lift_root.add_child(sheave)

    for run in [-1.0,1.0]:
        var segments:=18
        for i in range(segments):
            var t0=float(i)/segments
            var t1=float(i+1)/segments
            var p0=a.lerp(b,t0)+Vector3(run*2.0,9.0,0)+Vector3.UP*(-sin(t0*PI)*3.0)
            var p1=a.lerp(b,t1)+Vector3(run*2.0,9.0,0)+Vector3.UP*(-sin(t1*PI)*3.0)
            lift_root.add_child(_beam(p0,p1,0.10,cable_col))

    # Detailed stations with roofs, loading platforms and bullwheels.
    _lift_station(a,"BOTTOM",type_name)
    _lift_station(b,"TOP",type_name)

    var carrier_count=18 if type_name.find("GONDOLA") < 0 else 12
    for i in range(carrier_count):
        var carrier:=Node3D.new()
        carrier.name="Carrier"
        var t=float(i)/float(carrier_count)
        carrier.position=a.lerp(b,t)+Vector3.UP*(8.7-sin(t*PI)*3.0)
        var hanger=_beam(Vector3.ZERO,Vector3.UP*-2.0,0.08,Color("#303438"))
        carrier.add_child(hanger)
        if type_name.find("GONDOLA") >= 0:
            var cabin=_box(Vector3(2.8,1.9,2.2),Color("#dfe7ea"))
            cabin.position.y=-3.0
            carrier.add_child(cabin)
            var glass=_box(Vector3(2.45,1.1,0.12),Color("#8fc6e6"))
            glass.position=Vector3(0,-2.8,-1.12)
            carrier.add_child(glass)
        else:
            var seat=_box(Vector3(2.5,0.20,1.0),Color("#b42d2d"))
            seat.position.y=-2.2
            carrier.add_child(seat)
            var back=_box(Vector3(2.5,1.0,0.18),Color("#8e2525"))
            back.position=Vector3(0,-1.7,0.38)
            carrier.add_child(back)
            for x in [-0.9,0.9]:
                carrier.add_child(_beam(Vector3(x,-2.1,0),Vector3(x,-0.9,0),0.055,Color("#303438")))
        lift_root.add_child(carrier)
        data["carriers"].append(carrier)

func _lift_station(pos: Vector3, side: String, type_name: String) -> void:
    var root:=Node3D.new()
    root.position=pos
    var platform=_box(Vector3(12,0.8,7),Color("#667178"))
    platform.position.y=0.5
    root.add_child(platform)
    var roof=_box(Vector3(13,0.7,8),Color("#354048"))
    roof.position.y=8.5
    root.add_child(roof)
    var glass=_box(Vector3(10,4.5,5.8),Color("#9ccfe5"))
    glass.position.y=4.3
    root.add_child(glass)
    for x in [-5.0,5.0]:
        root.add_child(_beam(Vector3(x,1,0),Vector3(x,8,0),0.18,Color("#30373d")))
    var wheel=_cylinder(2.0,0.5,Color("#252a2e"))
    wheel.position=Vector3(0,7.0,0)
    wheel.rotation_degrees.x=90
    root.add_child(wheel)
    var label:=Label3D.new()
    label.text=type_name + " " + side
    label.font_size=22
    label.outline_size=6
    label.position.y=10.0
    root.add_child(label)
    lift_root.add_child(root)

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
        guests.append({"node":n,"route":route,"t":rng.randf(),"speed":rng.randf_range(0.018,0.036),"lane":rng.randf_range(-2.7,2.7),"phase":rng.randf_range(0.0,TAU)})
        guest_root.add_child(n)

func _skier(i: int) -> Node3D:
    var n:=Node3D.new()
    n.name="Skier_%02d" % i
    var jacket_colors=[Color("#d94b45"),Color("#3178c6"),Color("#e3a52f"),Color("#7b4db4"),Color("#28a878"),Color("#f07b38")]
    var jacket=jacket_colors[i % jacket_colors.size()]
    var body=_box(Vector3(0.62,1.20,0.48),jacket)
    body.name="Body"
    body.position.y=1.15
    n.add_child(body)
    var head=_sphere(0.39,Color("#efc4a2"))
    head.position.y=2.05
    n.add_child(head)
    var helmet=_sphere(0.44,Color("#1e252b"))
    helmet.scale=Vector3(1,0.64,1)
    helmet.position.y=2.30
    n.add_child(helmet)
    var goggles=_box(Vector3(0.42,0.13,0.10),Color("#71c9df"))
    goggles.position=Vector3(0,2.08,-0.34)
    n.add_child(goggles)

    var pants=_box(Vector3(0.68,0.72,0.50),Color("#252b33"))
    pants.position.y=0.42
    n.add_child(pants)

    for side in [-1.0,1.0]:
        var ski=_box(Vector3(0.10,0.07,2.15),Color("#f1f4f5"))
        ski.position=Vector3(side*0.22,0.10,0)
        n.add_child(ski)
        var boot=_box(Vector3(0.20,0.22,0.45),Color("#15191d"))
        boot.position=Vector3(side*0.22,0.22,-0.18)
        n.add_child(boot)
        var pole=_beam(Vector3(side*0.38,1.05,-0.05),Vector3(side*0.48,0.05,-0.65),0.025,Color("#343a40"))
        n.add_child(pole)

    var arm_l=_beam(Vector3(-0.32,1.55,0),Vector3(-0.58,1.0,-0.15),0.10,jacket)
    var arm_r=_beam(Vector3(0.32,1.55,0),Vector3(0.58,1.0,-0.15),0.10,jacket)
    arm_l.name="ArmL"; arm_r.name="ArmR"
    n.add_child(arm_l); n.add_child(arm_r)
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
        var tangent=(pts[idx+1]-pts[idx]).normalized()
        var side=tangent.cross(Vector3.UP).normalized()
        var weave=sin(g["t"]*TAU*2.0+g["phase"])*0.65
        p += side*(g["lane"]+weave)
        p.y += 0.25
        g["node"].position=p
        g["node"].rotation.y=atan2(tangent.x,tangent.z)
        var lean=clamp(g["lane"]*0.12+sin(g["t"]*TAU*3.0+g["phase"])*0.08,-0.35,0.35)
        g["node"].rotation.z=lean
        var body=g["node"].get_node_or_null("Body")
        if body:
            body.rotation.z=sin(Time.get_ticks_msec()*0.006+g["phase"])*0.05
        var al=g["node"].get_node_or_null("ArmL")
        var ar=g["node"].get_node_or_null("ArmR")
        if al: al.rotation.z=sin(Time.get_ticks_msec()*0.008+g["phase"])*0.10
        if ar: ar.rotation.z=-sin(Time.get_ticks_msec()*0.008+g["phase"])*0.10

func _animate_lifts(delta: float) -> void:
    lift_clock += delta
    for data in lifts:
        var carriers:Array=data["carriers"]
        for i in range(carriers.size()):
            var carrier:Node3D=carriers[i]
            var t=fmod(float(i)/float(max(1,carriers.size())) + lift_clock*0.018 + data["phase"]*0.001,1.0)
            var a:Vector3=data["a"]
            var b:Vector3=data["b"]
            carrier.position=a.lerp(b,t)+Vector3.UP*(8.7-sin(t*PI)*3.0)
            carrier.rotation.y=atan2((b-a).x,(b-a).z)

func _ui() -> void:
    var layer:=CanvasLayer.new()
    layer.name="HUD"
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

func _cylinder(radius: float,height: float,color: Color)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var c:=CylinderMesh.new()
    c.top_radius=radius
    c.bottom_radius=radius
    c.height=height
    m.mesh=c
    m.material_override=_mat(color,0.5)
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
