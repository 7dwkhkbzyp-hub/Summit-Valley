extends Node3D

# SUMMIT VALLEY — playable mobile ski-resort tycoon
const MAP_SIZE := 180.0
const GRID := 56
const START_CASH := 250000.0
const MAX_GUESTS := 180
const PISTE_COLOURS := {"GREEN":Color("#43d17b"),"BLUE":Color("#3f9cff"),"RED":Color("#ef4f4f"),"BLACK":Color("#292b30")}
var cash:=START_CASH
var reputation:=62.0
var ticket_price:=72.0
var guest_count:=45
var guest_capacity:=90
var day:=1
var hour:=8.5
var paused:=false
var weather:="SUNNY"
var snow_depth:=1.15
var season:=1
var season_days:=28
var game_speed:=1.0
var income_timer:=0.0
var weather_timer:=0.0
var save_key:="summit_valley_tycoon_v2"
var camera:Camera3D
var sun:DirectionalLight3D
var terrain_mesh:MeshInstance3D
var world_env:WorldEnvironment
var piste_root:=Node3D.new()
var lift_root:=Node3D.new()
var building_root:=Node3D.new()
var guest_root:=Node3D.new()
var scenery_root:=Node3D.new()
var pistes:Array=[]
var lifts:Array=[]
var buildings:Array=[]
var guests:Array=[]
var rng:=RandomNumberGenerator.new()
var mode:="SELECT"
var painting:=false
var paint_points:=PackedVector3Array()
var camera_target:=Vector3(0,20,0)
var camera_distance:=115.0
var camera_yaw:=42.0
var camera_pitch:=-47.0
var last_touch:=Vector2.ZERO
var touch_mode:=false
var hud:Label
var info:Label
var mode_label:Label
var toast:Label
var controls:HBoxContainer

func _ready()->void:
 rng.seed=73191
 add_child(scenery_root);add_child(piste_root);add_child(lift_root);add_child(building_root);add_child(guest_root)
 _setup_environment();_build_mountain();_build_initial_resort();_spawn_guests(45);_build_ui();_set_mode("SELECT");_load_game()
 get_viewport().size_changed.connect(_layout_ui);_layout_ui();_toast("Welcome to Summit Valley — build a resort and keep the mountain busy!")

func _process(delta:float)->void:
 if paused:_update_hud();return
 var dt:=delta*game_speed
 hour+=dt*.055
 if hour>=24.0:
  hour-=24.0;day+=1
  if day>season_days:day=1;season+=1
 income_timer+=dt;weather_timer+=dt
 if income_timer>=1.0:income_timer=0.0;_economy_tick()
 if weather_timer>=18.0:weather_timer=0.0;_weather_tick()
 _animate_guests(dt);_animate_lifts(dt);_update_sun();_update_hud()

func terrain_height(x:float,z:float)->float:
 var a=43.0*exp(-((x+38.0)**2/1800.0+(z-18.0)**2/2600.0))
 var b=55.0*exp(-((x-30.0)**2/1900.0+(z+22.0)**2/3200.0))
 var c=32.0*exp(-((x+3.0)**2/1000.0+(z+52.0)**2/1500.0))
 var valley=-18.0*exp(-(x**2/1500.0+(z-15.0)**2/1900.0))
 return max(1.5,7.0+a+b+c+valley+5.5*sin(x*.055)*cos(z*.045))

func _setup_environment()->void:
 world_env=WorldEnvironment.new();var env:=Environment.new()
 env.background_mode=Environment.BG_COLOR;env.background_color=Color("#91bde0")
 env.ambient_light_source=Environment.AMBIENT_SOURCE_COLOR;env.ambient_light_color=Color("#d9e8f4");env.ambient_light_energy=.82;env.tonemap_mode=Environment.TONE_MAPPER_FILMIC
 world_env.environment=env;add_child(world_env)
 sun=DirectionalLight3D.new();sun.light_energy=1.55;sun.shadow_enabled=true;sun.directional_shadow_max_distance=220.0;add_child(sun)
 camera=Camera3D.new();camera.fov=55.0;add_child(camera);_update_camera()

func _build_mountain()->void:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(_mat(Color("#eaf1f5"),.94))
 for z in range(GRID-1):
  for x in range(GRID-1):
   var x0=-MAP_SIZE*.5+x*MAP_SIZE/float(GRID-1);var x1=-MAP_SIZE*.5+(x+1)*MAP_SIZE/float(GRID-1)
   var z0=-MAP_SIZE*.5+z*MAP_SIZE/float(GRID-1);var z1=-MAP_SIZE*.5+(z+1)*MAP_SIZE/float(GRID-1)
   var p00=Vector3(x0,terrain_height(x0,z0),z0);var p10=Vector3(x1,terrain_height(x1,z0),z0);var p01=Vector3(x0,terrain_height(x0,z1),z1);var p11=Vector3(x1,terrain_height(x1,z1),z1)
   st.add_vertex(p00);st.add_vertex(p10);st.add_vertex(p01);st.add_vertex(p10);st.add_vertex(p11);st.add_vertex(p01)
 st.generate_normals();terrain_mesh=MeshInstance3D.new();terrain_mesh.mesh=st.commit();terrain_mesh.name="SnowMountain";add_child(terrain_mesh)
 var tree_mesh:=_pine_mesh()
 for i in range(115):
  var x:=rng.randf_range(-82,82);var z:=rng.randf_range(-82,82);var y:=terrain_height(x,z)
  if y<11 or y>48:continue
  var tree:=MeshInstance3D.new();tree.mesh=tree_mesh;tree.material_override=_mat(Color("#173f34"),.9);tree.position=Vector3(x,y,z);var s:=rng.randf_range(.75,1.35);tree.scale=Vector3(s,s,s);scenery_root.add_child(tree)
 for p in [Vector3(-38,49,18),Vector3(30,61,-22),Vector3(0,40,-52)]:
  var cap:=_cone(11,7,Color("#fff"));cap.position=p;scenery_root.add_child(cap)

func _build_initial_resort()->void:
 _building("ALPINE GRAND HOTEL",Vector3(-8,terrain_height(-8,24),24),65000)
 _building("MOUNTAIN RESTAURANT",Vector3(20,terrain_height(20,-5),-5),32000)
 _building("RENTAL CENTRE",Vector3(-25,terrain_height(-25,40),40),22000)
 _building("SKI SCHOOL",Vector3(8,terrain_height(8,27),27),18000)
 _piste([Vector3(-20,terrain_height(-20,-42)+.4,-42),Vector3(-16,38,-30),Vector3(-7,31,-16),Vector3(1,24,-2),Vector3(-4,terrain_height(-4,14)+.4,14),Vector3(-8,terrain_height(-8,24)+.4,24)],"GREEN")
 _piste([Vector3(-28,terrain_height(-28,-48)+.4,-48),Vector3(-28,43,-31),Vector3(-20,35,-18),Vector3(-5,27,-3),Vector3(8,22,10),Vector3(1,terrain_height(1,16)+.4,18)],"BLUE")
 _piste([Vector3(31,terrain_height(31,-43)+.4,-43),Vector3(35,49,-30),Vector3(27,40,-19),Vector3(20,32,-8),Vector3(12,25,3),Vector3(20,terrain_height(20,-5)+.4,-5)],"RED")
 _piste([Vector3(40,terrain_height(40,-46)+.4,-46),Vector3(45,55,-28),Vector3(38,46,-12),Vector3(31,38,2),Vector3(25,31,10),Vector3(20,terrain_height(20,-5)+.4,-5)],"BLACK")
 _lift(Vector3(-8,terrain_height(-8,24)+2.5,24),Vector3(-20,terrain_height(-20,-42)+2.5,-42),"HIGH-SPEED QUAD")
 _lift(Vector3(20,terrain_height(20,-5)+2.5,-5),Vector3(31,terrain_height(31,-43)+2.5,-43),"GONDOLA")
 _lift(Vector3(1,terrain_height(1,16)+2.5,18),Vector3(27,terrain_height(27,-20)+2.5,-20),"DETACHABLE SIX")

func _piste(points:Array,difficulty:String)->void:
 var d={"points":PackedVector3Array(points),"difficulty":difficulty,"condition":100.0,"open":true,"name":difficulty+" RUN "+str(pistes.size()+1)};pistes.append(d);_render_piste(d)

func _render_piste(d:Dictionary)->void:
 var pts:PackedVector3Array=d["points"];if pts.size()<2:return
 var col:Color=PISTE_COLOURS[d["difficulty"]];var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(_mat(col,.24))
 for i in range(pts.size()-1):
  var a=pts[i];var b=pts[i+1];var side=(b-a).cross(Vector3.UP).normalized();var w=4.9 if d["difficulty"]!="BLACK" else 4.2
  st.add_vertex(a+side*w);st.add_vertex(b+side*w);st.add_vertex(a-side*w);st.add_vertex(a-side*w);st.add_vertex(b+side*w);st.add_vertex(b-side*w)
 var mi:=MeshInstance3D.new();mi.mesh=st.commit();piste_root.add_child(mi)
 for i in range(pts.size()-1):
  var a=pts[i];var b=pts[i+1];var count=max(1,int(a.distance_to(b)/6));var side=(b-a).cross(Vector3.UP).normalized()
  for j in range(count):
   var t=(float(j)+.5)/float(count);_piste_marker(a.lerp(b,t)+side*5.7,col);_piste_marker(a.lerp(b,t)-side*5.7,col)
 var sign:=Label3D.new();sign.text=d["name"];sign.font_size=24;sign.outline_size=7;sign.modulate=col;sign.position=pts[0]+Vector3.UP*3;piste_root.add_child(sign)

func _piste_marker(pos:Vector3,col:Color)->void:
 var pole:=_cylinder(.07,2.5,Color("#f1f4f6"));pole.position=pos+Vector3.UP*1.25;piste_root.add_child(pole)
 var flag:=_box(Vector3(.7,.48,.12),col);flag.position=pos+Vector3.UP*2.1;piste_root.add_child(flag)

func _lift(a:Vector3,b:Vector3,type_name:String)->void:
 var data={"a":a,"b":b,"type":type_name,"carriers":[],"phase":rng.randf()};lifts.append(data)
 for i in range(10):
  var t=float(i)/9;var p=a.lerp(b,t);var tower:=_box(Vector3(.72,9,.72),Color("#68747b"));tower.position=p+Vector3.UP*4.5;lift_root.add_child(tower)
  var cross:=_box(Vector3(5.4,.28,.45),Color("#4d565d"));cross.position=p+Vector3.UP*9;lift_root.add_child(cross)
 for run in [-1.0,1.0]:
  for i in range(18):
   var t0=float(i)/18;var t1=float(i+1)/18;var p0=a.lerp(b,t0)+Vector3(run*2,9-sin(t0*PI)*2.8,0);var p1=a.lerp(b,t1)+Vector3(run*2,9-sin(t1*PI)*2.8,0);lift_root.add_child(_beam(p0,p1,.09,Color("#20252a")))
 _lift_station(a,"BOTTOM",type_name);_lift_station(b,"TOP",type_name)
 var count:=14 if type_name.find("GONDOLA")<0 else 10
 for i in range(count):
  var carrier:=Node3D.new();var t=float(i)/float(count);carrier.position=a.lerp(b,t)+Vector3.UP*(8.7-sin(t*PI)*2.8);carrier.set_meta("lift_t",t);carrier.set_meta("lift_speed",.012 if type_name.find("GONDOLA")<0 else .009)
  if type_name.find("GONDOLA")>=0:
   var cabin:=_box(Vector3(2.8,1.9,2.15),Color("#e3e8ea"));cabin.position.y=-2.8;carrier.add_child(cabin)
   var glass:=_box(Vector3(2.45,1.05,.12),Color("#72b9d7"));glass.position=Vector3(0,-2.8,-1.1);carrier.add_child(glass)
  else:
   var seat:=_box(Vector3(2.6,.22,1),Color("#b72e34"));seat.position.y=-2.15;carrier.add_child(seat)
   var back:=_box(Vector3(2.6,1,.18),Color("#8f252b"));back.position=Vector3(0,-1.65,.35);carrier.add_child(back)
   carrier.add_child(_beam(Vector3(0,-.1,0),Vector3(0,-2,0),.07,Color("#303438")))
  lift_root.add_child(carrier);data["carriers"].append(carrier)

func _lift_station(pos:Vector3,side:String,type_name:String)->void:
 var root:=Node3D.new();root.position=pos;var platform:=_box(Vector3(12,.8,7),Color("#626e75"));platform.position.y=.5;root.add_child(platform)
 var roof:=_box(Vector3(13,.7,8),Color("#313b42"));roof.position.y=8.4;root.add_child(roof)
 var glass:=_box(Vector3(10,4.5,5.8),Color("#8dc9df"));glass.position.y=4.2;root.add_child(glass)
 var wheel:=_cylinder(2,.45,Color("#20252a"));wheel.position=Vector3(0,6.8,0);wheel.rotation_degrees.x=90;root.add_child(wheel)
 var label:=Label3D.new();label.text=type_name+" "+side;label.font_size=20;label.outline_size=6;label.position.y=10;root.add_child(label);lift_root.add_child(root)

func _spawn_guests(count:int)->void:
 for i in range(count):_spawn_guest(i)
func _spawn_guest(i:int)->void:
 if pistes.is_empty():return
 var n:=_skier(i);var route:=rng.randi_range(0,pistes.size()-1);var g={"node":n,"route":route,"t":rng.randf(),"speed":rng.randf_range(.015,.032),"lane":rng.randf_range(-2.8,2.8),"phase":rng.randf_range(0,TAU)};guests.append(g);guest_root.add_child(n)

func _skier(i:int)->Node3D:
 var n:=Node3D.new();var jackets=[Color("#d84b42"),Color("#397bc5"),Color("#e2a52f"),Color("#744db1"),Color("#24a578"),Color("#ed7834")];var jacket=jackets[i%jackets.size()]
 var body:=_box(Vector3(.62,1.2,.48),jacket);body.position.y=1.12;n.add_child(body)
 var head:=_sphere(.39,Color("#efc5a5"));head.position.y=2.02;n.add_child(head)
 var helmet:=_sphere(.44,Color("#20262b"));helmet.scale=Vector3(1,.64,1);helmet.position.y=2.28;n.add_child(helmet)
 var goggles:=_box(Vector3(.43,.13,.1),Color("#73c8dc"));goggles.position=Vector3(0,2.07,-.34);n.add_child(goggles)
 var pants:=_box(Vector3(.68,.72,.5),Color("#252b33"));pants.position.y=.42;n.add_child(pants)
 for s in [-1.0,1.0]:
  var ski:=_box(Vector3(.1,.07,2.15),Color("#f4f6f7"));ski.position=Vector3(s*.22,.1,0);n.add_child(ski)
  var boot:=_box(Vector3(.2,.22,.45),Color("#15191d"));boot.position=Vector3(s*.22,.22,-.18);n.add_child(boot)
  n.add_child(_beam(Vector3(s*.38,1.05,-.05),Vector3(s*.50,.05,-.65),.025,Color("#30363b")))
 n.add_child(_beam(Vector3(-.32,1.55,0),Vector3(-.58,1,-.15),.09,jacket));n.add_child(_beam(Vector3(.32,1.55,0),Vector3(.58,1,-.15),.09,jacket));return n

func _animate_guests(dt:float)->void:
 if pistes.is_empty():return
 for g in guests:
  g["t"]=fmod(g["t"]+g["speed"]*dt,1.0);var pts:PackedVector3Array=pistes[g["route"]]["points"];var seg=max(1,pts.size()-1);var f=g["t"]*seg;var idx=min(int(f),seg-1);var lt=f-idx;var p=pts[idx].lerp(pts[idx+1],lt);var tangent=(pts[idx+1]-pts[idx]).normalized();var side=tangent.cross(Vector3.UP).normalized();p+=side*(g["lane"]+sin(g["t"]*TAU*2+g["phase"])*.65);p.y+=.25;g["node"].position=p;g["node"].rotation.y=atan2(tangent.x,tangent.z);g["node"].rotation.z=sin(g["t"]*TAU*3+g["phase"])*.12

func _animate_lifts(dt:float)->void:
 for data in lifts:
  for carrier in data["carriers"]:
   var t=float(carrier.get_meta("lift_t"));t=fmod(t+float(carrier.get_meta("lift_speed"))*dt,1.0);carrier.set_meta("lift_t",t);carrier.position=data["a"].lerp(data["b"],t)+Vector3.UP*(8.7-sin(t*PI)*2.8)

func _economy_tick()->void:
 var open_pistes:=0;var condition:=0.0
 for p in pistes:
  if p["open"]:open_pistes+=1;condition+=float(p["condition"]);p["condition"]=clamp(float(p["condition"])-.018+snow_depth*.004,35.0,100.0)
 var avg=condition/max(1,open_pistes);var weather_factor=1.0 if weather=="SUNNY" else (.86 if weather=="CLOUDY" else (.72 if weather=="SNOW" else .55));var target=int(clamp(guest_capacity*(.55+reputation/200)*weather_factor*(.55+avg/200),10,MAX_GUESTS))
 if guest_count<target and guests.size()<MAX_GUESTS:
  var add=min(3,target-guest_count)
  for i in range(add):_spawn_guest(guests.size())
  guest_count+=add
 elif guest_count>target+8 and guests.size()>20:
  var remove=min(2,guest_count-target)
  for i in range(remove):var g=guests.pop_back();if is_instance_valid(g["node"]):g["node"].queue_free()
  guest_count-=remove
 cash+=guest_count*ticket_price*.018+guest_count*(1.7+buildings.size()*.12)-(8+buildings.size()*1.7+lifts.size()*4)
 reputation=clamp(reputation+(avg-75)*.001+open_pistes*.012-.004,0,100);snow_depth=clamp(snow_depth+(.006 if weather=="SNOW" else -.0015),.35,2.5)

func _weather_tick()->void:
 var roll=rng.randf()
 if snow_depth<.7 and roll<.5:weather="SNOW"
 elif roll<.25:weather="CLOUDY"
 elif roll<.86:weather="SUNNY"
 else:weather="SNOW"
 if weather=="SNOW":_toast("Fresh snowfall! Pistes are getting faster and the mountain is busy.")
 elif weather=="SUNNY":_toast("Bluebird day — guest demand is rising.")

func _build_ui()->void:
 var layer:=CanvasLayer.new();add_child(layer)
 var top:=ColorRect.new();top.color=Color(0.025,0.045,0.065,.88);top.position=Vector2(12,12);top.size=Vector2(430,145);layer.add_child(top)
 hud=Label.new();hud.position=Vector2(28,22);hud.add_theme_font_size_override("font_size",19);layer.add_child(hud)
 info=Label.new();info.position=Vector2(28,170);info.add_theme_font_size_override("font_size",16);layer.add_child(info)
 mode_label=Label.new();mode_label.position=Vector2(18,0);mode_label.add_theme_font_size_override("font_size",19);layer.add_child(mode_label)
 toast=Label.new();toast.position=Vector2(460,24);toast.add_theme_font_size_override("font_size",18);layer.add_child(toast)
 controls=HBoxContainer.new();controls.add_theme_constant_override("separation",7);layer.add_child(controls)
 for a in [["VIEW","SELECT"],["BUILD","BUILD"],["PISTE","PISTE"],["LIFT","LIFT"],["UPGRADE","UPGRADE"],["SAVE","SAVE"],["PAUSE","PAUSE"]]:
  var b:=Button.new();b.text=a[0];b.custom_minimum_size=Vector2(104,54);b.add_theme_font_size_override("font_size",16);b.pressed.connect(_button_action.bind(a[1]));controls.add_child(b)

func _button_action(action:String)->void:
 if action=="PAUSE":paused=!paused
 elif action=="SAVE":_save_game()
 elif action=="UPGRADE":_upgrade_resort()
 else:_set_mode(action)

func _upgrade_resort()->void:
 var cost=30000.0+buildings.size()*7000.0
 if cash<cost:_toast("Need $%0.0f for the next resort upgrade."%cost);return
 cash-=cost;guest_capacity=min(MAX_GUESTS,guest_capacity+25);reputation=min(100.0,reputation+3);_toast("Resort upgraded! Capacity +25 and reputation +3.")

func _set_mode(m:String)->void:
 mode=m
 if mode=="PISTE":mode_label.text="PISTE MODE • Drag across the mountain to draw a BLUE run"
 elif mode=="BUILD":mode_label.text="BUILD MODE • Tap the mountain to build a lodge"
 elif mode=="LIFT":mode_label.text="LIFT MODE • Tap to add a chairlift"
 else:mode_label.text="SUMMIT VALLEY • SELECT / VIEW"

func _layout_ui()->void:
 if not controls:return
 var s=get_viewport().get_visible_rect().size;controls.position=Vector2(max(8.0,(s.x-controls.size.x)*.5),max(8.0,s.y-70.0));mode_label.position=Vector2(18,max(155.0,s.y-110.0));info.visible=not(s.x<950 or s.y<750)

func _update_hud()->void:
 if not hud:return
 var minute=int(fmod(hour*60,60));hud.text="SUMMIT VALLEY\n$%0.0f   Guests %d/%d   Rep %d\nDay %d   %02d:%02d   %s\nSnow %0.2fm   Pistes %d   Lifts %d"%[cash,guest_count,guest_capacity,int(reputation),day,int(hour),minute,weather,snow_depth,pistes.size(),lifts.size()]
 if info:info.text="Ticket $%d • Season %d\nBuild: $25k • Upgrade: $%0.0f\nTip: build facilities to increase guest spending."%[int(ticket_price),season,30000.0+buildings.size()*7000]

func _toast(t:String)->void:
 if toast:toast.text=t

func _unhandled_input(event:InputEvent)->void:
 if event is InputEventKey and event.pressed and not event.echo:
  if event.keycode==KEY_B:_set_mode("BUILD")
  elif event.keycode==KEY_P:_set_mode("PISTE")
  elif event.keycode==KEY_L:_set_mode("LIFT")
  elif event.keycode==KEY_SPACE:paused=!paused
  elif event.keycode==KEY_1:game_speed=1
  elif event.keycode==KEY_2:game_speed=3
  elif event.keycode==KEY_3:game_speed=8
  return
 if event is InputEventScreenTouch:
  if event.pressed:
   last_touch=event.position;touch_mode=mode=="PISTE"
   if mode=="BUILD":_place_building(event.position)
   elif mode=="LIFT":_place_lift(event.position)
  else:
   if touch_mode and paint_points.size()>=2:_piste(paint_points,"BLUE");_toast("New BLUE piste opened.")
   painting=false;paint_points.clear()
  return
 if event is InputEventScreenDrag:
  if touch_mode:
   painting=true;var p=_screen_ground(event.position)
   if p!=Vector3.INF and (paint_points.is_empty() or paint_points[-1].distance_to(p)>2.2):paint_points.append(p+Vector3.UP*.4)
  else:
   var diff=event.position-last_touch;camera_yaw-=diff.x*.25;camera_pitch=clamp(camera_pitch-diff.y*.12,-72,-28);_update_camera();last_touch=event.position
  return
 if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
  if event.pressed:
   if mode=="PISTE":painting=true;paint_points.clear();var p=_screen_ground(event.position);if p!=Vector3.INF:paint_points.append(p+Vector3.UP*.4)
   elif mode=="BUILD":_place_building(event.position)
   elif mode=="LIFT":_place_lift(event.position)
  elif painting:painting=false;if paint_points.size()>=2:_piste(paint_points,"BLUE");paint_points.clear()
 elif event is InputEventMouseMotion and painting:
  var p=_screen_ground(event.position)
  if p!=Vector3.INF and (paint_points.is_empty() or paint_points[-1].distance_to(p)>2.2):paint_points.append(p+Vector3.UP*.4)
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_WHEEL_UP:camera_distance=clamp(camera_distance-7,55,160);_update_camera()
 elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_WHEEL_DOWN:camera_distance=clamp(camera_distance+7,55,160);_update_camera()

func _screen_ground(pos:Vector2)->Vector3:
 var origin=camera.project_ray_origin(pos);var dir=camera.project_ray_normal(pos)
 if abs(dir.y)<.0001:return Vector3.INF
 var t=(camera_target.y-origin.y)/dir.y;if t<0:t=0
 var p=origin+dir*t;p.y=terrain_height(p.x,p.z);return p

func _update_camera()->void:
 if not camera:return
 var yaw=deg_to_rad(camera_yaw);var pitch=deg_to_rad(camera_pitch);var offset=Vector3(cos(pitch)*sin(yaw),-sin(pitch),cos(pitch)*cos(yaw))*camera_distance
 camera.position=camera_target+offset;camera.look_at(camera_target,Vector3.UP)

func _update_sun()->void:
 var angle=(hour-12)*7.5;sun.rotation_degrees=Vector3(-35,angle,-20);sun.light_energy=clamp(1.55-abs(hour-13)*.075,.2,1.55)

func _place_building(pos:Vector2)->void:
 var p=_screen_ground(pos)
 if p==Vector3.INF or cash<25000:_toast("Not enough cash or invalid terrain.");return
 cash-=25000;_building("ALPINE LODGE",p,25000);guest_capacity=min(MAX_GUESTS,guest_capacity+18);_toast("Alpine Lodge built. Guest capacity +18.")

func _place_lift(pos:Vector2)->void:
 var p=_screen_ground(pos)
 if p==Vector3.INF or cash<45000:_toast("A chairlift costs $45,000.");return
 cash-=45000;var end=p+Vector3(20,18,-42);end.y=terrain_height(end.x,end.z)+2.5;_lift(p+Vector3.UP*2.5,end,"CHAIRLIFT");guest_capacity=min(MAX_GUESTS,guest_capacity+20);_toast("New lift opened. Capacity +20.")

func _building(title:String,pos:Vector3,cost:float)->void:
 buildings.append({"name":title,"pos":pos,"cost":cost});var root:=Node3D.new();root.position=pos
 var base:=_box(Vector3(12,7,9),Color("#8e6245"));base.position.y=3.5;root.add_child(base)
 var roof:=_box(Vector3(13,1.4,10),Color("#352a28"));roof.position.y=8;root.add_child(roof)
 for x in [-3.8,-1.3,1.3,3.8]:
  var win:=_box(Vector3(1.45,1.45,.18),Color("#ffd66e"));win.position=Vector3(x,4,-4.6);root.add_child(win)
 var label:=Label3D.new();label.text=title;label.font_size=26;label.outline_size=7;label.position.y=10;root.add_child(label);building_root.add_child(root)

func _save_game()->void:
 var data={"cash":cash,"reputation":reputation,"guest_capacity":guest_capacity,"ticket_price":ticket_price,"day":day,"season":season,"snow":snow_depth}
 var file=FileAccess.open("user://"+save_key+".json",FileAccess.WRITE)
 if file:file.store_string(JSON.stringify(data));file.close();_toast("Game saved.")

func _load_game()->void:
 if not FileAccess.file_exists("user://"+save_key+".json"):return
 var file=FileAccess.open("user://"+save_key+".json",FileAccess.READ);var data=JSON.parse_string(file.get_as_text());file.close()
 if typeof(data)==TYPE_DICTIONARY:
  cash=float(data.get("cash",cash));reputation=float(data.get("reputation",reputation));guest_capacity=int(data.get("guest_capacity",guest_capacity));ticket_price=float(data.get("ticket_price",ticket_price));day=int(data.get("day",day));season=int(data.get("season",season));snow_depth=float(data.get("snow",snow_depth))

func _pine_mesh()->ArrayMesh:
 var st:=SurfaceTool.new();st.begin(Mesh.PRIMITIVE_TRIANGLES);st.set_material(_mat(Color("#174536"),.92))
 for j in range(3):
  var r=2.7-j*.65;var y=1.4+j*2;var h=3.5;var pts=[Vector3(0,y+h/2,0),Vector3(-r,y-h/2,-r*.75),Vector3(r,y-h/2,-r*.75),Vector3(r,y-h/2,r*.75),Vector3(-r,y-h/2,r*.75)]
  for k in range(4):st.add_vertex(pts[0]);st.add_vertex(pts[k+1]);st.add_vertex(pts[(k+1)%4+1])
 return st.commit()
func _mat(color:Color,rough:float)->StandardMaterial3D:
 var m:=StandardMaterial3D.new();m.albedo_color=color;m.roughness=rough;return m
func _box(size:Vector3,color:Color)->MeshInstance3D:
 var m:=MeshInstance3D.new();var b:=BoxMesh.new();b.size=size;m.mesh=b;m.material_override=_mat(color,.72);return m
func _sphere(radius:float,color:Color)->MeshInstance3D:
 var m:=MeshInstance3D.new();var s:=SphereMesh.new();s.radius=radius;s.height=radius*2;m.mesh=s;m.material_override=_mat(color,.65);return m
func _cone(radius:float,height:float,color:Color)->MeshInstance3D:
 var m:=MeshInstance3D.new();var c:=CylinderMesh.new();c.top_radius=0;c.bottom_radius=radius;c.height=height;m.mesh=c;m.material_override=_mat(color,.9);return m
func _cylinder(radius:float,height:float,color:Color)->MeshInstance3D:
 var m:=MeshInstance3D.new();var c:=CylinderMesh.new();c.top_radius=radius;c.bottom_radius=radius;c.height=height;m.mesh=c;m.material_override=_mat(color,.5);return m
func _beam(a:Vector3,b:Vector3,radius:float,color:Color)->MeshInstance3D:
 var m:=MeshInstance3D.new();var c:=CylinderMesh.new();c.top_radius=radius;c.bottom_radius=radius;c.height=a.distance_to(b);m.mesh=c;m.material_override=_mat(color,.45);m.position=(a+b)*.5;m.look_at(b,Vector3.UP);m.rotate_object_local(Vector3.RIGHT,PI*.5);return m
