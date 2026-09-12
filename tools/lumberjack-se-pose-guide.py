"""Disposable 3D motion guides for image editing, not a production character.

Fixed +Y heading, orthographic SE projection, analytic two-bone leg placement.
No source artwork is read or transformed by this script.
"""
import bpy
import math
from mathutils import Vector
from pathlib import Path

OUT = Path(__file__).resolve().parents[1] / 'docs/art/animations/lumberjack-without-log-SE-v2/guides'
OUT.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

def mat(name, color):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value = (*color, 1)
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value = .85
    return m

olive=mat('tunic',(.30,.31,.16)); skin=mat('skin',(.65,.39,.22))
leather=mat('leather',(.23,.115,.052)); cap=mat('cap',(.42,.19,.055))
right=mat('RIGHT_near_leg',(.26,.19,.12)); left=mat('LEFT_far_leg',(.18,.13,.09))
white=mat('cuffs',(.75,.68,.52)); metal=mat('axe',(.23,.25,.26))

moving=[]
def ell(name,p,s,m):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=20,ring_count=12,location=p)
    o=bpy.context.object; o.name=name; o.scale=s; o.data.materials.append(m)
    for face in o.data.polygons: face.use_smooth=True
    moving.append(o)
    return o

def bone(name,a,b,r,m,r2=None):
    a,b=Vector(a),Vector(b); d=b-a
    bpy.ops.mesh.primitive_cone_add(vertices=20,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)*.5)
    o=bpy.context.object; o.name=name; o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(m)
    moving.append(o)
    return o

def cube(name,p,s,m,bevel=.03):
    bpy.ops.mesh.primitive_cube_add(size=1,location=p)
    o=bpy.context.object;o.name=name;o.scale=s
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    o.data.materials.append(m)
    mod=o.modifiers.new('rounded','BEVEL');mod.width=bevel;mod.segments=3
    o.modifiers.new('normals','WEIGHTED_NORMAL');moving.append(o)
    return o

def knee(hip, ankle):
    h,a=Vector(hip),Vector(ankle);d=a-h;distance=d.length;L=.455
    forward=Vector((0,1,0));perp=(forward-d.normalized()*forward.dot(d.normalized())).normalized()
    return (h+a)*.5+perp*math.sqrt(max(.0001,L*L-distance*distance/4))

def pose(p):
    for o in moving: bpy.data.objects.remove(o,do_unlink=True)
    moving.clear()
    z=[.97,.95,.995,1.005,.97,.95,.995,1.005][round(p*8)%8]
    ell('torso',(0,0,z+.39),(.34,.21,.37),olive)
    ell('shoulders',(0,0,z+.60),(.40,.19,.15),olive)
    ell('pelvis',(0,0,z),(.26,.19,.16),olive)
    bone('belt',(-.245,0,z+.02),(.245,0,z+.02),.075,leather)
    # A short guide apron leaves both hip attachments visible.
    cube('short_apron',(0,.205,z-.08),(.36,.028,.24),leather,.015)
    ell('head',(0,.005,z+.91),(.19,.175,.24),skin)
    ell('beard',(0,.115,z+.79),(.17,.105,.12),leather)
    ell('nose',(0,.191,z+.94),(.052,.059,.058),skin)
    ell('hat',(0,-.02,z+1.10),(.212,.19,.15),cap)
    ell('hat_roll',(0,-.01,z+1.045),(.222,.205,.065),cap)
    for side,phase,material in [('R',p,right),('L',(p+.5)%1,left)]:
        x=.19 if side=='R' else -.19
        if phase<.5:
            y=.32*(1-4*phase); lift=0
        else:
            q=(phase-.5)*2;y=-.32+.64*q;lift=.19*math.sin(math.pi*q)
        hip=(x,0,z);ankle=(x,y,.13+lift);k=knee(hip,ankle)
        bone(side+'_thigh',hip,k,.135,material,.108)
        ell(side+'_knee',k,(.107,.107,.107),material)
        bone(side+'_shin',k,ankle,.100,material,.079)
        cube(side+'_boot',(x,y+.082,.078+lift),(.21,.34,.15),leather,.06)
        bone(side+'_cuff',(x,y,.15+lift),(x,y,.30+lift),.116,leather)
        # Arms swing opposite their ipsilateral leg.
        swing=-.14*math.cos(2*math.pi*phase)
        shoulder=(x*1.95,0,z+.60);elbow=(x*2.33,swing*.55,z+.31);hand=(x*2.47,swing,z+.07)
        bone(side+'_sleeve',shoulder,elbow,.13,olive,.105)
        ell(side+'_cuff_arm',elbow,(.112,.11,.065),white)
        bone(side+'_forearm',elbow,hand,.084,skin,.065)
        ell(side+'_hand',hand,(.085,.065,.105),skin)
        if side=='R':
            tip=(hand[0]+.10,hand[1]+.20,hand[2]-.37)
            bone('axe_handle',(hand[0]-.05,hand[1]-.08,hand[2]+.10),tip,.032,cap)
            cube('axe_head',tip,(.08,.22,.15),metal,.015)

scene=bpy.context.scene
scene.render.engine='BLENDER_EEVEE'
scene.render.resolution_x=768;scene.render.resolution_y=1024;scene.render.resolution_percentage=100
scene.render.image_settings.file_format='PNG'
scene.world.color=(.8,.8,.8)
bpy.ops.object.camera_add(location=(5.5,8,9.0))
camera=bpy.context.object;target=Vector((0,0,1.03))
camera.rotation_euler=(target-camera.location).to_track_quat('-Z','Y').to_euler()
camera.data.type='ORTHO';camera.data.ortho_scale=2.55;scene.camera=camera
bpy.ops.object.light_add(type='AREA',location=(-3,4,8));bpy.context.object.data.energy=650;bpy.context.object.data.shape='DISK';bpy.context.object.data.size=5
scene.view_settings.view_transform='Standard'
scene.render.film_transparent=False
scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(1,1,1,1);scene.world.node_tree.nodes['Background'].inputs[1].default_value=.8
for i in range(8):
    pose(i/8)
    scene.render.filepath=str(OUT / f'{i:02d}.png')
    bpy.ops.render.render(write_still=True)
pose(0)
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'motion-guide.blend'))
print('Rendered eight disposable pose guides')
