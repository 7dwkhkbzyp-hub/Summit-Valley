extends Node3D

# SUMMIT VALLEY — playable mobile ski-resort tycoon
# Designed as a lightweight Godot 4 Web/mobile prototype with real gameplay loops.

const MAP_SIZE := 180.0
const GRID := 56
const START_CASH := 250000.0
const MAX_GUESTS := 240
const PISTE_COLOURS := {
    "GREEN": Color("#43d17b"),
    "BLUE": Color("#3f9cff"),
    "RED": Color("#ef4f4f"),
    "BLACK": Color("#292b30")
}

var cash := START_CASH
var reputation := 62.0
var ticket_price := 72.0
var guest_count := 45
var guest_capacity := 90
var day := 1
var hour := 8.5
var paused := false
var weather := "SUNNY"
var snow_depth := 1.15
var season := 1
var season_days := 28
var game_speed := 1.0
var income_timer := 0.0
var weather_timer := 0.0
var save_key := "summit_valley_tycoon_v3"

var camera: Camera3D
var sun: DirectionalLight3D
var terrain_mesh: MeshInstance3D
var world_env: WorldEnvironment

var piste_root := Node3D.new()
var lift_root := Node3D.new()
var building_root := Node3D.new()
var guest_root := Node3D.new()
var scenery_root := Node3D.new()

var pistes: Array = []
var lifts: Array = []
var buildings: Array = []
var guests: Array = []

var rng := RandomNumberGenerator.new()
var mode := "SELECT"
var painting := false
var paint_points := PackedVector3Array()
var selected_piste := "BLUE"
var camera_target := Vector3(0, 20, 0)
var camera_distance := 135.0
var camera_yaw := 42.0
var camera_pitch := -58.0
var camera_visual_target := Vector3.ZERO
var camera_visual_yaw := 42.0
var camera_visual_pitch := -47.0
var camera_visual_distance := 115.0
var camera_smooth_ready := false
var camera_pan_speed := 0.11
var touch_start := Vector2.ZERO
var last_touch := Vector2.ZERO
var touch_mode := false

var hud: Label
var info: Label
var mode_label: Label
var toast: Label
var controls: HBoxContainer

func _ready() -> void:
    rng.seed = 73191
    add_child(scenery_root)
    add_child(piste_root)
    add_child(lift_root)
    add_child(building_root)
    add_child(guest_root)
    _setup_environment()
    _build_mountain()
    _build_initial_resort()
    _spawn_guests(60)
    _build_ui()
    _set_mode("SELECT")
    _load_game()
    get_viewport().size_changed.connect(_layout_ui)
    _layout_ui()
    _toast("Welcome to Summit Valley — build a resort and keep the mountain busy!")

func _process(delta: float) -> void:
    _update_camera(delta)
    if paused:
        _update_hud()
        return
    var dt := delta * game_speed
    hour += dt * 0.055
    if hour >= 24.0:
        hour -= 24.0
        day += 1
        if day > season_days:
            day = 1
            season += 1
    income_timer += dt
    weather_timer += dt
    if income_timer >= 1.0:
        income_timer = 0.0
        _economy_tick()
    if weather_timer >= 18.0:
        weather_timer = 0.0
        _weather_tick()
    _animate_guests(dt)
    _animate_lifts(dt)
    _update_sun()
    _update_hud()

func terrain_height(x: float, z: float) -> float:
    # A more readable ski mountain: broad valley floor, distinct ridges,
    # three summit bowls and stronger fall-line elevation changes.
    var peak_a = 49.0 * exp(-((x + 43.0) ** 2 / 2100.0 + (z - 18.0) ** 2 / 3000.0))
    var peak_b = 62.0 * exp(-((x - 32.0) ** 2 / 2200.0 + (z + 24.0) ** 2 / 3600.0))
    var peak_c = 38.0 * exp(-((x + 2.0) ** 2 / 1250.0 + (z + 57.0) ** 2 / 1800.0))
    var valley = -24.0 * exp(-(x ** 2 / 2100.0 + (z - 20.0) ** 2 / 2600.0))
    var shoulder = 7.0 * exp(-((x + 65.0) ** 2 / 1700.0 + (z + 20.0) ** 2 / 5000.0))
    var gullies = 2.8 * sin(x * 0.075 + z * 0.018) * cos(z * 0.052)
    return max(1.0, 6.0 + peak_a + peak_b + peak_c + valley + shoulder + gullies)

func _setup_environment() -> void:
    world_env = WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#91bde0")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#d9e8f4")
    env.ambient_light_energy = 0.82
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    world_env.environment = env
    add_child(world_env)

    sun = DirectionalLight3D.new()
    sun.light_energy = 1.55
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 220.0
    add_child(sun)

    camera = Camera3D.new()
    camera.fov = 55.0
    add_child(camera)
    _update_camera()

func _build_mountain() -> void:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var mountain_mat:=_mountain_material()
    st.set_material(mountain_mat)

    # Vertex-coloured terrain: lower forest floor, exposed rock bands and
    # high alpine snowfields. This is deliberately more readable than a
    # single white procedural mesh.
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
            _terrain_vertex(st,p00)
            _terrain_vertex(st,p10)
            _terrain_vertex(st,p01)
            _terrain_vertex(st,p10)
            _terrain_vertex(st,p11)
            _terrain_vertex(st,p01)
    st.generate_normals()
    terrain_mesh = MeshInstance3D.new()
    terrain_mesh.name = "DetailedSnowMountain"
    terrain_mesh.mesh = st.commit()
    add_child(terrain_mesh)

    # Forest is concentrated in believable lower/mid-mountain bands.
    for i in range(240):
        var x := rng.randf_range(-84.0,84.0)
        var z := rng.randf_range(-84.0,84.0)
        var y := terrain_height(x,z)
        if y < 9.0 or y > 45.0:
            continue
        # Leave the main pistes and summit bowls more open.
        if abs(x) < 18.0 and z > -42.0 and z < 28.0 and rng.randf() < 0.58:
            continue
        var tree := _detailed_pine()
        tree.position = Vector3(x,y,z)
        var s := rng.randf_range(0.72,1.28)
        tree.scale = Vector3(s,s,rng.randf_range(0.78,1.15)*s)
        tree.rotation.y = rng.randf_range(0,TAU)
        scenery_root.add_child(tree)

    # Distinct high-alpine snowfields and cornices.
    for p in [
        Vector3(-43,terrain_height(-43,18)+1.0,18),
        Vector3(32,terrain_height(32,-24)+1.0,-24),
        Vector3(0,terrain_height(0,-57)+1.0,-57)
    ]:
        var cap := _snowfield(16.0)
        cap.position=p
        scenery_root.add_child(cap)

    # Rock outcrops and cliff chunks make the fall line much easier to read.
    var rock_positions=[
        Vector3(-61,terrain_height(-61,5)+0.7,5),
        Vector3(57,terrain_height(57,-8)+0.7,-8),
        Vector3(8,terrain_height(8,-48)+0.7,-48),
        Vector3(-48,terrain_height(-48,-25)+0.7,-25),
        Vector3(46,terrain_height(46,20)+0.7,20)
    ]
    for p in rock_positions:
        var rock:=_rock_cluster()
        rock.position=p
        rock.rotation.y=rng.randf_range(0,TAU)
        rock.scale=Vector3(rng.randf_range(0.8,1.5),rng.randf_range(0.8,1.4),rng.randf_range(0.8,1.5))
        scenery_root.add_child(rock)

    # A few groomed snow shelves beside the main village make the resort
    # footprint read from the overhead management camera.
    for p in [
        Vector3(-8,terrain_height(-8,24)+0.3,24),
        Vector3(20,terrain_height(20,-5)+0.3,-5),
        Vector3(-25,terrain_height(-25,40)+0.3,40)
    ]:
        var apron:=_box(Vector3(18,0.18,12),Color("#e7eef2"))
        apron.position=p
        scenery_root.add_child(apron)

func _terrain_vertex(st:SurfaceTool,p:Vector3)->void:
    var h=p.y
    var hx=terrain_height(p.x+1.5,p.z)-terrain_height(p.x-1.5,p.z)
    var hz=terrain_height(p.x,p.z+1.5)-terrain_height(p.x,p.z-1.5)
    var slope=clamp(sqrt(hx*hx+hz*hz)/12.0,0.0,1.0)
    var base:Color
    if h < 14.0:
        base=Color("#b9c8bd").lerp(Color("#e4ece9"),clamp((h-6.0)/8.0,0.0,1.0))
    elif h < 28.0:
        base=Color("#e8edf0").lerp(Color("#f7fafb"),clamp((h-14.0)/14.0,0.0,1.0))
    elif slope > 0.62 and h < 48.0:
        base=Color("#aab2b5").lerp(Color("#e7ecee"),0.55)
    else:
        base=Color("#f6f9fb")
    st.set_color(base)
    st.add_vertex(p)

func _mountain_material()->StandardMaterial3D:
    var m:=_mat(Color.WHITE,0.96)
    m.vertex_color_use_as_albedo=true
    m.cull_mode=BaseMaterial3D.CULL_BACK
    return m

func _asset_mesh(path:String, scale:Vector3=Vector3.ONE)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var mesh=load(path)
    if mesh is ArrayMesh:
        m.mesh=mesh
        m.scale=scale
    return m

func _detailed_pine()->Node3D:
    var root:=Node3D.new()
    root.add_child(_asset_mesh("res://assets/pine/asset.obj",Vector3(0.72,0.72,0.72)))
    return root

func _snowfield(radius:float)->Node3D:
    var root:=Node3D.new()
    var lower:=_cone(radius,3.0,Color("#ffffff"))
    lower.position.y=0.2
    root.add_child(lower)
    var crest:=_cone(radius*0.62,4.0,Color("#f7fbfd"))
    crest.position.y=1.4
    root.add_child(crest)
    return root

func _rock_cluster()->Node3D:
    var root:=Node3D.new()
    for i in range(4):
        var rock:=_cone(rng.randf_range(1.4,3.8),rng.randf_range(2.5,6.0),Color("#667277"))
        rock.position=Vector3(rng.randf_range(-3.0,3.0),rng.randf_range(0,1.0),rng.randf_range(-2.5,2.5))
        rock.rotation=Vector3(rng.randf_range(-0.2,0.2),rng.randf_range(0,TAU),rng.randf_range(-0.2,0.2))
        root.add_child(rock)
    return root

func _build_initial_resort() -> void:
    _building("ALPINE GRAND HOTEL",Vector3(-8,terrain_height(-8,24),24),65000.0)
    _building("MOUNTAIN RESTAURANT",Vector3(20,terrain_height(20,-5),-5),32000.0)
    _building("RENTAL CENTRE",Vector3(-25,terrain_height(-25,40),40),22000.0)
    _building("SKI SCHOOL",Vector3(8,terrain_height(8,27),27),18000.0)

    _piste([Vector3(-20,terrain_height(-20,-42)+0.4,-42),Vector3(-16,38,-30),Vector3(-7,31,-16),Vector3(1,24,-2),Vector3(-4,terrain_height(-4,14)+0.4,14),Vector3(-8,terrain_height(-8,24)+0.4,24)],"GREEN")
    _piste([Vector3(-28,terrain_height(-28,-48)+0.4,-48),Vector3(-28,43,-31),Vector3(-20,35,-18),Vector3(-5,27,-3),Vector3(8,22,10),Vector3(1,terrain_height(1,16)+0.4,18)],"BLUE")
    _piste([Vector3(31,terrain_height(31,-43)+0.4,-43),Vector3(35,49,-30),Vector3(27,40,-19),Vector3(20,32,-8),Vector3(12,25,3),Vector3(20,terrain_height(20,-5)+0.4,-5)],"RED")
    _piste([Vector3(40,terrain_height(40,-46)+0.4,-46),Vector3(45,55,-28),Vector3(38,46,-12),Vector3(31,38,2),Vector3(25,31,10),Vector3(20,terrain_height(20,-5)+0.4,-5)],"BLACK")

    _lift(Vector3(-8,terrain_height(-8,24)+2.5,24),Vector3(-20,terrain_height(-20,-42)+2.5,-42),"HIGH-SPEED QUAD")
    _lift(Vector3(20,terrain_height(20,-5)+2.5,-5),Vector3(31,terrain_height(31,-43)+2.5,-43),"GONDOLA")
    _lift(Vector3(1,terrain_height(1,16)+2.5,18),Vector3(27,terrain_height(27,-20)+2.5,-20),"DETACHABLE SIX")
    _lift(Vector3(-52,terrain_height(-52,8)+2.5,8),Vector3(-38,terrain_height(-38,-58)+2.5,-58),"CABLE CAR")
    _lift(Vector3(5,terrain_height(5,31)+0.6,31),Vector3(9,terrain_height(9,17)+0.6,17),"MAGIC CARPET")

func _piste(points: Array, difficulty: String) -> void:
    var d = {"points":PackedVector3Array(points),"difficulty":difficulty,"condition":100.0,"open":true,"name":difficulty+" RUN "+str(pistes.size()+1)}
    pistes.append(d)
    _render_piste(d)

func _render_piste(d: Dictionary) -> void:
    var pts: PackedVector3Array = d["points"]
    if pts.size() < 2: return
    var col: Color = PISTE_COLOURS[d["difficulty"]]

    # Groomed piste surface.
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_material(_mat(Color("#eef4f7"),0.88))
    for i in range(pts.size()-1):
        var a=pts[i]; var b=pts[i+1]
        a.y=terrain_height(a.x,a.z)+0.72
        b.y=terrain_height(b.x,b.z)+0.72
        var side=(b-a).cross(Vector3.UP).normalized()
        var w=7.0 if d["difficulty"]=="GREEN" else (6.4 if d["difficulty"]=="BLUE" else (5.7 if d["difficulty"]=="RED" else 5.0))
        st.add_vertex(a+side*w); st.add_vertex(b+side*w); st.add_vertex(a-side*w)
        st.add_vertex(a-side*w); st.add_vertex(b+side*w); st.add_vertex(b-side*w)
    var mi:=MeshInstance3D.new()
    mi.mesh=st.commit()
    piste_root.add_child(mi)

    # Difficulty-coloured boundary ribbons make the runs obvious from above.
    for edge in [-1.0,1.0]:
        var edge_st:=SurfaceTool.new()
        edge_st.begin(Mesh.PRIMITIVE_TRIANGLES)
        edge_st.set_material(_mat(col,0.72))
        for i in range(pts.size()-1):
            var a=pts[i]; var b=pts[i+1]
            a.y=terrain_height(a.x,a.z)+0.76
            b.y=terrain_height(b.x,b.z)+0.76
            var side=(b-a).cross(Vector3.UP).normalized()
            var center_a=a+side*(edge*5.8)
            var center_b=b+side*(edge*5.8)
            var inner_a=a+side*(edge*5.45)
            var inner_b=b+side*(edge*5.45)
            edge_st.add_vertex(inner_a);edge_st.add_vertex(center_a);edge_st.add_vertex(inner_b)
            edge_st.add_vertex(center_a);edge_st.add_vertex(center_b);edge_st.add_vertex(inner_b)
        var edge_mesh:=MeshInstance3D.new()
        edge_mesh.mesh=edge_st.commit()
        piste_root.add_child(edge_mesh)

    for i in range(pts.size()-1):
        var a=pts[i]; var b=pts[i+1]
        var count=max(1,int(a.distance_to(b)/7.0))
        var side=(b-a).cross(Vector3.UP).normalized()
        for j in range(count):
            var t=(float(j)+0.5)/float(count)
            _piste_marker(a.lerp(b,t)+side*6.0,col)
            _piste_marker(a.lerp(b,t)-side*6.0,col)

    var sign:=Label3D.new()
    sign.text=d["name"]
    sign.font_size=24
    sign.outline_size=7
    sign.modulate=col
    sign.position=pts[0]+Vector3.UP*3
    piste_root.add_child(sign)

func _piste_marker(pos:Vector3,col:Color)->void:
    var pole:=_cylinder(0.07,2.5,Color("#f1f4f6"))
    pole.position=pos+Vector3.UP*1.25
    piste_root.add_child(pole)
    var flag:=_box(Vector3(0.7,0.48,0.12),col)
    flag.position=pos+Vector3.UP*2.1
    piste_root.add_child(flag)

func _lift(a:Vector3,b:Vector3,type_name:String)->void:
    if type_name == "MAGIC CARPET":
        _magic_carpet(a,b)
        return

    var is_cable_car := type_name.find("CABLE CAR") >= 0
    var is_gondola := type_name.find("GONDOLA") >= 0
    var is_chair := not is_cable_car and not is_gondola
    var data={
        "a":a,
        "b":b,
        "type":type_name,
        "carriers":[],
        "phase":rng.randf()
    }
    # The two haul-rope tracks are offset perpendicular to the lift line.
    # Every carrier and every rope segment uses this same side vector, so the
    # vehicles visibly sit on the wires instead of floating beside them.
    var horizontal:=Vector3(b.x-a.x,0,b.z-a.z)
    var track_side:=Vector3(-horizontal.z,0,horizontal.x).normalized()
    data["track_side"]=track_side
    data["cable_height"]=9.0 if is_chair else (10.0 if is_gondola else 12.0)
    lifts.append(data)

    var tower_count:=12 if is_cable_car else 10
    for i in range(tower_count):
        var t=float(i)/float(tower_count-1)
        var p=_lift_cable_pos(data,t,0.0)
        var h:=9.0 if is_chair else (10.0 if is_gondola else 12.0)
        var ground_y:=terrain_height(p.x,p.z)
        var tower_top:=ground_y+h
        # Four-legged steel tower rather than a solid box.
        for leg_side in [-1.0,1.0]:
            for leg_depth in [-1.0,1.0]:
                var foot=p+Vector3(leg_side*0.9,0,leg_depth*0.9)
                var head=p+Vector3(leg_side*0.28,h,leg_depth*0.28)
                lift_root.add_child(_beam(foot+Vector3.UP*0.25,head,0.16,Color("#68747b")))
        var cross_len:=5.8 if is_chair else (6.8 if is_gondola else 7.6)
        var cross:=_beam(p-track_side*cross_len*0.5+Vector3.UP*h,p+track_side*cross_len*0.5+Vector3.UP*h,0.30,Color("#4d565d"))
        lift_root.add_child(cross)
        for side_sign in [-1.0,1.0]:
            var sheave_pos=p+track_side*side_sign*2.0+Vector3.UP*h
            for wheel_offset in [-0.55,0.55]:
                var sheave:=_cylinder(0.43 if is_cable_car else 0.37,0.26,Color("#1f2327"))
                sheave.position=sheave_pos+Vector3(0,0,wheel_offset)
                sheave.rotation_degrees.x=90
                lift_root.add_child(sheave)
        var tower_marker:=_box(Vector3(0.9,0.55,0.18),Color("#e7c44c"))
        tower_marker.position=p+Vector3.UP*(h+0.35)
        lift_root.add_child(tower_marker)

    # Each haul rope is one continuous 3D tube. The carrier path below is
    # sampled from the exact same function, so the cars/chairs sit directly
    # on the wire rather than on a chain of visibly separated segments.
    for run in [-1.0,1.0]:
        var cable_points:=PackedVector3Array()
        for i in range(73):
            cable_points.append(_lift_cable_pos(data,float(i)/72.0,run))
        lift_root.add_child(_cable_tube(cable_points,0.15 if is_cable_car else 0.12,Color("#11161a")))

    _lift_station(a,"BOTTOM",type_name)
    _lift_station(b,"TOP",type_name)

    if is_cable_car:
        # Two large aerial-tram cabins, one on each side of the loop.
        for run in [-1.0,1.0]:
            var carrier:=Node3D.new()
            carrier.position=_lift_cable_pos(data,0.5,run)
            carrier.set_meta("lift_t",0.5 if run < 0.0 else 0.0)
            carrier.set_meta("lift_dir",1.0 if run < 0.0 else -1.0)
            carrier.set_meta("lift_speed",0.018)
            carrier.set_meta("lift_run",run)
            _cable_car_vehicle(carrier)
            lift_root.add_child(carrier)
            data["carriers"].append(carrier)
    else:
        var count:=14 if is_chair else 12
        var spacing:=1.0/float(count)
        for run in [-1.0,1.0]:
            for i in range(count):
                var carrier:=Node3D.new()
                var t=(float(i)/float(count)+0.02) if run < 0.0 else (1.0-(float(i)/float(count)+0.02))
                carrier.position=_lift_cable_pos(data,t,run)
                carrier.set_meta("lift_t",t)
                carrier.set_meta("lift_dir",1.0 if run < 0.0 else -1.0)
                carrier.set_meta("lift_speed",0.012 if is_chair else 0.009)
                carrier.set_meta("lift_run",run)
                var hanger_len:=1.55 if is_chair else 1.75
                var hanger:=_beam(Vector3.ZERO,Vector3(0,-hanger_len,0),0.085,Color("#252a2e"))
                carrier.add_child(hanger)

                if is_gondola:
                    var hanger_bar:=_beam(Vector3(-0.8,-1.35,0),Vector3(0.8,-1.35,0),0.065,Color("#252a2e"))
                    carrier.add_child(hanger_bar)
                    var cabin:=_asset_mesh("res://assets/gondola/asset.obj",Vector3(0.9,0.9,0.9))
                    cabin.position.y=-2.35
                    carrier.add_child(cabin)
                    var glass_back:=_box(Vector3(2.5,1.15,0.12),Color("#72b9d7"))
                    glass_back.position=Vector3(0,-2.65,1.11)
                    carrier.add_child(glass_back)
                    var door:=_box(Vector3(0.9,1.35,0.08),Color("#3f5965"))
                    door.position=Vector3(0,-2.6,-1.18)
                    carrier.add_child(door)
                else:
                    var spreader:=_beam(Vector3(0,-1.35,0),Vector3(0,-1.9,0),0.075,Color("#303438"))
                    carrier.add_child(spreader)
                    var seat:=_box(Vector3(2.9,0.26,1.08),Color("#b72e34"))
                    seat.position.y=-2.15
                    carrier.add_child(seat)
                    var back:=_box(Vector3(2.9,1.08,0.20),Color("#8f252b"))
                    back.position=Vector3(0,-1.65,0.38)
                    carrier.add_child(back)
                    for x in [-1.2,1.2]:
                        carrier.add_child(_beam(Vector3(x,-1.9,-0.25),Vector3(x,-2.2,0.15),0.055,Color("#8f252b")))
                    var safety:=_beam(Vector3(-1.18,-1.72,-0.30),Vector3(1.18,-1.72,-0.30),0.06,Color("#d9b64c"))
                    carrier.add_child(safety)
                    var footrest:=_beam(Vector3(-1.05,-2.28,-0.42),Vector3(1.05,-2.28,-0.42),0.065,Color("#303438"))
                    carrier.add_child(footrest)
                lift_root.add_child(carrier)
                data["carriers"].append(carrier)

func _lift_cable_pos(data:Dictionary,t:float,run:float)->Vector3:
    var a:Vector3=data["a"]
    var b:Vector3=data["b"]
    var side:Vector3=data["track_side"]
    var sag:=2.8 if data["type"].find("CABLE CAR") < 0 else 3.6
    var height:float=data["cable_height"]
    return a.lerp(b,clamp(t,0.0,1.0))+side*run*2.0+Vector3.UP*(height-sin(clamp(t,0.0,1.0)*PI)*sag)

func _cable_car_vehicle(carrier:Node3D)->void:
    carrier.add_child(_beam(Vector3.ZERO,Vector3(0,-1.6,0),0.10,Color("#252a2e")))
    var cabin:=_asset_mesh("res://assets/gondola/asset.obj",Vector3(0.95,0.95,0.95))
    cabin.position.y=-2.0
    carrier.add_child(cabin)

func _lift_station(pos:Vector3,side:String,type_name:String)->void:
    var root:=Node3D.new()
    root.position=pos
    var wheel_height:=9.0 if type_name.find("CABLE CAR") < 0 else 12.0
    if type_name.find("GONDOLA") >= 0:
        wheel_height=10.0

    # Full classic terminal: loading platform, machinery housing, roof and bullwheel.
    var platform:=_box(Vector3(16,0.9,9),Color("#59656c"))
    platform.position.y=0.45
    root.add_child(platform)

    var deck:=_box(Vector3(13,0.45,6),Color("#9ba6aa"))
    deck.position=Vector3(0,1.15,0)
    root.add_child(deck)

    var housing:=_box(Vector3(11.5,5.0,7.2),Color("#d8dfe1"))
    housing.position=Vector3(0,3.5,0)
    root.add_child(housing)

    var roof:=_box(Vector3(14.5,1.0,8.5),Color("#303940"))
    roof.position=Vector3(0,6.5,0)
    root.add_child(roof)

    # Glass loading hall.
    var glass_front:=_box(Vector3(9.5,3.0,0.18),Color("#74b7cf"))
    glass_front.position=Vector3(0,3.6,-3.65)
    root.add_child(glass_front)

    # Bullwheel and drive machinery.
    var wheel:=_cylinder(2.45,0.55,Color("#171c20"))
    wheel.position=Vector3(0,wheel_height,0)
    wheel.rotation_degrees.x=90
    root.add_child(wheel)
    var hub:=_cylinder(0.55,0.7,Color("#7f898d"))
    hub.position=Vector3(0,wheel_height,0)
    hub.rotation_degrees.x=90
    root.add_child(hub)

    # Entry gates and queue barriers.
    for x in [-4.0,-1.35,1.35,4.0]:
        var gate:=_beam(Vector3(x,1.15,-3.0),Vector3(x,2.25,-3.0),0.06,Color("#2e3539"))
        root.add_child(gate)
    for x in [-5.5,5.5]:
        var rail:=_beam(Vector3(x,1.0,-4.1),Vector3(x,1.0,2.5),0.08,Color("#d7b54a"))
        root.add_child(rail)

    var sign:=_box(Vector3(5.5,1.3,0.3),Color("#20272c"))
    sign.position=Vector3(0,5.2,-4.05)
    root.add_child(sign)

    for x in [-4.8,4.8]:
        var column:=_beam(Vector3(x,1.0,-3.1),Vector3(x,6.5,-3.1),0.22,Color("#59656c"))
        root.add_child(column)
    var station_sign:=Label3D.new()
    station_sign.text="SUMMIT VALLEY  •  "+side
    station_sign.font_size=14
    station_sign.outline_size=5
    station_sign.position=Vector3(0,7.7,-4.1)
    root.add_child(station_sign)

    var label:=Label3D.new()
    label.text=type_name+" "+side
    label.font_size=20
    label.outline_size=6
    label.position=Vector3(0,9.2,0)
    root.add_child(label)
    lift_root.add_child(root)

func _spawn_guests(count:int)->void:
    for i in range(count):
        _spawn_guest(i)

func _spawn_guest(i:int)->void:
    if pistes.is_empty(): return
    var n:=_skier(i)
    var route:=rng.randi_range(0,pistes.size()-1)
    var g={"node":n,"route":route,"t":rng.randf(),"speed":rng.randf_range(0.015,0.032),"lane":rng.randf_range(-2.8,2.8),"phase":rng.randf_range(0.0,TAU)}
    guests.append(g)
    guest_root.add_child(n)

func _skier(i:int)->Node3D:
    var n:=Node3D.new()
    n.name="Skier_"+str(i)
    n.add_child(_asset_mesh("res://assets/skier/asset.obj",Vector3(1.15,1.15,1.15)))
    return n

func _animate_guests(dt:float)->void:
    if pistes.is_empty(): return
    for g in guests:
        g["t"]=fmod(g["t"]+g["speed"]*dt,1.0)
        var pts:PackedVector3Array=pistes[g["route"]]["points"]
        var seg=max(1,pts.size()-1)
        var f=g["t"]*seg
        var idx=min(int(f),seg-1)
        var lt=f-idx
        var p=pts[idx].lerp(pts[idx+1],lt)
        var tangent=(pts[idx+1]-pts[idx]).normalized()
        var side=tangent.cross(Vector3.UP).normalized()
        p+=side*(g["lane"]+sin(g["t"]*TAU*2.0+g["phase"])*0.65)
        p.y+=0.25
        g["node"].position=p
        g["node"].rotation.y=atan2(tangent.x,tangent.z)
        g["node"].rotation.z=sin(g["t"]*TAU*3.0+g["phase"])*0.12

func _animate_lifts(dt:float)->void:
    for data in lifts:
        if data["type"] == "MAGIC CARPET":
            continue
        for carrier in data["carriers"]:
            var t=float(carrier.get_meta("lift_t"))
            var dir=float(carrier.get_meta("lift_dir"))
            var speed=float(carrier.get_meta("lift_speed"))
            t=fposmod(t+speed*dir*dt,1.0)
            carrier.set_meta("lift_t",t)
            var run=float(carrier.get_meta("lift_run"))
            carrier.position=_lift_cable_pos(data,t,run)
            var tangent:Vector3=(data["b"]-data["a"]).normalized()
            if dir < 0.0:
                tangent=-tangent
            carrier.look_at(carrier.position+tangent,Vector3.UP)

func _economy_tick()->void:
    var open_pistes:=0
    var condition:=0.0
    for p in pistes:
        if p["open"]:
            open_pistes+=1
            condition+=float(p["condition"])
            p["condition"]=clamp(float(p["condition"])-0.018+snow_depth*0.004,35.0,100.0)
    var avg=condition/max(1,open_pistes)
    var weather_factor=1.0 if weather=="SUNNY" else (0.86 if weather=="CLOUDY" else (0.72 if weather=="SNOW" else 0.55))
    var target=int(clamp(guest_capacity*(0.55+reputation/200.0)*weather_factor*(0.55+avg/200.0),10,MAX_GUESTS))
    if guest_count<target and guests.size()<MAX_GUESTS:
        var add=min(3,target-guest_count)
        for i in range(add):
            _spawn_guest(guests.size())
        guest_count+=add
    elif guest_count>target+8 and guests.size()>20:
        var remove=min(2,guest_count-target)
        for i in range(remove):
            var g=guests.pop_back()
            if is_instance_valid(g["node"]): g["node"].queue_free()
        guest_count-=remove

    var ticket_income=guest_count*ticket_price*0.018
    var spending=guest_count*(1.7+buildings.size()*0.12)
    var wages=8.0+buildings.size()*1.7+lifts.size()*4.0
    cash+=ticket_income+spending-wages
    reputation=clamp(reputation+(avg-75.0)*0.001+(open_pistes*0.012)-0.004,0.0,100.0)
    snow_depth=clamp(snow_depth + (0.006 if weather=="SNOW" else -0.0015),0.35,2.5)

func _weather_tick()->void:
    var roll=rng.randf()
    if snow_depth<0.7 and roll<0.5:
        weather="SNOW"
    elif roll<0.25:
        weather="CLOUDY"
    elif roll<0.86:
        weather="SUNNY"
    else:
        weather="SNOW"
    if weather=="SNOW":
        _toast("Fresh snowfall! Pistes are getting faster and the mountain is busy.")
    elif weather=="SUNNY":
        _toast("Bluebird day — guest demand is rising.")

func _build_ui()->void:
    var layer:=CanvasLayer.new()
    layer.name="HUD"
    add_child(layer)

    var top:=ColorRect.new()
    top.color=Color(0.025,0.045,0.065,0.88)
    top.position=Vector2(12,12)
    top.size=Vector2(430,145)
    layer.add_child(top)

    hud=Label.new()
    hud.position=Vector2(28,22)
    hud.add_theme_font_size_override("font_size",19)
    layer.add_child(hud)

    info=Label.new()
    info.position=Vector2(28,170)
    info.add_theme_font_size_override("font_size",16)
    layer.add_child(info)

    mode_label=Label.new()
    mode_label.position=Vector2(18,0)
    mode_label.add_theme_font_size_override("font_size",19)
    layer.add_child(mode_label)

    toast=Label.new()
    toast.position=Vector2(460,24)
    toast.add_theme_font_size_override("font_size",18)
    layer.add_child(toast)

    controls=HBoxContainer.new()
    controls.add_theme_constant_override("separation",7)
    layer.add_child(controls)
    var actions=[["VIEW","SELECT"],["BUILD","BUILD"],["PISTE","PISTE"],["LIFT","LIFT"],["UPGRADE","UPGRADE"],["SAVE","SAVE"],["PAUSE","PAUSE"]]
    for a in actions:
        var b:=Button.new()
        b.text=a[0]
        b.custom_minimum_size=Vector2(104,54)
        b.add_theme_font_size_override("font_size",16)
        b.pressed.connect(_button_action.bind(a[1]))
        controls.add_child(b)

func _button_action(action:String)->void:
    if action=="PAUSE":
        paused=!paused
    elif action=="SAVE":
        _save_game()
    elif action=="UPGRADE":
        _upgrade_resort()
    else:
        _set_mode(action)

func _upgrade_resort()->void:
    var cost=30000.0+buildings.size()*7000.0
    if cash<cost:
        _toast("Need $%0.0f for the next resort upgrade." % cost)
        return
    cash-=cost
    guest_capacity=min(MAX_GUESTS,guest_capacity+25)
    reputation=min(100.0,reputation+3.0)
    _toast("Resort upgraded! Capacity +25 and reputation +3.")

func _set_mode(m:String)->void:
    mode=m
    if mode=="PISTE":
        mode_label.text="PISTE MODE  •  Drag across the mountain to draw a BLUE run"
    elif mode=="BUILD":
        mode_label.text="BUILD MODE  •  Tap the mountain to build a lodge"
    elif mode=="LIFT":
        mode_label.text="LIFT MODE  •  Tap to add a chairlift"
    elif mode=="UPGRADE":
        mode_label.text="UPGRADE MODE"
    else:
        mode_label.text="SUMMIT VALLEY  •  SELECT / VIEW"

func _layout_ui()->void:
    if not controls: return
    var s=get_viewport().get_visible_rect().size
    var compact=s.x<950.0 or s.y<750.0
    controls.position=Vector2(max(8.0,(s.x-controls.size.x)*0.5),max(8.0,s.y-70.0))
    mode_label.position=Vector2(18.0,max(155.0,s.y-110.0))
    if info:
        info.visible=not compact

func _update_hud()->void:
    if not hud:return
    var minute=int(fmod(hour*60.0,60.0))
    hud.text="SUMMIT VALLEY\n$%0.0f   Guests %d/%d   Rep %d\nDay %d   %02d:%02d   %s\nSnow %0.2fm   Pistes %d   Lifts %d" % [cash,guest_count,guest_capacity,int(reputation),day,int(hour),minute,weather,snow_depth,pistes.size(),lifts.size()]
    if info:
        info.text="Ticket $%d   •   Season %d\nBuild: $25k   Upgrade: $%0.0f\nTip: build facilities to increase guest spending." % [int(ticket_price),season,30000.0+buildings.size()*7000.0]

func _toast(t:String)->void:
    if toast:
        toast.text=t

func _unhandled_input(event:InputEvent)->void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode==KEY_B:_set_mode("BUILD")
        elif event.keycode==KEY_P:_set_mode("PISTE")
        elif event.keycode==KEY_L:_set_mode("LIFT")
        elif event.keycode==KEY_SPACE:paused=!paused
        elif event.keycode==KEY_1:game_speed=1.0
        elif event.keycode==KEY_2:game_speed=3.0
        elif event.keycode==KEY_3:game_speed=8.0
        return

    if event is InputEventScreenTouch:
        if event.pressed:
            touch_start=event.position
            last_touch=event.position
            touch_mode=mode=="PISTE"
            if mode=="BUILD":_place_building(event.position)
            elif mode=="LIFT":_place_lift(event.position)
            elif mode=="SELECT":_focus_ground(event.position)
        else:
            if touch_mode and paint_points.size()>=2:
                _piste(paint_points,"BLUE")
                _toast("New BLUE piste opened. Skiers are choosing their own lines.")
            painting=false
            paint_points.clear()
        return

    if event is InputEventScreenDrag:
        if touch_mode:
            painting=true
            var p=_screen_ground(event.position)
            if p!=Vector3.INF and (paint_points.is_empty() or paint_points[-1].distance_to(p)>2.2):
                paint_points.append(p+Vector3.UP*0.4)
        else:
            var diff=event.position-last_touch
            var yaw=deg_to_rad(camera_yaw)
            var right:=Vector3(cos(yaw),0,-sin(yaw))
            var forward:=Vector3(sin(yaw),0,cos(yaw))
            camera_target += (-right*diff.x + forward*diff.y)*camera_pan_speed
            camera_target.x=clamp(camera_target.x,-65.0,65.0)
            camera_target.z=clamp(camera_target.z,-65.0,65.0)
            last_touch=event.position
        return

    if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
        if event.pressed:
            if mode=="PISTE":
                painting=true
                paint_points.clear()
                var p=_screen_ground(event.position)
                if p!=Vector3.INF:paint_points.append(p+Vector3.UP*0.4)
            elif mode=="BUILD":_place_building(event.position)
            elif mode=="LIFT":_place_lift(event.position)
        elif painting:
            painting=false
            if paint_points.size()>=2:_piste(paint_points,"BLUE")
            paint_points.clear()
    elif event is InputEventMouseMotion and painting:
        var p=_screen_ground(event.position)
        if p!=Vector3.INF and (paint_points.is_empty() or paint_points[-1].distance_to(p)>2.2):
            paint_points.append(p+Vector3.UP*0.4)
    elif event is InputEventMouseMotion and not painting and mode=="SELECT":
        var diff=event.relative
        var yaw=deg_to_rad(camera_yaw)
        var right:=Vector3(cos(yaw),0,-sin(yaw))
        var forward:=Vector3(sin(yaw),0,cos(yaw))
        camera_target += (-right*diff.x + forward*diff.y)*0.055
        camera_target.x=clamp(camera_target.x,-65.0,65.0)
        camera_target.z=clamp(camera_target.z,-65.0,65.0)
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_WHEEL_UP:
        camera_distance=clamp(camera_distance-7.0,55.0,160.0)
    elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:
        camera_distance=clamp(camera_distance+7.0,55.0,160.0)

func _focus_ground(pos:Vector2)->void:
    var p=_screen_ground(pos)
    if p!=Vector3.INF:
        camera_target=p


func _screen_ground(pos:Vector2)->Vector3:
    var origin=camera.project_ray_origin(pos)
    var dir=camera.project_ray_normal(pos)
    if abs(dir.y)<0.0001:return Vector3.INF
    var t=(camera_target.y-origin.y)/dir.y
    if t<0:t=0.0
    var p=origin+dir*t
    p.y=terrain_height(p.x,p.z)
    return p

func _update_camera(delta:float=0.016)->void:
    if not camera:return
    # Stable overhead resort view: the player pans the map instead of spinning
    # the whole mountain around, with smooth easing between positions.
    camera_yaw=42.0
    camera_pitch=-58.0
    camera_distance=clamp(camera_distance,110.0,155.0)
    var yaw=deg_to_rad(camera_yaw)
    var pitch=deg_to_rad(camera_pitch)
    var desired_offset=Vector3(cos(pitch)*sin(yaw),-sin(pitch),cos(pitch)*cos(yaw))*camera_distance
    var desired_position=camera_target+desired_offset
    if not camera_smooth_ready:
        camera_visual_target=camera_target
        camera_visual_yaw=yaw
        camera_visual_pitch=pitch
        camera_visual_distance=camera_distance
        camera.position=desired_position
        camera.look_at(camera_target,Vector3.UP)
        camera_smooth_ready=true
        return
    var blend=1.0-exp(-7.5*max(delta,0.001))
    camera_visual_target=camera_visual_target.lerp(camera_target,blend)
    camera_visual_distance=lerp(camera_visual_distance,camera_distance,blend)
    var smooth_offset=Vector3(cos(pitch)*sin(yaw),-sin(pitch),cos(pitch)*cos(yaw))*camera_visual_distance
    camera.position=camera_visual_target+smooth_offset
    camera.look_at(camera_visual_target,Vector3.UP)

func _update_sun()->void:
    var angle=(hour-12.0)*7.5
    sun.rotation_degrees=Vector3(-35,angle,-20)
    sun.light_energy=clamp(1.55-abs(hour-13.0)*0.075,0.2,1.55)

func _place_building(pos:Vector2)->void:
    var p=_screen_ground(pos)
    if p==Vector3.INF or cash<25000:
        _toast("Not enough cash or invalid terrain.")
        return
    cash-=25000
    _building("ALPINE LODGE",p,25000)
    guest_capacity=min(MAX_GUESTS,guest_capacity+18)
    _toast("Alpine Lodge built. Guest capacity +18.")

func _place_lift(pos:Vector2)->void:
    var p=_screen_ground(pos)
    if p==Vector3.INF or cash<45000:
        _toast("A chairlift costs $45,000.")
        return
    cash-=45000
    var end=p+Vector3(20,18,-42)
    end.y=terrain_height(end.x,end.z)+2.5
    _lift(p+Vector3.UP*2.5,end,"CHAIRLIFT")
    guest_capacity=min(MAX_GUESTS,guest_capacity+20)
    _toast("New lift opened. Capacity +20.")

func _building(title:String,pos:Vector3,cost:float)->void:
    buildings.append({"name":title,"pos":pos,"cost":cost})
    var root:=Node3D.new()
    root.position=pos
    var variant:=buildings.size()%3
    root.add_child(_asset_mesh("res://assets/chalet/asset.obj",Vector3(1.0+variant*0.05,1.0+variant*0.03,1.0+variant*0.05)))
    var sign:=Label3D.new()
    sign.text=title
    sign.font_size=24
    sign.outline_size=7
    sign.modulate=Color("#ffffff")
    sign.position=Vector3(0,14.0,0)
    root.add_child(sign)
    building_root.add_child(root)

func _save_game()->void:
    var data={"cash":cash,"reputation":reputation,"guest_capacity":guest_capacity,"ticket_price":ticket_price,"day":day,"season":season,"snow":snow_depth}
    var file=FileAccess.open("user://"+save_key+".json",FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))
        file.close()
        _toast("Game saved.")

func _load_game()->void:
    if not FileAccess.file_exists("user://"+save_key+".json"):return
    var file=FileAccess.open("user://"+save_key+".json",FileAccess.READ)
    var data=JSON.parse_string(file.get_as_text())
    file.close()
    if typeof(data)==TYPE_DICTIONARY:
        cash=float(data.get("cash",cash))
        reputation=float(data.get("reputation",reputation))
        guest_capacity=int(data.get("guest_capacity",guest_capacity))
        ticket_price=float(data.get("ticket_price",ticket_price))
        day=int(data.get("day",day))
        season=int(data.get("season",season))
        snow_depth=float(data.get("snow",snow_depth))

func _pine_mesh()->ArrayMesh:
    var st:=SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var mat:=_mat(Color("#174536"),0.92)
    st.set_material(mat)
    for j in range(3):
        var r=2.7-j*0.65
        var y=1.4+j*2.0
        var h=3.5
        var pts=[Vector3(0,y+h/2,0),Vector3(-r,y-h/2,-r*0.75),Vector3(r,y-h/2,-r*0.75),Vector3(r,y-h/2,r*0.75),Vector3(-r,y-h/2,r*0.75)]
        for k in range(4):
            st.add_vertex(pts[0]);st.add_vertex(pts[k+1]);st.add_vertex(pts[((k+1)%4)+1])
    return st.commit()

func _mat(color:Color,rough:float)->StandardMaterial3D:
    var m:=StandardMaterial3D.new()
    m.albedo_color=color
    m.roughness=rough
    return m

func _box(size:Vector3,color:Color)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var b:=BoxMesh.new()
    b.size=size
    m.mesh=b
    m.material_override=_mat(color,0.72)
    return m

func _sphere(radius:float,color:Color)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var s:=SphereMesh.new()
    s.radius=radius
    s.height=radius*2.0
    m.mesh=s
    m.material_override=_mat(color,0.65)
    return m

func _cone(radius:float,height:float,color:Color)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var c:=CylinderMesh.new()
    c.top_radius=0.0
    c.bottom_radius=radius
    c.height=height
    m.mesh=c
    m.material_override=_mat(color,0.9)
    return m

func _cylinder(radius:float,height:float,color:Color)->MeshInstance3D:
    var m:=MeshInstance3D.new()
    var c:=CylinderMesh.new()
    c.top_radius=radius
    c.bottom_radius=radius
    c.height=height
    m.mesh=c
    m.material_override=_mat(color,0.5)
    return m

func _beam(a:Vector3,b:Vector3,radius:float,color:Color)->MeshInstance3D:
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
