"""Render original inventory icons, no external images or extracted game assets."""
import bpy
from pathlib import Path
from mathutils import Vector
ROOT=Path(__file__).resolve().parents[2]
bpy.ops.wm.open_mainfile(filepath=str(ROOT/'assets/source/mrw_carwash_props.blend'))
for obj in bpy.context.scene.objects: obj.hide_render=True
scene=bpy.context.scene
scene.render.engine='CYCLES';scene.cycles.samples=32;scene.cycles.use_denoising=False
scene.render.resolution_x=512;scene.render.resolution_y=512;scene.render.resolution_percentage=100
scene.render.film_transparent=True;scene.render.image_settings.file_format='PNG';scene.render.image_settings.color_mode='RGBA'
scene.world.color=(.2,.2,.2)
for name,pos,power,size in [('Key',(2,-3,4),350,3),('Fill',(-2,-1,2),180,2),('Rim',(0,3,3),400,2)]:
 light=bpy.data.lights.new(name,'AREA');light.energy=power;light.size=size
 obj=bpy.data.objects.new(name,light);bpy.context.collection.objects.link(obj);obj.location=pos
 obj.rotation_euler=(Vector((0,.3,0))-obj.location).to_track_quat('-Z','Y').to_euler()
camera=bpy.data.cameras.new('Icon');cam=bpy.data.objects.new('Icon',camera);bpy.context.collection.objects.link(cam)
scene.camera=cam;camera.type='ORTHO';camera.ortho_scale=1.05
cam.location=(1.2,-.5,.65);cam.rotation_euler=(Vector((0,.30,-.015))-cam.location).to_track_quat('-Z','Y').to_euler()
gun=bpy.data.objects['mrw_pressure_gun.model'];gun.hide_render=False
scene.render.filepath=str(ROOT/'install/images/mrw_pressure_washer.png')
bpy.ops.render.render(write_still=True)
gun.hide_render=True
# Standalone bottle icon; not an additional streamed object.
def material(name,color):
 mat=bpy.data.materials.new(name);mat.use_nodes=True
 bsdf=mat.node_tree.nodes.get('Principled BSDF');bsdf.inputs['Base Color'].default_value=color;bsdf.inputs['Roughness'].default_value=.3
 return mat
red=material('Bottle red',(.47,.025,.035,1));black=material('Cap black',(.015,.018,.024,1));white=material('Label',(.9,.91,.9,1))
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,0,.05))
bottle=bpy.context.object;bottle.dimensions=(.31,.18,.48);bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
bevel=bottle.modifiers.new('Rounded bottle','BEVEL');bevel.width=.045;bevel.segments=4;bottle.data.materials.append(red)
bpy.ops.mesh.primitive_cylinder_add(vertices=32,radius=.075,depth=.09,location=(0,0,.32));bpy.context.object.data.materials.append(black)
bpy.ops.mesh.primitive_cube_add(size=1,location=(0,-.093,.05));bpy.context.object.dimensions=(.26,.008,.25);bpy.context.object.data.materials.append(white)
for label,height,size in [('MrW',.10,.065),('CAR',.015,.045),('SHAMPOO',-.035,.032)]:
 curve=bpy.data.curves.new(label,'FONT');curve.body=label;curve.size=size;curve.align_x='CENTER';curve.extrude=.0001
 obj=bpy.data.objects.new(label,curve);bpy.context.collection.objects.link(obj);obj.location=(0,-.100,height);obj.rotation_euler.x=1.570796;obj.data.materials.append(black)
camera.ortho_scale=.75;cam.location=(.7,-1,.5);cam.rotation_euler=(Vector((0,0,.06))-cam.location).to_track_quat('-Z','Y').to_euler()
scene.render.filepath=str(ROOT/'install/images/mrw_carwash_soap.png')
bpy.ops.render.render(write_still=True)
