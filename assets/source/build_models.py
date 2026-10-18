"""Original pressure-washer models by MrW. Run in Blender 4.3 with Sollumz 2.9.
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
    'graphite': (25, 27, 30), 'rubber': (11, 12, 14),
    'red': (174, 24, 32), 'red_light': (224, 38, 45),
    'steel': (164, 171, 177), 'white': (232, 234, 235),
    'brass': (181, 132, 54), 'screen': (8, 17, 18),
    'led': (113, 226, 173), 'yellow': (232, 174, 38),
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
    obj.data.materials.append(materials[material] if isinstance(material, str) else material)
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

# Station: powder-coated red shell, instrument panel and a loose floor hose.
box('Rubber plinth',(0,0,.055),(.92,.70,.11),'rubber',.028)
box('Foot plate',(0,0,.145),(.84,.62,.09),'graphite',.018)
box('Lower steel frame',(0,0,.24),(.76,.57,.12),'steel',.015)
box('Cabinet core',(0,0,.84),(.68,.50,1.17),'graphite',.028)
box('Front powder-coated door',(0,-.263,.84),(.60,.035,1.12),'red',.018)
box('Front left rail',(-.315,-.283,.84),(.035,.025,1.16),'graphite',.007)
box('Front right rail',(.315,-.283,.84),(.035,.025,1.16),'graphite',.007)
box('Door lower kick plate',(0,-.288,.34),(.52,.018,.13),'graphite',.007)
box('Door upper seam',(0,-.287,1.36),(.54,.012,.012),'red_light',.003)

box('Service hatch',(0,.258,.82),(.54,.026,.86),'graphite',.012)
box('Service hatch inset',(0,.275,.82),(.48,.012,.79),'red',.008)
box('Service hatch seam',(0,.284,.82),(.008,.006,.72),'graphite',.002)
for x in [-.235,.235]:
    for z in [.48,1.16]: cylinder('Service hatch fastener',(x,.29,z),.013,.012,'steel','Y',12)
for z in [.43,.47,.51,.55,.59,.63,.67]:
    box('Front ventilation slot',(0,-.303,z),(.39,.012,.012),'graphite',.003)
for side in [-1,1]:
    for z in [.56,.62,.68,.74,.80,.86]:
        box('Side cooling slot',(side*.35,.04,z),(.012,.28,.018),'rubber',.004,rotation=(0,0,math.pi/2))

box('Control console',(0,-.012,1.46),(.76,.56,.29),'graphite',.024)
box('Console lower trim',(0,-.298,1.32),(.69,.018,.025),'red_light',.005)
box('Display bezel',(-.12,-.302,1.49),(.37,.028,.18),'steel',.008)
box('Status display',(-.12,-.321,1.49),(.335,.012,.145),'screen',.006)
text('READY',(-.12,-.330,1.502),.047,'led')
text('150 BAR',(-.12,-.330,1.448),.022,'white')
for x in [-.24,-.20,-.16,-.12,-.08,-.04]:
    box('Display status mark',(x,-.330,1.425),(.016,.003,.004),'red_light',.001)

cylinder('Gauge housing',(.235,-.316,1.50),.068,.045,'graphite','Y',32)
cylinder('Gauge rim',(.235,-.343,1.50),.059,.012,'steel','Y',32)
cylinder('Gauge face',(.235,-.351,1.50),.051,.006,'white','Y',32)
for angle in [-1.15,-.86,-.57,-.28,0,.28,.57,.86,1.15]:
    x=.235+math.sin(angle)*.040; z=1.50+math.cos(angle)*.040
    box('Gauge scale',(x,-.356,z),(.003,.003,.009),'graphite',.0005,rotation=(0,angle,0))
box('Gauge needle',(.24,-.359,1.515),(.005,.004,.041),'red',.001,rotation=(0,-.48,0))
cylinder('Gauge pivot',(.235,-.361,1.50),.006,.004,'graphite','Y',12)

box('Payment terminal frame',(-.20,-.305,1.11),(.23,.035,.29),'graphite',.012)
box('Payment terminal display',(-.20,-.326,1.18),(.17,.012,.07),'screen',.004)
text('CARD',(-.20,-.334,1.18),.018,'white')
for row in range(3):
    for col in range(3):
        cylinder('Keypad button',(-.25+col*.05,-.333,1.10-row*.045),.011,.009,
            'steel' if row == 2 and col == 2 else 'graphite','Y',12)
box('Contactless badge',(-.20,-.326,1.285),(.12,.012,.035),'red_light',.004)
for radius in [.008,.015,.022]: torus('Contactless mark',(-.20+radius,-.336,1.285),radius,.002,'white','Y')
box('Cash slot',(.14,-.306,1.11),(.14,.024,.035),'rubber',.004)
box('Slot trim',(.14,-.321,1.11),(.10,.006,.008),'steel',.002)

box('Emergency stop base',(.25,-.307,1.13),(.10,.045,.10),'yellow',.012)
cylinder('Emergency stop button',(.25,-.342,1.15),.038,.05,'red_light','Y',24)
box('Emergency label',(.25,-.308,1.065),(.12,.012,.022),'graphite',.003)
text('STOP',(.25,-.317,1.066),.012,'white')

box('Brandless header',(0,0,1.705),(.79,.59,.16),'red',.019)
box('Header black lower lip',(0,-.301,1.651),(.71,.014,.022),'graphite',.004)
box('Header reflective stripe',(0,-.303,1.681),(.70,.007,.008),'red_light',.002)
text('SELF SERVICE',(0,-.302,1.706),.041,'white')
text('PRESSURE WASH',(0,-.283,1.235),.043,'white')
text('HIGH PRESSURE',(0,-.285,1.174),.021,'white')
cylinder('Status light bezel',(-.24,-.304,.96),.027,.018,'graphite','Y',20)
cylinder('Status light',(-.24,-.318,.96),.016,.012,'led','Y',20)
box('Gun holster',(-.365,-.06,1.08),(.10,.18,.13),'rubber',.009)
tube('Holster hook',[(-.405,-.12,1.18),(-.45,-.12,1.20),(-.46,-.12,1.11)],.013,'steel')

cylinder('Reel axle',(.40,.02,.92),.041,.24,'steel','X',24)
for x in [.365,.635]:
    cylinder('Reel flange',(x,.02,.92),.248,.025,'graphite','X',40)
    torus('Reel red rim',(x,.02,.92),.228,.018,'red','X')
    torus('Reel steel lip',(x,.02,.92),.198,.007,'steel','X')
    cylinder('Reel hub',(x,.02,.92),.065,.028,'red_light','X',24)
    for angle in [0,math.pi/3,2*math.pi/3]:
        box('Reel spoke',(x,.02,.92),(.026,.31,.012),'steel',.004,rotation=(angle,0,0))
for i in range(9): torus('High pressure hose on reel',(.395+i*.025,.02,.92),.174,.018,'rubber','X')
tube('Hose from reel to floor',[(.52,-.12,.84),(.58,-.22,.68),(.45,-.30,.44),(.38,-.30,.20),
    (.47,-.34,.055),(.72,-.42,.032),(.94,-.59,.027),(.92,-.81,.027),(.69,-.91,.027),
    (.52,-.81,.027),(.59,-.62,.027),(.88,-.56,.027),(1.12,-.68,.027),(1.24,-.84,.027),
    (1.10,-.96,.035)],.020,'rubber')
cylinder('Floor hose outlet',(1.105,-.96,.036),.025,.085,'graphite','X',20)
torus('Floor hose locking ring',(1.145,-.96,.036),.027,.006,'brass','X')
torus('Floor hose strain relief',(1.065,-.96,.036),.023,.005,'rubber','X')
cylinder('Water inlet',(.19,.27,.25),.026,.07,'brass','Y',20)
for x in [-.34,.34]:
    for y in [-.25,.25]: cylinder('Floor anchor bolt',(x,y,.21),.019,.014,'steel','Z',8)
station = complete('mrw_pressure_stand', ((0,0,.91),(.76,.56,1.78)))

# Hand prop: grip origin at the palm; lance points along local +Y.
box('Pressure gun grip',(0,0,-.035),(.060,.064,.155),'rubber',.014,rotation=(-.22,0,0))
box('Grip heel',(0,-.018,-.109),(.064,.068,.035),'graphite',.009)
for z in [-.087,-.060,-.033,-.006]: box('Moulded grip rib',(0,-.035,z),(.062,.012,.009),'graphite',.003)
box('Red pressure housing',(0,.075,.075),(.082,.255,.106),'red',.018)
box('Black rear cover',(0,-.062,.074),(.076,.052,.088),'graphite',.012)
box('Top pressure cover',(0,.079,.133),(.070,.225,.026),'graphite',.008)
box('Side service insert',(.044,.092,.081),(.009,.092,.046),'red_light',.004)
box('Safety selector',(-.046,.015,.105),(.012,.055,.018),'steel',.004)
for y in [.035,.12,.205]: cylinder('Housing fastener',(.047,y,.081),.006,.004,'steel','X',10)
tube('Trigger guard',[(0,.012,-.105),(0,.145,-.10),(0,.174,.005),(0,.15,.061)],.010,'graphite')
box('Red trigger',(0,.066,.004),(.018,.019,.078),'red_light',.004,rotation=(.30,0,0))
cylinder('Front coupling',(0,.228,.078),.037,.075,'graphite','Y',20)
torus('Front coupling ring',(0,.263,.078),.030,.006,'steel','Y')
cylinder('Brass lance fitting',(0,.278,.078),.028,.035,'brass','Y',16)
cylinder('Lance steel',(0,.484,.078),.012,.39,'steel','Y',20)
cylinder('Lance hand grip',(0,.35,.078),.025,.11,'rubber','Y',20)
for y in [.302,.322,.342,.362,.382,.402]: torus('Lance grip rib',(0,y,.078),.025,.0035,'graphite','Y')
cylinder('Nozzle collar',(0,.687,.078),.025,.052,'graphite','Y',20)
torus('Nozzle collar ridge',(0,.706,.078),.022,.004,'steel','Y')
cylinder('Red nozzle',(0,.724,.078),.018,.026,'red_light','Y',16)
cylinder('Nozzle aperture',(0,.741,.078),.008,.009,'rubber','Y',12)
cylinder('Gun hose quick connect',(0,-.025,-.129),.020,.047,'brass','Z',16)
torus('Gun hose clamp',(0,-.025,-.152),.018,.004,'steel','Z')
tube('Gun strain relief',[(0,-.025,-.15),(0,-.03,-.19),(0,-.08,-.24)],.013,'rubber')
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
    node.inputs['Metallic'].default_value = .78 if mat_name in ['steel','brass'] else .12
    node.inputs['Roughness'].default_value = .27 if mat_name in ['red','red_light'] else .46
    materials['preview_'+mat_name] = mat
for name, root in models.items():
    original = next(c for c in root.children if c.type=='MESH' and c.sollum_type==SollumType.DRAWABLE_MODEL)
    copy = original.copy(); copy.data=original.data.copy()
    copy.parent = None
    bpy.context.collection.objects.link(copy)
    copy.hide_render = False
    if name.endswith('_gun'):
        copy.location = (1.62,-.98,.31)
        copy.rotation_euler = (0,0,math.radians(-90))
        copy.scale = (1.25,1.25,1.25)
    else: copy.location = (-.45,0,0)
    for i, mat in enumerate(copy.data.materials): copy.data.materials[i]=materials['preview_'+mat.name.removeprefix('MRW_')]
    if name.endswith('_gun'):
        bpy.context.view_layer.update()
        port = copy.matrix_world @ Vector((0,-.08,-.24))
        tube('Loose preview hose',[(.655,-.96,.036),(.83,-1.14,.027),(1.06,-1.28,.024),
            (1.31,-1.28,.024),(1.51,-1.16,.024),(1.59,-1.02,.026),
            (port.x,port.y,max(.024,port.z))],.020,materials['preview_rubber'])
# Floor and lights.
bpy.ops.mesh.primitive_plane_add(size=200)
floor = bpy.context.object
mat = bpy.data.materials.new('Studio floor');mat.diffuse_color=(.055,.065,.085,1)
floor.data.materials.append(mat)
def area(name, pos, power, size, color):
    light = bpy.data.lights.new(name,'AREA');light.energy=power;light.shape='DISK';light.size=size;light.color=color
    obj=bpy.data.objects.new(name,light);bpy.context.collection.objects.link(obj);obj.location=pos
    obj.rotation_euler=(Vector((.35,-.42,.80))-obj.location).to_track_quat('-Z','Y').to_euler()
area('Softbox',(0,-4,5),1100,5,(.78,.88,1))
area('Rim',(2,2,4),1400,3,(.35,.65,1))
area('Warm fill',(-4,-1,2),850,3,(1,.85,.67))
camera=bpy.data.cameras.new('Product camera');obj=bpy.data.objects.new('Product camera',camera)
bpy.context.collection.objects.link(obj);obj.location=(3.6,-6,3.2)
obj.rotation_euler=(Vector((.4,0,.87))-obj.location).to_track_quat('-Z','Y').to_euler()
camera.type='ORTHO';camera.ortho_scale=5.4;bpy.context.scene.camera=obj
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.use_denoising=False
scene.render.resolution_x=1600;scene.render.resolution_y=1100;scene.render.resolution_percentage=100
scene.world.color=(.12,.12,.12)
scene.render.image_settings.file_format='PNG';scene.render.filepath=str(PREVIEW/'mrw_carwash_props.png')
if os.environ.get('MRW_SKIP_RENDER') != '1':
    bpy.ops.render.render(write_still=True)
import json
(ROOT/'assets'/'model_metrics.json').write_text(json.dumps(specs,indent=2)+'\n')
print('MRW_MODELS_EXPORTED',json.dumps(specs))
