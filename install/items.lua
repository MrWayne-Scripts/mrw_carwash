-- Merge these entries into ox_inventory/data/items.lua (inside its return table).
-- Do not replace the inventory's entire item file.
['mrw_pressure_washer'] = {
    label = 'Tlaková pistole',
    weight = 1800,
    stack = false,
    close = true,
    consume = 0,
    durability = true,
    description = 'Opakovaně použitelná tlaková pistole pro samoobslužné myčky.',
    client = {export = 'mrw_carwash.useWasher'},
},
['mrw_carwash_soap'] = {
    label = 'Autošampon',
    weight = 500,
    stack = true,
    close = true,
    consume = 0,
    description = 'Jedna dávka šamponu pro relaci ručního mytí.',
},
