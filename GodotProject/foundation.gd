extends Node3D

# SUMMIT VALLEY — FOUNDATION 01
# World-first prototype: terrain, mountain forms, snow, forest, rocks and
# a fixed isometric management camera. No economy, lifts or guests yet.

const MAP_SIZE := 320.0
const GRID := 96
const TREE_COUNT := 420
const ROCK_COUNT := 90

var camera: Camera3D
var terrain: MeshInstance3D
var terrain_heights: PackedFloat32Array
var rng := RandomNumberGenerator.new()
var target := Vector3(0, 28, 0)
var yaw := 42.0
var pitch := -54.0
var distance := 210.0
var dragging := false
var last_touch := Vector2.ZERO
var status: Label

func _ready() -> void:
    rng.seed = 424242
    _setup_world()
    _build_terrain()
    _scatter_forest()
    _scatter_rocks()
    _build_alpine_backdrop()
    _build_ui()
    _update_camera()

func terrain_height(x: float, z: float) -> float:
    var main_a := 66.0 * exp(-((x + 52.0) ** 2 / 4200.0 + (z + 30.0) ** 2 / 7200.0))
    var main_b := 76.0 * exp(-((x - 32.0) ** 2 / 5200.0 + (z - 42.0) ** 2 / 6800.0))
    var main_c := 54.0 * exp(-((x + 8.0) ** 2 / 2600.0 + (z + 76.0) ** 2 / 3200.0))
    var shoulder := 25.0 * exp(-((x + 104.0) ** 2 / 5000.0 + (z + 8.0) ** 2 / 9000.0))
    var bowl := -25.0 * exp(-(x ** 2 / 5200.0 + (z - 25.0) ** 2 / 4600.0))
    var valley := -16.0 * exp(-(x ** 2 / 11500.0 + (z - 72.0) ** 2 / 5200.0))
    var ridge := 6.0 * sin(x * 0.075 + z * 0.031) * exp(-(x*x + z*z) / 26000.0)
    var gullies := 3.0 * sin(x * 0.14) * cos(z * 0.11)
    return max(2.0, 5.0 + main_a + main_b + main_c + shoulder + bowl + valley + ridge + gullies)

func _setup_world() -> void:
    var env_node := WorldEnvironment.new()
    var env := Environment.new()
    env.background_mode = Environment.BG_COLOR
    env.background_color = Color("#86acd0")
    env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
    env.ambient_light_color = Color("#dceaf4")
    env.ambient_light_energy = 0.82
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env_node.environment = env
    add_child(env_node)

    var sun := DirectionalLight3D.new()
    sun.rotation_degrees = Vector3(-52.0, -32.0, 0.0)
    sun.light_energy = 1.35
    sun.shadow_enabled = true
    sun.directional_shadow_max_distance = 280.0
    add_child(sun)

    camera = Camera3D.new()
    camera.fov = 52.0
    camera.near = 0.5
    camera.far = 650.0
    add_child(camera)

func _build_terrain() -> void:
    terrain_heights.resize(GRID * GRID)
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    st.set_material(_terrain_material())

    for z in range(GRID):
        for x in range(GRID):
            var wx := -MAP_SIZE * 0.5 + float(x) * MAP_SIZE / float(GRID - 1)
            var wz := -MAP_SIZE * 0.5 + float(z) * MAP_SIZE / float(GRID - 1)
            terrain_heights[z * GRID + x] = terrain_height(wx, wz)

    for z in range(GRID - 1):
        for x in range(GRID - 1):
            var p00 := _terrain_point(x, z)
            var p10 := _terrain_point(x + 1, z)
            var p01 := _terrain_point(x, z + 1)
            var p11 := _terrain_point(x + 1, z + 1)
            _terrain_vertex(st, p00)
            _terrain_vertex(st, p10)
            _terrain_vertex(st, p01)
            _terrain_vertex(st, p10)
            _terrain_vertex(st, p11)
            _terrain_vertex(st, p01)

    st.generate_normals()
    terrain = MeshInstance3D.new()
    terrain.name = "EditableMountainTerrain"
    terrain.mesh = st.commit()
    add_child(terrain)

func _terrain_point(x:int, z:int) -> Vector3:
    var wx := -MAP_SIZE * 0.5 + float(x) * MAP_SIZE / float(GRID - 1)
    var wz := -MAP_SIZE * 0.5 + float(z) * MAP_SIZE / float(GRID - 1)
    return Vector3(wx, terrain_heights[z * GRID + x], wz)

func _terrain_vertex(st:SurfaceTool, p:Vector3) -> void:
    var dx := terrain_height(p.x + 2.0, p.z) - terrain_height(p.x - 2.0, p.z)
    var dz := terrain_height(p.x, p.z + 2.0) - terrain_height(p.x, p.z - 2.0)
    var slope := clamp(sqrt(dx * dx + dz * dz) / 15.0, 0.0, 1.0)
    var h := p.y

    var snow := Color("#f5f8fa")
    var blue_shadow := Color("#cbdbe5")
    var rock := Color("#687277")
    var lower := Color("#d7e2df")

    var col := snow
    if h < 17.0:
        col = lower.lerp(snow, clamp((h - 5.0) / 12.0, 0.0, 1.0))
    if slope > 0.58 and h < 58.0:
        col = rock.lerp(snow, 0.48)
    if h > 62.0:
        col = Color("#ffffff")
    if slope > 0.78:
        col = blue_shadow.lerp(col, 0.55)

    st.set_color(col)
    st.add_vertex(p)

func _terrain_material() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.roughness = 0.92
    m.metallic = 0.0
    return m

func _scatter_forest() -> void:
    var tree_mesh := _make_tree_mesh()
    var mat := StandardMaterial3D.new()
    mat.vertex_color_use_as_albedo = true
    mat.roughness = 0.95
    tree_mesh.surface_set_material(0, mat)

    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = tree_mesh
    mm.instance_count = TREE_COUNT

    var forest := MultiMeshInstance3D.new()
    forest.name = "Forest"
    forest.multimesh = mm
    forest.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
    add_child(forest)

    var made := 0
    while made < TREE_COUNT:
        var x := rng.randf_range(-145.0,145.0)
        var z := rng.randf_range(-145.0,145.0)
        var y := terrain_height(x,z)
        if y < 10.0 or y > 52.0:
            continue
        # Keep the central valley and upper bowls open enough for future pistes.
        if abs(x) < 28.0 and z > -70.0 and z < 78.0 and rng.randf() < 0.62:
            continue
        var s := rng.randf_range(0.72,1.35)
        var t := Transform3D(Basis(Vector3.UP, rng.randf_range(0.0, TAU)).scaled(Vector3(s,s,s)), Vector3(x,y,z))
        mm.set_instance_transform(made, t)
        made += 1

func _make_tree_mesh() -> ArrayMesh:
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)

    # Trunk.
    _cone_surface(st, 0.22, 0.12, 2.4, 6, Color("#49382d"), 0.0)
    # Layered foliage gives the forest a fuller silhouette.
    _cone_surface(st, 2.5, 0.0, 4.0, 8, Color("#214b3b"), 1.7)
    _cone_surface(st, 2.05, 0.0, 3.5, 8, Color("#2b5d48"), 3.4)
    _cone_surface(st, 1.45, 0.0, 3.1, 8, Color("#356c52"), 5.0)
    _cone_surface(st, 0.85, 0.0, 2.4, 8, Color("#477d60"), 6.5)

    st.generate_normals()
    return st.commit()

func _cone_surface(st:SurfaceTool, radius:float, top_radius:float, height:float, sides:int, color:Color, y0:float) -> void:
    for i in range(sides):
        var a0 := TAU * float(i) / float(sides)
        var a1 := TAU * float(i + 1) / float(sides)
        var b0 := Vector3(cos(a0)*radius,y0,sin(a0)*radius)
        var b1 := Vector3(cos(a1)*radius,y0,sin(a1)*radius)
        var t0 := Vector3(cos(a0)*top_radius,y0+height,sin(a0)*top_radius)
        var t1 := Vector3(cos(a1)*top_radius,y0+height,sin(a1)*top_radius)
        st.set_color(color)
        st.add_vertex(b0); st.add_vertex(b1); st.add_vertex(t0)
        st.add_vertex(b1); st.add_vertex(t1); st.add_vertex(t0)

func _scatter_rocks() -> void:
    var rock_mesh := SphereMesh.new()
    rock_mesh.radius = 1.0
    rock_mesh.height = 1.8
    rock_mesh.radial_segments = 7
    rock_mesh.rings = 4
    var rock_mat := StandardMaterial3D.new()
    rock_mat.albedo_color = Color("#687176")
    rock_mat.roughness = 1.0
    rock_mesh.material = rock_mat

    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = rock_mesh
    mm.instance_count = ROCK_COUNT

    var rocks := MultiMeshInstance3D.new()
    rocks.name = "AlpineRockFields"
    rocks.multimesh = mm
    add_child(rocks)

    for i in range(ROCK_COUNT):
        var x := rng.randf_range(-150.0,150.0)
        var z := rng.randf_range(-150.0,150.0)
        var y := terrain_height(x,z)
        var s := Vector3(rng.randf_range(1.0,3.8),rng.randf_range(0.7,2.6),rng.randf_range(1.0,3.8))
        var basis := Basis(Vector3.UP,rng.randf_range(0.0,TAU)).scaled(s)
        mm.set_instance_transform(i, Transform3D(basis,Vector3(x,y+0.7*s.y,z)))

func _build_alpine_backdrop() -> void:
    # Distant peaks make the playable mountain read as part of a larger alpine range.
    for i in range(12):
        var a := TAU * float(i) / 12.0
        var r := 275.0 + rng.randf_range(-18.0,18.0)
        var p := Vector3(cos(a)*r, -2.0, sin(a)*r)
        var peak := CylinderMesh.new()
        peak.top_radius = 0.0
        peak.bottom_radius = rng.randf_range(30.0,52.0)
        peak.height = rng.randf_range(55.0,95.0)
        peak.radial_segments = 7
        var mat := StandardMaterial3D.new()
        mat.albedo_color = Color("#d6e0e8")
        mat.roughness = 1.0
        peak.material = mat
        var node := MeshInstance3D.new()
        node.mesh = peak
        node.position = p
        node.rotation.y = a
        add_child(node)

func _build_ui() -> void:
    var layer := CanvasLayer.new()
    add_child(layer)

    var panel := ColorRect.new()
    panel.position = Vector2(16,16)
    panel.size = Vector2(360,78)
    panel.color = Color(0.035,0.07,0.11,0.82)
    layer.add_child(panel)

    var title := Label.new()
    title.text = "SUMMIT VALLEY  •  WORLD FOUNDATION 01"
    title.position = Vector2(28,24)
    title.add_theme_font_size_override("font_size",18)
    layer.add_child(title)

    status = Label.new()
    status.text = "Mountain • snow • forest • rocks"
    status.position = Vector2(28,52)
    status.add_theme_font_size_override("font_size",14)
    layer.add_child(status)

func _update_camera() -> void:
    if camera == null:
        return
    var rot := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))
    var offset := rot * Vector3(0,0,distance)
    camera.position = target + offset
    camera.look_at(target,Vector3.UP)

func _unhandled_input(event:InputEvent) -> void:
    if event is InputEventScreenTouch:
        if event.pressed:
            dragging = true
            last_touch = event.position
        else:
            dragging = false
    elif event is InputEventScreenDrag and dragging:
        var d := event.relative
        target.x -= d.x * distance * 0.0009
        target.z -= d.y * distance * 0.0009
        target.x = clamp(target.x,-120.0,120.0)
        target.z = clamp(target.z,-120.0,120.0)
        _update_camera()
    elif event is InputEventMouseButton:
        if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
            distance = max(85.0,distance-15.0)
            _update_camera()
        elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
            distance = min(310.0,distance+15.0)
            _update_camera()
    elif event is InputEventMouseMotion and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
        target.x -= event.relative.x * distance * 0.0009
        target.z -= event.relative.y * distance * 0.0009
        _update_camera()
