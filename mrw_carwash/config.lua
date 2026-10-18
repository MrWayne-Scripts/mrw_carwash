--[[
    MRW CARWASH • 3.0.0-rc.1
    Konfigurace serveru. Změny se načtou po restartu resource.

    RYCHLÉ NASTAVENÍ
      1. Zvol jazyk a způsob platby.
      2. Přidej předměty z install/items.lua do ox_inventory.
      3. Uprav souřadnice a natočení stojanů dole v tomto souboru.
      4. Ve hře ověř držení pistole, kolize a multiplayer podle docs/TESTING.md.

    Jednotky: metry, sekundy; výslovně označené časy jsou v milisekundách.
    false = vypnuto. nil u ceny stojanu = použít společnou cenu.
    Žádné heslo, token ani licenční klíč do tohoto souboru nepatří.
    Přehled všech voleb: docs/CONFIGURATION.md.
]]

Config = {
    -- ═══════════════════════════════════════════════════════════════════════
    -- 01 / ZÁKLAD
    -- ═══════════════════════════════════════════════════════════════════════
    Locale = 'cs',             -- 'cs' / 'en'; texty jsou v locales/*.json
    Debug = false,            -- výpis začátku a konce relací do konzole
    Framework = 'auto',       -- 'auto' / 'esxlegacy' / 'qbcore' / 'standalone'

    -- ═══════════════════════════════════════════════════════════════════════
    -- 02 / EKONOMIKA
    -- ═══════════════════════════════════════════════════════════════════════
    Payment = {
        provider = 'inventory', -- 'inventory' = měnový item, 'framework' = účty
        item = 'money',         -- jen inventory; musí existovat v ox_inventory
        accounts = {'money', 'bank'}, -- jen framework; QBCore: {'cash', 'bank'}
        cost = 30,              -- základní cena relace; 0 = zdarma
        symbol = '$',           -- pouze zobrazení; nemění ekonomiku ani měnu
        -- Poplatek není záloha. Vrácení, smrt ani restart jej automaticky nevrací.
        -- Účtuje se až po vytvoření pistole, potvrzení serverem a kontrole vybavení.
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 03 / OX_INVENTORY A OPOTŘEBENÍ
    -- ═══════════════════════════════════════════════════════════════════════
    Inventory = {
        required = true,                -- hráč musí vlastnit funkční pistoli
        tool = 'mrw_pressure_washer',    -- stack=false, consume=0, durability=true
        soap = 'mrw_carwash_soap',       -- při zapnutí šamponu se spotřebuje 1 kus
        wearPerTick = 0.04,              -- úbytek z životnosti 0–100 za platný střik
        -- 100 / 0.04 = přibližně 2500 střiků. Pistole není dočasný pronajatý item.
        -- Po ukončení zůstane v inventáři. Časová degradace (degrade) se nepoužívá.
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 04 / PRŮBĚH MYTÍ, DOSAH A SPOTŘEBA
    -- ═══════════════════════════════════════════════════════════════════════
    Washer = {
        radius = 20.0,             -- dosah od stojanu; překročení ukončí relaci
        range = 6.0,               -- dosah proudu od hráče
        tickMs = 350,              -- interval střiků v ms; 100–5000
        dirtPerTick = 0.35,        -- GTA špína 0–15, úbytek za zásah vozidla
        sessionSeconds = 600,      -- maximální délka aktivního mytí
        waterTicks = 240,          -- zásoba střiků; ubývá i při střiku do prázdna
        pickupMs = 1200,           -- zrušitelná příprava před rezervací / platbou
        targetDistance = 2.5,      -- vzdálenost pro interakci ox_target
        effectDistance = 60.0,     -- distribuce efektů hráčům poblíž (stejný bucket)

        -- VLASTNÍ MODELY • přiložené soubory jsou v stream/
        standModel = 'mrw_pressure_stand',
        gunModel = 'mrw_pressure_gun',
        handBone = 57005,          -- pravá ruka
        gunOffset = vector3(0.03, 0.02, -0.02),
        gunRotation = vector3(-90.0, 0.0, 0.0), -- stupně; doladit s animací ve hře
        nozzleOffset = vector3(0.0, 0.745, 0.078), -- přesné ústí dodaného modelu

        -- VIZUÁL • samotné mytí stále povoluje a počítá server
        particleDict = 'core',
        particleName = 'ent_sht_water',
        animation = {dict = 'weapons@rifle@', clip = 'idle', flag = 49},
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 05 / ŠAMPON
    -- ═══════════════════════════════════════════════════════════════════════
    Foam = {
        enabled = true,
        multiplier = 1.6, -- násobič úbytku špíny po spotřebování jedné dávky
        -- Platí do konce relace. Jde o bonus a světlejší proud, nikoli vrstvu pěny.
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 06 / OVLÁDÁNÍ A ROZHRANÍ OX_LIB
    -- ═══════════════════════════════════════════════════════════════════════
    Keys = {
        menu = 'G',
        returnWasher = 'X',
        -- Výchozí klávesy; hráč si je může přemapovat ve FiveM nastavení.
        -- Stříkání používá levé tlačítko myši.
    },
    UI = {
        showHud = true,
        hudPosition = 'right-center',      -- right-center / left-center / top-center
        notificationPosition = 'top-right',
        progressPosition = 'bottom',       -- bottom / middle
    },
    Blips = {
        enabled = true,
        sprite = 100,
        colour = 3,
        scale = 0.75,
    },

    -- ═══════════════════════════════════════════════════════════════════════
    -- 07 / STANICE
    -- ═══════════════════════════════════════════════════════════════════════
    -- id         unikátní stálý identifikátor, bez mezer
    -- enabled    false vypne použití, model i blip této stanice
    -- location   souřadnice; ground Z a průjezd ověř na své mapě/MLO
    -- heading    natočení ve stupních
    -- capacity   počet souběžných rezervací a aktivních hráčů, 1–10
    -- bucket     serverový routing bucket; 0 = běžný veřejný svět
    -- price      nil = Payment.cost, 0 = zdarma, jiné celé číslo = vlastní cena
    -- showBlip   false skryje jen mapovou značku této stanice
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
        -- DALŠÍ STANICE: zkopíruj celý blok výše, dej mu nové id a souřadnice.
        -- Nezapomeň na čárku za blokem a jedinečné id.
    },
}
