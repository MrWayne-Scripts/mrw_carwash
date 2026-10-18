"""Validate real shipped resources and source assets, using only Python's standard library."""
import hashlib
import json
import re
import struct
from pathlib import Path
from xml.etree import ElementTree as ET

root = Path(__file__).resolve().parents[1]
resource = root / 'mrw_carwash'
checks = 0

def check(ok, message):
    global checks
    assert ok, message
    checks += 1

manifest = (resource / 'fxmanifest.lua').read_text()
config = (resource / 'config.lua').read_text()
for dependency in ['ox_lib', 'ox_inventory', 'ox_target', '/onesync']:
    check("'" + dependency + "'" in manifest, 'Missing dependency ' + dependency)
check("data_file 'DLC_ITYP_REQUEST' 'stream/mrw_carwash_props.ytyp'" in manifest, 'Missing archetype registration')
for path in ['server/bridge.lua', 'server/main.lua', 'client.lua', 'config.lua', 'shared/core.lua']:
    check((resource / path).is_file() and "'" + path + "'" in manifest, 'Unregistered code ' + path)
check(not (resource / 'server.lua').exists(), 'Obsolete unsecured server entrypoint retained')
locales = {lang: json.loads((resource / 'locales' / (lang + '.json')).read_text()) for lang in ['cs', 'en']}
check(locales['cs'].keys() == locales['en'].keys(), 'Locale keys differ')
code = '\n'.join(path.read_text() for path in resource.rglob('*.lua'))
keys = set(re.findall(r"locale\('([a-z_]+)'", code))
keys |= set(re.findall(r"reply\('([a-z_]+)'", code))
keys |= set(re.findall(r"finish\([^\n]*?, '([a-z_]+)'\)", code))
for key in keys:
    check(key in locales['en'], 'Missing locale ' + key)
for key in locales['en']:
    check(re.findall(r'%[sd]', locales['cs'][key]) == re.findall(r'%[sd]', locales['en'][key]), 'Locale arguments differ ' + key)
for name in ['mrw_pressure_washer', 'mrw_carwash_soap']:
    png = (root / 'install/images' / (name + '.png')).read_bytes()
    check(png[:8] == b'\x89PNG\r\n\x1a\n', 'Missing inventory PNG')
    width, height, depth, colour = struct.unpack('>IIBB', png[16:26])
    check((width, height, colour) == (512, 512, 6), 'Icon must have transparent RGBA channels')
    check(name in (root / 'install/items.lua').read_text(), 'Missing item template')
props = ET.parse(root / 'assets/export/mrw_carwash_props.ytyp.xml').getroot().findall('archetypes/Item')
check(len(props) == 2, 'Expected two archetypes')
for prop in props:
    name = prop.findtext('name')
    check(name in config, 'Config does not use shipped prop ' + name)
    binary = (resource / 'stream' / (name + '.ydr')).read_bytes()
    check(binary[:4] == b'RSC7' and len(binary) > 10000, 'Not a native RAGE resource')
    xml = ET.parse(root / 'assets/export' / (name + '.ydr.xml')).getroot()
    for lod in ['High', 'Medium', 'Low']:
        check(len(xml.findall('DrawableModels' + lod + '/Item')) > 0, 'Missing LOD ' + lod)
    for texture in xml.findall('ShaderGroup/TextureDictionary/Item'):
        filename = texture.findtext('FileName')
        dds = (root / 'assets/export' / filename).read_bytes()
        check(dds[:4] == b'DDS ' and dds[84:88] == b'DXT1', 'Invalid BC1 input')
        height, width, mips = struct.unpack_from('<I', dds, 12)[0], struct.unpack_from('<I', dds, 16)[0], struct.unpack_from('<I', dds, 28)[0]
        check((width, height, mips) == (8, 8, 4) and len(dds) == 184, 'Incomplete DDS mip chain')
    if name.endswith('stand'):
        check(xml.find('Bounds') is not None, 'Missing station collision source')
check((resource / 'stream/mrw_carwash_props.ytyp').read_bytes()[:4] == b'RSC7', 'Invalid native YTYP')
check((root / 'assets/source/mrw_carwash_props.blend').read_bytes()[:7] == b'BLENDER', 'Missing editable source')
for documentation in ['INSTALLATION', 'CONFIGURATION', 'DEVELOPMENT', 'TESTING', 'RELEASE']:
    check((root / 'docs' / (documentation + '.md')).is_file(), 'Missing documentation ' + documentation)
print(f'{checks} packaging/localization/asset checks passed')
