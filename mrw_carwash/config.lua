-- MRW Carwash | 3.0.0-rc.2
-- Autor: MrW
-- Změny konfigurace načte restart resource.

Config = {
    -- Základní nastavení
    Locale = 'cs',
    Debug = false,
    Framework = 'auto',

    -- Platby
    Payment = {
        provider = 'inventory',
        item = 'money',
        accounts = {'money', 'bank'},
        cost = 30,
        symbol = '$',
    },

    -- Inventář a vybavení
    Inventory = {
        required = true,
        tool = 'mrw_pressure_washer',
        soap = 'mrw_carwash_soap',
        wearPerTick = 0.04,
    },

    -- Mytí a hadice
    Washer = {
        radius = 20.0,
        range = 6.0,
        tickMs = 350,
        dirtPerTick = 0.35,
        sessionSeconds = 600,
        waterTicks = 240,
        pickupMs = 1200,
        targetDistance = 2.5,
        effectDistance = 60.0,

        standModel = 'mrw_pressure_stand',
        gunModel = 'mrw_pressure_gun',
        handBone = 57005,
        gunOffset = vector3(0.03, 0.02, -0.02),
        gunRotation = vector3(-90.0, 0.0, 0.0),
        nozzleOffset = vector3(0.0, 0.745, 0.078),
        hoseStandAnchor = vector3(1.105, -0.96, 0.036),
        hoseGunAnchor = vector3(0.0, -0.08, -0.24),
        hoseSlack = 3.0,
        hoseLength = 24.0,
        hoseType = 3,
        hoseData = 'ropeFamily3',

        particleDict = 'core',
        particleName = 'ent_sht_water',
        animation = {dict = 'weapons@rifle@', clip = 'idle', flag = 49},
    },

    -- Šampon
    Foam = {
        enabled = true,
        multiplier = 1.6,
    },

    -- Ovládání
    Keys = {
        menu = 'G',
        returnWasher = 'X',
    },

    -- Rozhraní
    UI = {
        showHud = true,
        hudPosition = 'right-center',
        notificationPosition = 'top-right',
        progressPosition = 'bottom',
    },

    -- Mapa
    Blips = {
        enabled = true,
        sprite = 100,
        colour = 1,
        scale = 0.75,
    },

    -- Stanice
    locations = {
        {
            id = 'strawberry',
            enabled = true,
            name = 'Strawberry Carwash',
            location = vector3(23.68, -1391.92, 29.32),
            heading = 90.0,
            capacity = 1,
            bucket = 0,
            price = nil,
            showBlip = true,
        },
        {
            id = 'little_seoul',
            enabled = true,
            name = 'Little Seoul Carwash',
            location = vector3(-699.84, -934.0, 19.0),
            heading = 90.0,
            capacity = 1,
            bucket = 0,
            price = nil,
            showBlip = true,
        },
        {
            id = 'paleto',
            enabled = true,
            name = 'Paleto Carwash',
            location = vector3(-216.4, 6199.92, 31.48),
            heading = 45.0,
            capacity = 1,
            bucket = 0,
            price = nil,
            showBlip = true,
        },
    },
}
