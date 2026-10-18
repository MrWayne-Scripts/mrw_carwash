fx_version 'cerulean'
game 'gta5'
name 'mrw_carwash'
description 'Ruční samoobslužná tlaková myčka od MrW'
author 'MrW'
version '3.0.0-rc.2'
lua54 'yes'

shared_scripts {
    '@ox_lib/init.lua',
    'config.lua',
    'shared/core.lua',
}
server_scripts {
    'server/bridge.lua',
    'server/main.lua',
}
client_script 'client.lua'
files {
    'locales/*.json',
    'stream/mrw_carwash_props.ytyp',
}
data_file 'DLC_ITYP_REQUEST' 'stream/mrw_carwash_props.ytyp'
dependencies {'ox_lib', 'ox_inventory', 'ox_target', '/onesync'}

escrow_ignore {'config.lua', 'locales/*.json', 'server/bridge.lua'}
