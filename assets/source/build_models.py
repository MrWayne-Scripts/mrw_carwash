"""Original MRW pressure-washer models. Run in Blender 4.3 with Sollumz 2.9.
No models or textures are extracted from GTA or third-party resources.
Paths to tool dependencies can be supplied with MRW_ASSET_TOOLS.
"""
import math
import os
import struct
import sys
from pathlib import Path

TOOLS = Path(os.environ.get('MRW_ASSET_TOOLS', '/workspace/.carwash-tools'))
sys.path[:0] = [str(TOOLS), str(TOOLS / 'python')]
import bpy
import addon_utils
from mathutils import Vector
addon_utils.enable('Sollumz', default_set=True)
from Sollumz.tools.drawablehelper import convert_obj_to_drawable
from Sollumz.tools.meshhelper import mesh_add_missing_color_attrs, mesh_add_missing_uv_maps
from Sollumz.tools.blenderhelper import create_empty_object
from Sollumz.tools.boundhelper import create_bound_box, apply_flag_preset
from Sollumz.ybn.collision_materials import create_collision_material_from_index
from Sollumz.sollumz_properties import SollumType, LODLevel
from Sollumz.ydr.shader_materials import create_shader
from Sollumz.ydr.ydrexport import export_ydr
from Sollumz.iecontext import ExportSettings, ExportContext, export_context_scope
from szio.gta5 import (AssetFormat, AssetVersion, AssetTarget, Archetype,
    ArchetypeType, ArchetypeAssetType, AssetMapTypes, save_asset)

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / 'assets' / 'export'
PREVIEW = ROOT / 'assets' / 'previews'
OUT.mkdir(parents=True, exist_ok=True)
PREVIEW.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action='SELECT')
bpy.ops.object.delete(use_global=False)

PALETTE = {
    'graphite': (26, 33, 41), 'rubber': (14, 17, 21),
    'blue': (10, 116, 193), 'blue_light': (29, 174, 224),
    'steel': (156, 171, 180), 'white': (230, 238, 242),
    'brass': (187, 139, 54), 'screen': (9, 41, 49),
    'led': (84, 237, 192), 'red': (214, 52, 46),
}
materials = {}

def dds_solid(path, rgb):
    # BC1/DXT1 with a complete mip chain; all texels are authored here.
    values = [124, 0xA1007, 8, 8, 32, 0, 4] + [0]*11
    values += [32, 4, struct.unpack('<I', b'DXT1')[0], 0, 0, 0, 0, 0]
    values += [0x401008, 0, 0, 0, 0]
    color = ((rgb[0]>>3)<<11) | ((rgb[1]>>2)<<5) | (rgb[2]>>3)
    block = struct.pack('<HHI', color, color, 0)
    payload = b''.join(block*(((size+3)//4)**2) for size in [8,4,2,1])
    path.write_bytes(b'DDS ' + struct.pack('<31I', *values) + payload)

for name, color in PALETTE.items():
    tex_path = OUT / ('mrw_' + name + '.dds')
    dds_solid(tex_path, color)
    image = bpy.data.images.load(str(tex_path), check_existing=False)
    image.name = 'mrw_' + name
    image.pack()
    mat = create_shader('default.sps')
    mat.name = 'MRW_' + name
    node = mat.node_tree.nodes['DiffuseSampler']
    node.image = image
    node.texture_properties.embedded = True
    materials[name] = mat

parts = []
def finish(obj, name, material, bevel=0):
    obj.name = name
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    if bevel:
        modifier = obj.modifiers.new('Manufactured edges', 'BEVEL')
        modifier.width, modifier.segments = bevel, 2
        bpy.ops.object.modifier_apply(modifier=modifier.name)
    obj.data.materials.append(materials[material])
    parts.append(obj)
    return obj

def box(name, loc, size, material, bevel=0.01, rotation=None):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    obj = bpy.context.object
    obj.dimensions = size
    if rotation: obj.rotation_euler = rotation
    return finish(obj, name, material, bevel)

def cylinder(name, loc, radius, depth, material, axis='Z', vertices=20):
    bpy.ops.mesh.primitive_cylinder_add(vertices=vertices, radius=radius, depth=depth, location=loc)
    obj = bpy.context.object
    if axis == 'Y': obj.rotation_euler.x = math.pi/2
    elif axis == 'X': obj.rotation_euler.y = math.pi/2
    return finish(obj, name, material, min(0.003, radius*0.12))

def torus(name, loc, major, minor, material, axis='Z'):
    bpy.ops.mesh.primitive_torus_add(major_segments=24, minor_segments=6, location=loc,
        major_radius=major, minor_radius=minor)
    obj = bpy.context.object
    if axis == 'Y': obj.rotation_euler.x = math.pi/2
    elif axis == 'X': obj.rotation_euler.y = math.pi/2
    return finish(obj, name, material)

def tube(name, points, radius, material):
    curve = bpy.data.curves.new(name, 'CURVE')
    curve.dimensions = '3D'
    curve.bevel_depth, curve.bevel_resolution = radius, 1
    curve.resolution_u = 6
    spline = curve.splines.new('BEZIER')
    spline.bezier_points.add(len(points)-1)
    for bp, position in zip(spline.bezier_points, points):
        bp.co = position
        bp.handle_left_type = bp.handle_right_type = 'AUTO'
    obj = bpy.data.objects.new(name, curve)
    bpy.context.collection.objects.link(obj)
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object, name, material)

def text(label, loc, size, material, rotation=(math.pi/2,0,0)):
    curve = bpy.data.curves.new('Lettering '+label, 'FONT')
    curve.body, curve.size, curve.align_x = label, size, 'CENTER'
    curve.extrude, curve.bevel_depth = 0.0004, 0
    curve.resolution_u = 3
    obj = bpy.data.objects.new('Lettering '+label, curve)
    bpy.context.collection.objects.link(obj)
    obj.location, obj.rotation_euler = loc, rotation
    bpy.ops.object.select_all(action='DESELECT')
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.convert(target='MESH')
    return finish(bpy.context.object, 'Lettering '+label, material)

models, specs = {}, {}
def complete(name, collision=None):
    bpy.ops.object.select_all(action='DESELECT')
    for obj in parts: obj.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.convert(target='MESH')
    bpy.ops.object.join()
    obj = bpy.context.object
    obj.name = name
    bpy.context.scene.cursor.location = (0,0,0)
    bpy.ops.object.origin_set(type='ORIGIN_CURSOR')
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    tri = obj.modifiers.new('Game triangles','TRIANGULATE')
    bpy.ops.object.modifier_apply(modifier=tri.name)
    mesh_add_missing_uv_maps(obj.data)
    mesh_add_missing_color_attrs(obj.data)
    for attr in obj.data.color_attributes:
        if attr.domain == 'CORNER':
            for datum in attr.data: datum.color = (1,1,1,1)
    # Uniform material maps need no authored unwrap but valid UVs are provided.
    for uv in obj.data.uv_layers:
        for datum in uv.data: datum.uv = (0.5,0.5)
    drawable = convert_obj_to_drawable(obj)
    drawable.name = name
    drawable.drawable_properties.lod_dist_high = 60 if collision else 30
    drawable.drawable_properties.lod_dist_med = 90 if collision else 45
    drawable.drawable_properties.lod_dist_low = 120 if collision else 60
    # A simplified low LOD keeps distant stands inexpensive.
    duplicate = obj.copy()
    duplicate.data = obj.data.copy()
    bpy.context.collection.objects.link(duplicate)
    bpy.context.view_layer.objects.active = duplicate
    dec = duplicate.modifiers.new('Low LOD','DECIMATE')
    dec.ratio = 0.35
    bpy.ops.object.modifier_apply(modifier=dec.name)
    low_mesh = duplicate.data
    obj.sz_lods.get_lod(LODLevel.MEDIUM).mesh = low_mesh
    obj.sz_lods.get_lod(LODLevel.LOW).mesh = low_mesh
    bpy.data.objects.remove(duplicate, do_unlink=True)
    obj.sz_lods.active_lod_level = LODLevel.HIGH
    if collision:
        bounds = create_empty_object(SollumType.BOUND_COMPOSITE)
        bounds.name = name + '.collision'
        bounds.parent = drawable
        bound = create_bound_box()
        bound.parent = bounds
        bound.data.materials.append(create_collision_material_from_index(0))
        assert apply_flag_preset(bound, 'General (Default)')
        bound.location = collision[0]
        bound.scale = collision[1]
        bound.hide_render = True
        bounds.hide_render = True
    corners = [obj.matrix_world @ Vector(c) for c in obj.bound_box]
    bbmin = Vector(tuple(min(c[i] for c in corners) for i in range(3)))
    bbmax = Vector(tuple(max(c[i] for c in corners) for i in range(3)))
    center = (bbmin+bbmax)*0.5
    specs[name] = {'min': list(bbmin), 'max': list(bbmax), 'triangles': len(obj.data.polygons),
        'low_triangles': len(low_mesh.polygons)}
    models[name] = drawable
    target = AssetTarget(AssetFormat.CWXML, AssetVersion.GEN8)
    with export_context_scope(ExportContext(name, ExportSettings((target,)))):
        bundle = export_ydr(drawable)
        assert bundle, 'Drawable export failed'
        bundle.save(OUT, [target])
    parts.clear()
    return Archetype(name=name, type=ArchetypeType.BASE, flags=32, lod_dist=120,
        special_attribute=0, hd_texture_dist=40, texture_dictionary='', clip_dictionary='',
        drawable_dictionary='', physics_dictionary='', bb_min=bbmin, bb_max=bbmax,
        bs_center=center, bs_radius=(bbmax-center).length, asset_name=name,
        asset_type=ArchetypeAssetType.DRAWABLE, extensions=[])

# Station: powder-coated pedestal, service hatch, pressure gauge and hose reel.
box('Plinth',(0,0,0.055),(.84,.64,.11),'rubber',.025)
box('Base',(0,0,.16),(.73,.55,.16),'steel',.025)
box('Cabinet',(0,0,.81),(.64,.46,1.20),'graphite',.035)
box('Front blue face',(0,-.244,.88),(.57,.032,1.08),'blue',.018)
box('Rear service hatch',(0,.24,.80),(.51,.025,.85),'steel',.008)
for x in [-.24,.24]:
    for z in [.40,1.18]: cylinder('Hatch screw',(x,.258,z),.012,.01,'graphite','Y',12)
for i in range(7): box('Vent grille',(0,-.269,.43+i*.033),(.34,.014,.012),'graphite',.003)
box('Console',(0,-.015,1.46),(.72,.55,.30),'graphite',.025)
box('Display bezel',(-.10,-.303,1.49),(.38,.026,.18),'steel',.008)
box('Display',(-.10,-.32,1.49),(.34,.012,.145),'screen',.006)
text('READY',(-.10,-.329,1.495),.048,'led')
text('150 BAR',(-.10,-.329,1.445),.025,'white')
cylinder('Gauge housing',(.215,-.316,1.50),.065,.045,'steel','Y',24)
cylinder('Gauge face',(.215,-.342,1.50),.054,.007,'white','Y',24)
box('Gauge needle',(.22,-.349,1.515),(.006,.005,.055),'red',.001,rotation=(0,-.6,0))
for angle in [-1.0,-.5,0,.5,1.0]:
    x=.215+math.sin(angle)*.041; z=1.50+math.cos(angle)*.041
    box('Gauge tick',(x,-.348,z),(.003,.003,.010),'graphite',.0005,rotation=(0,angle,0))
box('Header',(0,0,1.705),(.76,.57,.16),'blue',.020)
box('Header stripe',(0,-.295,1.665),(.68,.01,.018),'blue_light',.003)
text('MRW WASH',(0,-.294,1.704),.075,'white')
text('PRESSURE WASH',(0,-.267,1.20),.045,'white')
text('SELF SERVICE',(0,-.267,1.12),.027,'white')
cylinder('Start button',(.15,-.271,1.0),.034,.025,'led','Y')
cylinder('Emergency button',(.24,-.271,1.0),.027,.025,'red','Y')
box('Payment slot',(-.14,-.27,1.0),(.14,.014,.045),'graphite',.004)
box('Gun holster',(-.36,-.04,1.12),(.10,.18,.12),'rubber',.008)
tube('Holster hook',[(-.40,-.10,1.22),(-.44,-.10,1.24),(-.45,-.10,1.15)],.012,'steel')
cylinder('Reel axle',(.39,.02,.91),.038,.20,'steel','X')
for x in [.375,.59]:
    cylinder('Reel flange',(x,.02,.91),.235,.018,'blue','X',32)
    torus('Reel flange edge',(x,.02,.91),.220,.015,'graphite','X')
for i in range(7): torus('Coiled hose',(.405+i*.024,.02,.91),.176,.014,'rubber','X')
tube('Hose tail',[(.53,-.145,.81),(.57,-.26,.60),(.40,-.32,.29),(.16,-.31,.31),(.14,-.27,.64)],.014,'rubber')
cylinder('Water inlet',(.18,.27,.25),.025,.06,'brass','Y')
for x in [-.32,.32]:
    for y in [-.22,.22]: cylinder('Anchor bolt',(x,y,.25),.018,.012,'steel','Z',6)
station = complete('mrw_pressure_stand', ((0,0,.91),(.76,.56,1.78)))

# Hand prop: grip origin at the palm; lance points along local +Y.
box('Grip',(0,0,-.035),(.055,.060,.145),'rubber',.012,rotation=(-.22,0,0))
box('Pressure body',(0,.075,.075),(.078,.25,.10),'blue',.018)
box('Rear cap',(0,-.060,.072),(.072,.045,.085),'graphite',.012)
box('Upper shell',(0,.08,.132),(.065,.22,.025),'graphite',.008)
for z in [-.075,-.05,-.025,0]: box('Grip ribs',(0,-.032,z),(.058,.012,.008),'graphite',.002)
tube('Trigger guard',[(0,.02,-.10),(0,.14,-.09),(0,.17,.02),(0,.15,.065)],.009,'graphite')
box('Trigger',(0,.065,.007),(.016,.018,.075),'blue_light',.004,rotation=(.30,0,0))
cylinder('Front coupling',(0,.228,.078),.035,.070,'graphite','Y')
cylinder('Brass fitting',(0,.270,.078),.026,.035,'brass','Y',12)
cylinder('Lance steel',(0,.475,.078),.011,.40,'steel','Y',16)
cylinder('Lance grip',(0,.34,.078),.024,.10,'rubber','Y',16)
for y in [.30,.32,.34,.36,.38]: torus('Lance ribs',(0,y,.078),.024,.003,'graphite','Y')
cylinder('Nozzle collar',(0,.688,.078),.023,.048,'graphite','Y',16)
cylinder('Blue nozzle',(0,.722,.078),.018,.025,'blue','Y',12)
cylinder('Nozzle aperture',(0,.737,.078),.008,.008,'rubber','Y',12)
cylinder('Hose quick connect',(0,-.025,-.129),.018,.045,'brass','Z',12)
tube('Flexible inlet',[(0,-.025,-.15),(0,-.03,-.20),(0,-.08,-.24)],.011,'rubber')
gun_arch = complete('mrw_pressure_gun')

target = AssetTarget(AssetFormat.CWXML, AssetVersion.GEN8)
save_asset(AssetMapTypes(name='mrw_carwash_props', archetypes=[station,gun_arch]), [target], OUT, 'mrw_carwash_props')

# Preserve the editable source with the actual game materials and LOD meshes.
bpy.context.preferences.filepaths.save_version = 0
bpy.ops.wm.save_as_mainfile(filepath=str(ROOT/'assets'/'source'/'mrw_carwash_props.blend'))

# Product sheet: the two original models at presentation scale, using the same geometry.
for obj in list(bpy.context.scene.objects): obj.hide_render = True
for mat_name, color in PALETTE.items():
    mat = bpy.data.materials.new('Preview '+mat_name)
    mat.use_nodes = True
    node = mat.node_tree.nodes.get('Principled BSDF')
    node.inputs['Base Color'].default_value = tuple((c/255)**2.2 for c in color)+(1,)
    node.inputs['Metallic'].default_value = .75 if mat_name in ['steel','brass'] else .08
    node.inputs['Roughness'].default_value = .25 if mat_name in ['blue','blue_light'] else .43
    materials['preview_'+mat_name] = mat
for name, root in models.items():
    original = next(c for c in root.children if c.type=='MESH' and c.sollum_type==SollumType.DRAWABLE_MODEL)
    copy = original.copy(); copy.data=original.data.copy()
    copy.parent = None
    bpy.context.collection.objects.link(copy)
    copy.hide_render = False
    if name.endswith('_gun'):
        copy.location = (.95,-.05,.65)
        copy.rotation_euler = (math.radians(15),math.radians(-15),math.radians(-95))
        copy.scale = (1.4,1.4,1.4)
    else: copy.location = (-.45,0,0)
    for i, mat in enumerate(copy.data.materials): copy.data.materials[i]=materials['preview_'+mat.name.removeprefix('MRW_')]
# Floor and lights.
bpy.ops.mesh.primitive_plane_add(size=200)
floor = bpy.context.object
mat = bpy.data.materials.new('Studio floor');mat.diffuse_color=(.055,.065,.085,1)
floor.data.materials.append(mat)
def area(name, pos, power, size, color):
    light = bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size;light.color=color
    obj=bpy.data.objects.new(name,light);bpy.context.collection.objects.link(obj);obj.location=pos
    obj.rotation_euler=(Vector((.3,0,.8))-obj.location).to_track_quat('-Z','Y').to_euler()
area('Softbox',(0,-4,5),1100,5,(.78,.88,1))
area('Rim',(2,2,4),1400,3,(.35,.65,1))
area('Warm fill',(-4,-1,2),850,3,(1,.85,.67))
camera=bpy.data.cameras.new('Product camera');obj=bpy.data.objects.new('Product camera',camera)
bpy.context.collection.objects.link(obj);obj.location=(3.6,-6,3.2)
obj.rotation_euler=(Vector((.4,0,.87))-obj.location).to_track_quat('-Z','Y').to_euler()
camera.type='ORTHO';camera.ortho_scale=4.1;bpy.context.scene.camera=obj
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=False
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.color=(.12,.12,.12)
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(PREVIEW/'mrw_carwash_props.png')
if os.environ.get('MRW_SKIP_RENDER') != '1':
    bpy.ops.render.render(write_still=True)
import json
(ROOT/'assets'/'model_metrics.json').write_text(json.dumps(specs,indent=2)+'\n')
print('MRW_MODELS_EXPORTED',json.dumps(specs))
