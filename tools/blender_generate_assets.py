# Summit Valley — Blender asset generator
# Run inside Blender 4.x:
#   blender --background --python tools/blender_generate_assets.py
#
# Exports production-ready GLBs into assets/generated/.
# The game is designed around these named assets so they can replace
# procedural placeholders without changing the tycoon systems.

import bpy, math, os
from mathutils import Vector

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "assets", "generated")
os.makedirs(OUT, exist_ok=True)

def reset():
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)
    for datablocks in (bpy.data.meshes, bpy.data.curves, bpy.data.materials, bpy.data.cameras, bpy.data.lights):
        pass

def material(name, color, roughness=.7, metallic=0):
    m=bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.diffuse_color=(*color,1)
    m.use_nodes=True
    bs=m.node_tree.nodes.get("Principled BSDF")
    bs.inputs["Base Color"].default_value=(*color,1)
    bs.inputs["Roughness"].default_value=roughness
    bs.inputs["Metallic"].default_value=metallic
    return m

WOOD=material("Alpine Timber",(0.30,.13,.045),.72)
WOOD_DARK=material("Dark Timber",(0.12,.055,.025),.75)
STONE=material("Granite Stone",(.25,.27,.29),.92)
ROOF=material("Slate Roof",(.045,.055,.065),.65)
SNOW=material("Fresh Snow",(.92,.97,1),.92)
GLASS=material("Blue Glass",(.04,.25,.34),.12,.15)
WARM=material("Warm Interior",(.95,.32,.035),.25)
STEEL=material("Lift Steel",(.30,.34,.38),.3,.8)
RED=material("Chair Red",(.72,.035,.025),.38,.2)
BLUE=material("Gondola Blue",(.025,.20,.42),.25,.35)
GREEN=material("Pine Green",(.018,.12,.05),.9)
PINE_SNOW=material("Pine Snow",(.65,.73,.78),.9)
SKIN=material("Skin",(.65,.36,.20),.82)
DARK=material("Clothing Dark",(.02,.025,.035),.8)

def apply_mat(obj, mat):
    if obj.data and hasattr(obj.data,"materials"):
        obj.data.materials.append(mat)

def cube(name, loc, scale, mat, bevel=.04):
    bpy.ops.mesh.primitive_cube_add(location=loc)
    o=bpy.context.object; o.name=name; o.scale=(scale[0]/2,scale[1]/2,scale[2]/2)
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    if bevel:
        mod=o.modifiers.new("soft edges","BEVEL"); mod.width=bevel; mod.segments=2
    apply_mat(o,mat); return o

def cyl(name, loc, radius, depth, mat, vertices=16):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=radius,depth=depth,location=loc)
    o=bpy.context.object;o.name=name;apply_mat(o,mat);return o

def uv(name, loc, scale, mat):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20, ring_count=12, location=loc)
    o=bpy.context.object;o.name=name;o.scale=scale;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);apply_mat(o,mat);return o

def cone(name, loc, radius, depth, mat, vertices=16):
    bpy.ops.mesh.primitive_cone_add(vertices=vertices,radius1=radius,radius2=radius*.08,depth=depth,location=loc)
    o=bpy.context.object;o.name=name;apply_mat(o,mat);return o

def roof_half(name,x,angle,w,d,y):
    o=cube(name,(x,y,0),(w,.55,d),ROOF,.03);o.rotation_euler[1]=angle;return o

def export(name):
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    path=os.path.join(OUT,name+".glb")
    bpy.ops.export_scene.gltf(filepath=path,export_format="GLB",use_selection=True,export_materials="EXPORT",export_apply=True)
    reset()


def alpine_mountain():
    """Build the mountain as one intentional sculpted landform.
    Run this in Blender 4.x; it exports summit_valley_mountain.glb.
    The playable mountain is made from broad peaks, bowls, gullies,
    ridgelines and a flattened village apron rather than primitives."""
    # 64 x 64 sculpt grid
    N=64
    size_x,size_z=190.0,155.0
    verts=[]; faces=[]
    def gauss(x,z,cx,cz,sx,sz,h):
        return h*math.exp(-(((x-cx)/sx)**2+((z-cz)/sz)**2))
    def terrain(x,z):
        y=1.8
        # Three dominant alpine masses + rear summit.
        y+=gauss(x,z,-48,10,42,48,34)
        y+=gauss(x,z,5,20,38,45,49)
        y+=gauss(x,z,46,8,31,39,35)
        y+=gauss(x,z,-8,61,31,25,39)
        # Main valley and side bowls.
        y-=gauss(x,z,0,-42,43,24,16)
        y-=gauss(x,z,31,-25,25,19,9)
        # Natural large-scale ridges.
        y+=3.2*math.sin(x*.055+z*.032)+1.8*math.cos(z*.085-x*.035)
        # Ski bowls / gullies cut deliberately into the mountain.
        for cx,cz,sx,sz,depth in [
            (-33,3,10,31,5.5),(2,2,11,36,6.5),
            (32,4,9,28,5.0),(-4,34,14,17,4.0)
        ]:
            y-=depth*math.exp(-(((x-cx)/sx)**2+((z-cz)/sz)**2))
        # Village terrace at the bottom.
        apron=math.exp(-((x/70)**2+((z+55)/17)**2))
        y=y*(1-apron)+max(y,2.6)*apron
        return max(.4,y)

    for j in range(N+1):
        z=-size_z/2+size_z*j/N
        for i in range(N+1):
            x=-size_x/2+size_x*i/N
            verts.append((x,terrain(x,z),z))
    for j in range(N):
        for i in range(N):
            q=j*(N+1)+i
            faces += [(q,q+1,q+N+1),(q+1,q+N+2,q+N+1)]

    mesh=bpy.data.meshes.new("Summit Valley Sculpted Mountain Mesh")
    mesh.from_pydata(verts,[],faces); mesh.update()
    mountain=bpy.data.objects.new("SUMMIT VALLEY — MAIN MOUNTAIN",mesh)
    bpy.context.collection.objects.link(mountain)
    apply_mat(mountain,SNOW)

    # Smooth base shading, then add a controlled subdivision.
    for p in mesh.polygons: p.use_smooth=True
    sub=mountain.modifiers.new("Alpine surface refinement","SUBSURF")
    sub.subdivision_type="SIMPLE"; sub.levels=1; sub.render_levels=1

    # Snow/rock material slots. A geometry-nodes style separation is avoided
    # so the GLB remains lightweight and reliable in PlayCanvas.
    mountain.data.materials.append(STONE)
    mountain.data.materials.append(SNOW)

    # Assign exposed rock to steep lower/mid faces.
    for poly in mesh.polygons:
        nx=poly.normal.x; ny=poly.normal.y; nz=poly.normal.z
        steep=1-abs(ny)
        cy=poly.center.y
        if steep>.38 and cy<30:
            poly.material_index=1

    # Distinct snow ridges/cornices as low-profile sculpted strips.
    def ridge(name,points,width=.9,lift=.25):
        me=bpy.data.meshes.new(name+" Mesh")
        vs=[];fs=[]
        for k,(x,z) in enumerate(points):
            dx=points[min(k+1,len(points)-1)][0]-points[max(0,k-1)][0]
            dz=points[min(k+1,len(points)-1)][1]-points[max(0,k-1)][1]
            ll=max(.001,math.hypot(dx,dz)); nx=-dz/ll; nz=dx/ll
            y=terrain(x,z)+lift
            vs += [(x+nx*width,y,z+nz*width),(x-nx*width,y-.08,z-nz*width)]
        for k in range(len(points)-1):
            q=k*2;fs.append((q,q+1,q+2));fs.append((q+1,q+3,q+2))
        me.from_pydata(vs,[],fs);me.update()
        ob=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(ob);apply_mat(ob,SNOW)
        return ob
    ridge("Upper wind lip A",[(-78,30),(-54,37),(-27,42),(0,47),(25,43)],1.5,.5)
    ridge("Upper wind lip B",[(5,44),(28,39),(54,31),(72,22)],1.25,.45)
    ridge("Cornice Ridge",[(-45,25),(-27,31),(-8,37),(14,35),(35,29)],1.0,.34)

    # Large faceted cliff faces are separate so the mountain silhouette remains readable.
    def cliff(cx,cz,w,d,h):
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(cx,terrain(cx,cz)-h*.15,cz))
        o=bpy.context.object;o.name="Exposed granite cliff";o.scale=(w,h,d)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);apply_mat(o,STONE)
        for p in o.data.polygons:p.use_smooth=False
    for p in [(-49,24,8,5,5),(-25,31,9,5,7),(7,38,10,6,8),(27,28,8,5,6),(48,20,8,5,5)]:
        cliff(*p)

    # Snow-capped summit domes, deliberately asymmetric.
    for cx,cz,sx,sz in [(-48,10,23,18),(5,20,27,22),(46,8,20,17),(-8,61,21,14)]:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(cx,terrain(cx,cz)+2,cz))
        cap=bpy.context.object;cap.name="Snow capped alpine summit"
        cap.scale=(sx,5.5,sz)
        bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);apply_mat(cap,SNOW)

    # Export the complete mountain selection.
    bpy.ops.object.select_all(action="DESELECT")
    for o in bpy.context.scene.objects: o.select_set(True)
    bpy.context.view_layer.objects.active=mountain
    path=os.path.join(OUT,"summit_valley_mountain.glb")
    bpy.ops.export_scene.gltf(filepath=path,export_format="GLB",use_selection=True,export_materials="EXPORT",export_apply=True)
    print("EXPORTED",path)
    reset()


def chalet():
    cube("Stone foundation",(0,.35,0),(9,.7,7),STONE)
    cube("Timber walls",(0,2.05,0),(8.4,3.4,6.4),WOOD)
    for x in (-3.5,3.5): cube("Heavy corner beam",(x,2.1,3.25),(.24,3.4,.22),WOOD_DARK)
    for x in (-2.6,0,2.6):
        cube("Window surround",(x,2.35,3.28),(1.45,1.3,.20),WOOD_DARK)
        cube("Window",(x,2.35,3.40),(1.16,1.02,.08),GLASS,0)
        cube("Window cross",(x,2.35,3.47),(.06,1.02,.05),WOOD_DARK,0)
        cube("Window cross",(x,2.35,3.47),(1.16,.06,.05),WOOD_DARK,0)
    cube("Door",(0,1.15,3.40),(1.15,2.05,.10),DARK,0)
    roof_half("Roof left",-2.05,-.48,5.1,7.5,4.35)
    roof_half("Roof right",2.05,.48,5.1,7.5,4.35)
    for x,a in [(-2.05,-.48),(2.05,.48)]:
        o=cube("Snow roof",(x,4.68,0),(5.2,.18,7.6),SNOW,.02);o.rotation_euler[1]=a
    for x in (-2.1,0,2.1):
        cube("Balcony",(x,3.05,3.85),(1.8,.16,1.1),WOOD_DARK)
        cube("Balcony rail",(x,3.42,4.38),(1.8,.48,.08),STEEL)
    cyl("Chimney",(2.5,5.1,0),.3,1.4,STONE)
    cube("Terrace",(0,.75,4.25),(5.5,.16,1.5),WOOD_DARK)
    export("alpine_chalet")

def hotel():
    cube("Hotel foundation",(0,.45,0),(13,.9,9),STONE)
    cube("Hotel body",(0,2.65,0),(12.4,4.3,8.4),WOOD)
    for x in (-5.1,5.1): cube("Corner beam",(x,2.6,4.25),(.28,4.3,.25),WOOD_DARK)
    for y in (1.8,3.2):
        for x in (-4.5,-1.5,1.5,4.5):
            cube("Window",(x,y,4.32),(1.35,1.0,.08),GLASS,0)
            cube("Window frame",(x,y,4.39),(1.42,.07,.05),WOOD_DARK,0)
    cube("Main entrance",(0,1.3,4.4),(1.7,2.5,.12),DARK,0)
    roof_half("Hotel roof left",-3.15,-.48,7.2,9.5,5.35)
    roof_half("Hotel roof right",3.15,.48,7.2,9.5,5.35)
    for x,a in [(-3.15,-.48),(3.15,.48)]:
        o=cube("Heavy roof snow",(x,5.72,0),(7.3,.20,9.6),SNOW,.02);o.rotation_euler[1]=a
    for x in (-4,-2,0,2,4):
        cube("Balcony",(x,4.0,4.65),(1.7,.16,1.0),WOOD_DARK)
        cube("Balcony rail",(x,4.35,5.15),(1.75,.5,.07),STEEL)
    cyl("Hotel chimney",(3.8,6.0,0),.35,1.5,STONE)
    cube("Grand terrace",(0,.9,5.0),(9,.18,1.7),WOOD_DARK)
    export("alpine_hotel")

def pine():
    cyl("Trunk",(0,1,0),.22,2,WOOD_DARK)
    for y,r,h in ((2.0,1.8,3.0),(3.25,1.45,2.7),(4.4,1.05,2.3),(5.35,.68,1.8)):
        cone("Fir crown",(0,y,0),r,h,GREEN)
    for y,r,h in ((3.0,1.3,1.0),(4.25,1.0,.9),(5.2,.65,.7)):
        cone("Snow load",(0,y+.25,0),r,h,PINE_SNOW)
    export("alpine_pine")

def skier():
    uv("Head",(0,1.58,0),(.29,.29,.29),SKIN)
    uv("Helmet",(0,1.82,0),(.34,.20,.34),DARK)
    cube("Padded jacket",(0,1.10,0),(.55,.78,.40),BLUE)
    cube("Left leg",(-.16,.55,0),(.19,.55,.19),DARK)
    cube("Right leg",(.16,.55,0),(.19,.55,.19),DARK)
    cube("Left boot",(-.16,.24,.12),(.24,.20,.38),DARK)
    cube("Right boot",(.16,.24,.12),(.24,.20,.38),DARK)
    for x in (-.34,.34):
        a=cyl("Arm",(x,1.2,.08),.08,.65,BLUE);a.rotation_euler[1]=(-.5 if x<0 else .5)
        cyl("Pole",(x*1.2,.68,.22),.025,1.1,STEEL)
    cube("Left ski",(-.18,.12,.12),(.06,.04,1.7),SNOW,0)
    cube("Right ski",(.18,.12,.12),(.06,.04,1.7),SNOW,0)
    export("skier")

def chairlift():
    cyl("Tower",(0,2.5,0),.12,5,STEEL)
    cube("Crossarm",(0,5,0),(3.2,.18,.28),STEEL)
    for x in (-1.25,1.25): cyl("Sheave",(x,4.72,0),.27,.20,STEEL)
    cyl("Hanger",(0,4.35,0),.05,1.5,STEEL)
    cube("Seat",(0,3.25,0),(1.4,.16,.55),RED)
    cube("Backrest",(0,3.62,0),(1.4,.70,.12),RED)
    export("chairlift")

def gondola():
    cyl("Tower",(0,2.5,0),.12,5,STEEL)
    cube("Crossarm",(0,5,0),(3.4,.18,.3),STEEL)
    for x in (-1.3,1.3): cyl("Sheave",(x,4.75,0),.28,.2,STEEL)
    cyl("Hanger",(0,4.2,0),.05,1.5,STEEL)
    cube("Cabin",(0,2.9,0),(1.5,1.15,1.0),BLUE)
    cube("Glass",(0,3.0,.53),(1.15,.7,.06),GLASS,0)
    export("gondola")

def snowmaker():
    cyl("Base",(0,.85,0),.18,1.7,STEEL)
    cyl("Mast",(0,1.7,0),.10,.9,STEEL)
    cube("Fan housing",(0,2.2,.22),(.42,.42,.42),STEEL)
    cyl("Fan",(0,2.25,.48),.48,.16,STEEL)
    cyl("Water line",(0,1.0,.12),.05,1.2,STEEL)
    uv("Snow nozzle",(0,2.28,.67),(.10,.10,.10),SNOW)
    export("snowmaker")

reset()
for fn in (alpine_mountain,chalet,hotel,pine,skier,chairlift,gondola,snowmaker):
    fn()
print("Summit Valley assets exported to",OUT)
