local stands, standTargets, standColliders, blips, effects, appliedDirt, remoteGuns, hoses = {}, {}, {}, {}, {}, {}, {}, {}
local active, pending, preparing, gun, previousWeapon, hud
local generation, stopping = 0, false
local menuBind, returnBind
local anim = Config.Washer.animation
local ropeTexturesRequested, ropeTexturesOwned = false, false
local function removeHose(src)
    local entry = hoses[src]
    hoses[src] = nil
    if entry and entry.rope and type(DoesRopeExist) == 'function' and DoesRopeExist(entry.rope)
        and type(DeleteRope) == 'function' then
        DeleteRope(entry.rope)
    end
end
local function removeAllHoses()
    for src in pairs(hoses) do removeHose(src) end
    if ropeTexturesOwned and type(GetAllRopes) == 'function' and type(RopeUnloadTextures) == 'function'
        and #GetAllRopes() == 0 then
        RopeUnloadTextures()
        ropeTexturesRequested, ropeTexturesOwned = false, false
    end
end
local function ropeTexturesReady()
    if type(RopeAreTexturesLoaded) ~= 'function' or type(RopeLoadTextures) ~= 'function' then return false end
    if RopeAreTexturesLoaded() then return true end
    if not ropeTexturesRequested then
        ropeTexturesRequested = true
        ropeTexturesOwned = true
        RopeLoadTextures()
    end
    return RopeAreTexturesLoaded()
end
local function hosePoints(stationIndex, hoseGun)
    local stand = stands[stationIndex]
    if not stand or not DoesEntityExist(stand) or not hoseGun or not DoesEntityExist(hoseGun) then return end
    local stationAnchor, gunAnchor = Config.Washer.hoseStandAnchor, Config.Washer.hoseGunAnchor
    local start = GetOffsetFromEntityInWorldCoords(stand, stationAnchor.x, stationAnchor.y, stationAnchor.z)
    local finish = GetOffsetFromEntityInWorldCoords(hoseGun, gunAnchor.x, gunAnchor.y, gunAnchor.z)
    return start, finish
end
local function createHose(src, stationIndex, hoseGun)
    if type(AddRope) ~= 'function' or type(AttachEntitiesToRope) ~= 'function'
        or type(DoesRopeExist) ~= 'function' or not ropeTexturesReady() then return end
    local stand = stands[stationIndex]
    local start, finish = hosePoints(stationIndex, hoseGun)
    if not stand or not start or not finish then return end
    local initialLength = math.min(Config.Washer.hoseLength,
        math.max(1.0, #(finish - start) + Config.Washer.hoseSlack))
    local origin = (start + finish) * 0.5
    local ok, rope = pcall(AddRope, origin.x, origin.y, origin.z, 0.0, 0.0, 0.0,
        Config.Washer.hoseLength, Config.Washer.hoseType, initialLength, 1.0, 1.0,
        false, true, false, 1.0, false, 0)
    if not ok or type(rope) ~= 'number' or rope == 0 or not DoesRopeExist(rope) then return end
    if type(LoadRopeData) == 'function' then pcall(LoadRopeData, rope, Config.Washer.hoseData) end
    local attached = pcall(AttachEntitiesToRope, rope, stand, hoseGun,
        start.x, start.y, start.z, finish.x, finish.y, finish.z, initialLength, false, false, nil, nil)
    if not attached then
        if DoesRopeExist(rope) and type(DeleteRope) == 'function' then DeleteRope(rope) end
        return
    end
    if type(RopeForceLength) == 'function' then pcall(RopeForceLength, rope, initialLength) end
    hoses[src] = {rope = rope, station = stationIndex, gun = hoseGun, lastAdjust = GetGameTimer()}
end
local function notify(key, kind)
    lib.notify({title = locale('title'), description = locale(key), type = kind or 'inform', position = Config.UI.notificationPosition})
end
local function callback(name, ...)
    local ok, response = pcall(lib.callback.await, name, false, ...)
    if not ok or type(response) ~= 'table' then notify('connection_error', 'error') return nil end
    if not response.ok then notify(response.error or 'connection_error', 'error') return nil end
    return response
end
local function load(request, loaded, asset)
    request(asset)
    local deadline = GetGameTimer() + 5000
    while not stopping and not loaded(asset) and GetGameTimer() < deadline do Wait(10) end
    return not stopping and loaded(asset)
end
local function model(name)
    local hash = joaat(name)
    return IsModelInCdimage(hash) and load(RequestModel, HasModelLoaded, hash) and hash or nil
end
local function offsetPosition(position, offset, heading)
    local angle = math.rad(heading or 0.0)
    return vector3(position.x + offset.x * math.cos(angle) + offset.y * math.sin(angle),
        position.y - offset.x * math.sin(angle) + offset.y * math.cos(angle), position.z + offset.z)
end
local function groundLevel(position, fallback)
    RequestCollisionAtCoord(position.x, position.y, fallback + 3.0)
    local deadline = GetGameTimer() + Config.Washer.groundWaitMs
    repeat
        local found, ground = GetGroundZFor_3dCoord(position.x, position.y, fallback + 3.0, false)
        if found then return ground end
        Wait(50)
    until stopping or GetGameTimer() >= deadline
    return fallback
end
local function addStandColliders(index, position, ground, heading, hash)
    if not hash then return end
    local min, max = GetModelDimensions(hash)
    local width, height = math.max(max.x - min.x, 0.2), math.max(max.z - min.z, 0.2)
    local columns = math.max(1, math.min(3, math.ceil(Config.Washer.standColliderWidth / (width * 0.85))))
    local layers = math.max(1, math.min(4, math.ceil(Config.Washer.standColliderHeight / (height * 0.9))))
    local entities = {}
    for layer = 0, layers - 1 do
        for column = 1, columns do
            local localX = (column - (columns + 1) / 2) * width * 0.82
            local offset = offsetPosition(vector3(0.0, 0.0, 0.0), vector3(localX, 0.0, 0.0), heading)
            local z = ground + layer * height - min.z
            local collider = CreateObjectNoOffset(hash, position.x + offset.x, position.y + offset.y, z, false, false, false)
            if collider ~= 0 then
                SetEntityAsMissionEntity(collider, true, true)
                SetEntityHeading(collider, heading or 0.0)
                SetEntityCollision(collider, true, true)
                SetEntityAlpha(collider, 0, false)
                SetEntityVisible(collider, false, false)
                FreezeEntityPosition(collider, true)
                entities[#entities + 1] = collider
            end
        end
    end
    standColliders[index] = entities
end
local function hideHud()
    local open, text = lib.isTextUIOpen()
    if open and text == hud then lib.hideTextUI() end
    hud = nil
end
local function release(tellServer)
    local old = active
    generation = generation + 1
    active = nil
    removeHose(GetPlayerServerId(PlayerId()))
    if gun and DoesEntityExist(gun) then DeleteEntity(gun) end
    gun = nil
    StopAnimTask(PlayerPedId(), anim.dict, anim.clip, 2.0)
    if previousWeapon and HasPedGotWeapon(PlayerPedId(), previousWeapon, false) then
        SetCurrentPedWeapon(PlayerPedId(), previousWeapon, true)
    end
    previousWeapon = nil
    hideHud()
    if tellServer and old then TriggerServerEvent('mrw_carwash:return', old.id) end
end
RegisterNetEvent('mrw_carwash:release', function(id, reason)
    if active and active.id == id then
        release(false)
        if reason ~= 'returned' then notify(reason) end
    end
end)
RegisterNetEvent('mrw_carwash:status', function(session)
    if active and active.id == session.id then
        active.water, active.foam = session.water, session.foam
        active.deadline = GetGameTimer() + session.seconds * 1000
    end
end)
RegisterNetEvent('mrw_carwash:cleaned', function() if active then notify('vehicle_clean', 'success') end end)

local function take(index, slot)
    if active or pending or stopping then return end
    if lib.progressActive() then notify('busy', 'error') return end
    pending = true
    local token = generation
    local hash = model(Config.Washer.gunModel)
    if not hash or not load(RequestAnimDict, HasAnimDictLoaded, anim.dict) then
        pending = false
        notify('model_failed', 'error')
        return
    end
    preparing = true
    local completed = lib.progressCircle({duration = Config.Washer.pickupMs, label = locale('preparing'),
        position = Config.UI.progressPosition, canCancel = true, useWhileDead = false, disable = {move = true, car = true, combat = true}})
    preparing = false
    if not completed or token ~= generation then pending = false return end
    local result = callback('mrw_carwash:take', index, slot)
    if not result then pending = false return end
    if token ~= generation or stopping then pending = false TriggerServerEvent('mrw_carwash:return', result.session.id) return end
    active = result.session
    active.deadline = GetGameTimer() + active.seconds * 1000
    local ped = PlayerPedId()
    previousWeapon = GetSelectedPedWeapon(ped)
    SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
    local p = GetEntityCoords(ped)
    gun = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
    if gun == 0 then pending = false release(true) notify('model_failed', 'error') return end
    SetEntityCollision(gun, false, false)
    local off, rot = Config.Washer.gunOffset, Config.Washer.gunRotation
    AttachEntityToEntity(gun, ped, GetPedBoneIndex(ped, Config.Washer.handBone), off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    local confirmed = callback('mrw_carwash:confirm', active.id)
    pending = false
    if not confirmed then release(true) return end
    if token ~= generation or not active then return end
    active = confirmed.session
    active.deadline = GetGameTimer() + active.seconds * 1000
    lib.notify({title = locale('title'), description = locale('equipped', menuBind and menuBind.currentKey or Config.Keys.menu, returnBind and returnBind.currentKey or Config.Keys.returnWasher), type = 'success', position = Config.UI.notificationPosition})
end
local function nearestStation()
    local p = GetEntityCoords(PlayerPedId())
    local closest, distance = nil, Config.Washer.targetDistance + 0.5
    for index, station in ipairs(Config.locations) do
        local d = #(p - station.location)
        if station.enabled ~= false and d < distance then closest, distance = index, d end
    end
    return closest
end
exports('useWasher', function(data, slot)
    if active or pending then notify('already_active', 'error') return end
    local index = nearestStation()
    if not index then notify('out_of_range', 'error') return end
    exports.ox_inventory:useItem(data, function(used)
        if used then take(index, slot.slot) end
    end)
end)
local function menu()
    if not active then return end
    lib.registerContext({id = 'mrw_carwash_menu', title = locale('title'), options = {
        {title = locale('foam'), description = locale('foam_description'), icon = 'soap', disabled = active.foam or not Config.Foam.enabled,
            onSelect = function()
                if active then
                    local result = callback('mrw_carwash:foam', active.id)
                    if result then notify('foam_enabled', 'success') end
                end
            end},
        {title = locale('return'), icon = 'rotate-left', onSelect = function() release(true) end},
    }})
    lib.showContext('mrw_carwash_menu')
end
menuBind = lib.addKeybind({name = 'mrw_carwash_menu', description = locale('menu_key'), defaultKey = Config.Keys.menu, onPressed = menu})
returnBind = lib.addKeybind({name = 'mrw_carwash_return', description = locale('return'), defaultKey = Config.Keys.returnWasher, onPressed = function() if active then release(true) end end})

local function deleteStand(index)
    local object = stands[index]
    if standTargets[index] and GetResourceState('ox_target') == 'started' then
        exports.ox_target:removeZone(standTargets[index])
    end
    standTargets[index] = nil
    for _, collider in ipairs(standColliders[index] or {}) do
        if DoesEntityExist(collider) then DeleteEntity(collider) end
    end
    standColliders[index] = nil
    if not object then return end
    if DoesEntityExist(object) then DeleteEntity(object) end
    stands[index] = nil
end
CreateThread(function()
    -- Static stands use ground-aligned hidden collision boxes and target zones, not drawable collision.
    local hash = model(Config.Washer.standModel)
    if not hash then print('[mrw_carwash] Stand model failed to load; check streamed assets and YTYP registration.') return end
    local colliderHash = model(Config.Washer.standColliderModel)
    if not colliderHash then print('[mrw_carwash] Collision proxy model failed to load.') end
    local min, max = GetModelDimensions(hash)
    local targetSize = Config.Washer.standTargetSize
    for index, station in ipairs(Config.locations) do
        if stopping then break end
        if station.enabled == false then goto next_station end
        local p = offsetPosition(station.location, station.standOffset or Config.Washer.standOffset, station.heading)
        local ground = groundLevel(p, station.location.z)
        local object = CreateObjectNoOffset(hash, p.x, p.y, ground - min.z + (station.standGroundOffset or Config.Washer.standGroundOffset), false, false, false)
        if object ~= 0 then
            stands[index] = object
            SetEntityHeading(object, station.heading or 0.0)
            SetEntityCoordsNoOffset(object, p.x, p.y, ground - min.z + (station.standGroundOffset or Config.Washer.standGroundOffset), false, false, false)
            SetEntityCollision(object, true, true)
            FreezeEntityPosition(object, true)
            SetEntityInvincible(object, true)
            standTargets[index] = exports.ox_target:addBoxZone({
                name = 'mrw_carwash_station_' .. station.id,
                coords = vector3(p.x, p.y, ground + targetSize.z / 2),
                size = targetSize,
                rotation = station.heading or 0.0,
                debug = Config.Debug,
                options = {
                {name = 'mrw_carwash_take_' .. station.id, icon = 'fa-solid fa-gun', label = locale('take', Config.Payment.symbol, station.price or Config.Payment.cost), distance = Config.Washer.targetDistance,
                    canInteract = function() return not active and not pending and not IsPedInAnyVehicle(PlayerPedId(), false) end,
                    onSelect = function() take(index) end},
                {name = 'mrw_carwash_menu_' .. station.id, icon = 'fa-solid fa-soap', label = locale('options'), distance = Config.Washer.targetDistance,
                    canInteract = function() return active and active.station == index end, onSelect = menu},
                {name = 'mrw_carwash_return_' .. station.id, icon = 'fa-solid fa-rotate-left', label = locale('return'), distance = Config.Washer.targetDistance,
                    canInteract = function() return active and active.station == index end, onSelect = function() release(true) end},
                },
            })
            addStandColliders(index, p, ground, station.heading or 0.0, colliderHash)
        else print(('[mrw_carwash] Failed to create stand %s'):format(station.id)) end
        if Config.Blips.enabled and station.showBlip ~= false then
            local blip = AddBlipForCoord(station.location.x, station.location.y, station.location.z)
            SetBlipSprite(blip, Config.Blips.sprite)
            SetBlipColour(blip, Config.Blips.colour)
            SetBlipScale(blip, Config.Blips.scale)
            SetBlipAsShortRange(blip, true)
            BeginTextCommandSetBlipName('STRING')
            AddTextComponentString(station.name)
            EndTextCommandSetBlipName(blip)
            blips[#blips + 1] = blip
        end
        ::next_station::
    end
    SetModelAsNoLongerNeeded(hash)
    if colliderHash then SetModelAsNoLongerNeeded(colliderHash) end
    load(RequestNamedPtfxAsset, HasNamedPtfxAssetLoaded, Config.Washer.particleDict)
end)

local function probe(start, dest, ped)
    local handle = StartShapeTestLosProbe(start.x, start.y, start.z, dest.x, dest.y, dest.z, 511, ped, 7)
    local status, hit, coords, normal, entity
    local deadline = GetGameTimer() + 100
    repeat
        Wait(0)
        status, hit, coords, normal, entity = GetShapeTestResult(handle)
    until status ~= 1 or GetGameTimer() >= deadline
    if status ~= 2 then return false, dest, 0 end
    return hit == 1, hit == 1 and coords or dest, entity
end
local function aimRay()
    local ped = PlayerPedId()
    local rotation = GetGameplayCamRot(2)
    local x, z = math.rad(rotation.x), math.rad(rotation.z)
    local direction = vector3(-math.sin(z)*math.cos(x), math.cos(z)*math.cos(x), math.sin(x))
    local camera = GetGameplayCamCoord()
    local hit, coords, entity = probe(camera, camera + direction*(Config.Washer.range + 3), ped)
    if not gun or not DoesEntityExist(gun) then return false, coords, 0 end
    local offset = Config.Washer.nozzleOffset
    local nozzle = GetOffsetFromEntityInWorldCoords(gun, offset.x, offset.y, offset.z)
    if not hit then return false, nozzle + direction * Config.Washer.range, 0 end
    local secondHit, impact, obstruction = probe(nozzle, coords, ped)
    if secondHit then return true, impact, obstruction end
    return true, coords, entity
end
local function waterEffect(src, hit, foam)
    if not Carwash.point(hit) then return end
    local player = GetPlayerFromServerId(src)
    if player == -1 then return end
    local ped = GetPlayerPed(player)
    local point = vector3(hit.x, hit.y, hit.z)
    if #(GetEntityCoords(PlayerPedId())-point) > Config.Washer.effectDistance then return end
    -- No yielding asset loads in effect event handlers: missing effects simply skip particles.
    if HasNamedPtfxAssetLoaded(Config.Washer.particleDict) then
        UseParticleFxAssetNextCall(Config.Washer.particleDict)
        StartParticleFxNonLoopedAtCoord(Config.Washer.particleName, point.x, point.y, point.z, 0, 0, 0, foam and 0.8 or 0.6, false, false, false)
    end
    effects[src] = {point = point, ped = ped, foam = foam, untilTime = GetGameTimer() + Config.Washer.tickMs + 30}
end
RegisterNetEvent('mrw_carwash:waterImpact', function(src, hit, foam)
    if src ~= GetPlayerServerId(PlayerId()) then waterEffect(src, hit, foam) end
end)
CreateThread(function()
    local nextSpray = 0
    while not stopping do
        if not active or pending then Wait(250) else
            Wait(0)
            local ped = PlayerPedId()
            if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or not gun or not DoesEntityExist(gun)
                or GetGameTimer() >= active.deadline
                or #(GetEntityCoords(ped) - Config.locations[active.station].location) > Config.Washer.radius then release(true)
            else
                DisablePlayerFiring(PlayerId(), true)
                for _, control in ipairs({24, 25, 37, 45, 140, 141, 142}) do DisableControlAction(0, control, true) end
                SetCurrentPedWeapon(ped, joaat('WEAPON_UNARMED'), true)
                if not IsEntityPlayingAnim(ped, anim.dict, anim.clip, 3) then TaskPlayAnim(ped, anim.dict, anim.clip, 4, 4, -1, anim.flag, 0, false, false, false) end
                if IsDisabledControlPressed(0, 24) and not IsPauseMenuActive() and not lib.getOpenContextMenu() and GetGameTimer() >= nextSpray then
                    local sessionId = active.id
                    nextSpray = GetGameTimer() + Config.Washer.tickMs
                    local hit, coords, vehicle = aimRay()
                    if active and active.id == sessionId then
                        SetEntityHeading(ped, GetGameplayCamRot(2).z)
                        waterEffect(GetPlayerServerId(PlayerId()), {x = coords.x, y = coords.y, z = coords.z}, active.foam)
                        local netId = hit and IsEntityAVehicle(vehicle) and NetworkGetEntityIsNetworked(vehicle) and VehToNet(vehicle) or 0
                        TriggerServerEvent('mrw_carwash:spray', sessionId, netId, {x = coords.x, y = coords.y, z = coords.z})
                    end
                end
            end
        end
    end
end)
CreateThread(function()
    while not stopping do
        if not next(effects) then Wait(150) else
            Wait(0)
            for src, effect in pairs(effects) do
                local localPlayer = src == GetPlayerServerId(PlayerId())
                if GetGameTimer() > effect.untilTime or not DoesEntityExist(effect.ped) or localPlayer and not active then effects[src] = nil
                else
                    local start = GetPedBoneCoords(effect.ped, Config.Washer.handBone, 0, 0.15, 0)
                    if localPlayer and gun and DoesEntityExist(gun) then
                        local off = Config.Washer.nozzleOffset
                        start = GetOffsetFromEntityInWorldCoords(gun, off.x, off.y, off.z)
                    end
                    DrawLine(start.x, start.y, start.z, effect.point.x, effect.point.y, effect.point.z,
                        effect.foam and 245 or 180, effect.foam and 245 or 220, 255, 180)
                end
            end
        end
    end
end)
CreateThread(function()
    while not stopping do
        Wait(1000)
        if active and not pending then
            TriggerServerEvent('mrw_carwash:heartbeat', active.id)
            local text = locale('controls', math.ceil(active.water/Config.Washer.waterTicks*100), locale(active.foam and 'mode_foam' or 'mode_water'), math.max(0, math.ceil((active.deadline-GetGameTimer())/1000)), menuBind and menuBind.currentKey or Config.Keys.menu, returnBind and returnBind.currentKey or Config.Keys.returnWasher)
            if Config.UI.showHud and text ~= hud then hud = text lib.showTextUI(text, {position = Config.UI.hudPosition, icon = 'faucet'}) end
        end
        for entity in pairs(appliedDirt) do if not DoesEntityExist(entity) then appliedDirt[entity] = nil end end
        for _, vehicle in ipairs(GetGamePool('CVehicle')) do
            local dirt = Entity(vehicle).state['mrw_carwash:dirt']
            if type(dirt) == 'table' and Carwash.finite(dirt.level) and Carwash.finite(dirt.revision) and NetworkHasControlOfEntity(vehicle) then
                if appliedDirt[vehicle] ~= dirt.revision then
                    SetVehicleDirtLevel(vehicle, math.max(0, math.min(15, dirt.level)))
                    if dirt.level <= 0 then WashDecalsFromVehicle(vehicle, 1.0) end
                    appliedDirt[vehicle] = dirt.revision
                end
            else appliedDirt[vehicle] = nil end
        end
    end
end)
CreateThread(function()
    while not stopping do
        Wait(500)
        local seen = {}
        local localPed = PlayerPedId()
        for _, player in ipairs(GetActivePlayers()) do
            if player ~= PlayerId() then
                local src, ped = GetPlayerServerId(player), GetPlayerPed(player)
                if Player(src).state['mrw_carwash:equipped'] == true and not IsEntityDead(ped)
                    and #(GetEntityCoords(localPed) - GetEntityCoords(ped)) <= Config.Washer.effectDistance then
                    seen[src] = true
                    local entry = remoteGuns[src]
                    if entry and (entry.ped ~= ped or not DoesEntityExist(entry.object)) then
                        removeHose(src)
                        if DoesEntityExist(entry.object) then DeleteEntity(entry.object) end
                        remoteGuns[src] = nil
                    end
                    if not remoteGuns[src] then
                        local hash = model(Config.Washer.gunModel)
                        if hash then
                            local p = GetEntityCoords(ped)
                            local object = CreateObjectNoOffset(hash, p.x, p.y, p.z, false, false, false)
                            if object ~= 0 then
                                local off, rot = Config.Washer.gunOffset, Config.Washer.gunRotation
                                SetEntityCollision(object, false, false)
                                AttachEntityToEntity(object, ped, GetPedBoneIndex(ped, Config.Washer.handBone), off.x, off.y, off.z, rot.x, rot.y, rot.z, true, true, false, true, 1, true)
                                remoteGuns[src] = {object = object, ped = ped}
                            end
                            SetModelAsNoLongerNeeded(hash)
                        end
                    end
                end
            end
        end
        for src, entry in pairs(remoteGuns) do
            if not seen[src] then
                removeHose(src)
                if DoesEntityExist(entry.object) then DeleteEntity(entry.object) end
                remoteGuns[src], effects[src] = nil, nil
            end
        end
    end
end)
CreateThread(function()
    while not stopping do
        local desired = {}
        if active and gun and DoesEntityExist(gun) then
            desired[GetPlayerServerId(PlayerId())] = {station = active.station, gun = gun}
        end
        for src, entry in pairs(remoteGuns) do
            local station = Player(src).state['mrw_carwash:station']
            if type(station) == 'number' and Config.locations[station] then
                desired[src] = {station = station, gun = entry.object}
            end
        end
        for src, target in pairs(desired) do
            local hose = hoses[src]
            if hose and (hose.station ~= target.station or hose.gun ~= target.gun
                or type(DoesRopeExist) ~= 'function' or not DoesRopeExist(hose.rope)) then
                removeHose(src)
                hose = nil
            end
            if not hose then
                createHose(src, target.station, target.gun)
            elseif GetGameTimer() - hose.lastAdjust >= 500 and type(RopeForceLength) == 'function' then
                local start, finish = hosePoints(target.station, target.gun)
                if start and finish then
                    local length = math.min(Config.Washer.hoseLength,
                        math.max(1.0, #(finish - start) + Config.Washer.hoseSlack))
                    pcall(RopeForceLength, hose.rope, length)
                    hose.lastAdjust = GetGameTimer()
                else
                    removeHose(src)
                end
            end
        end
        for src in pairs(hoses) do if not desired[src] then removeHose(src) end end
        Wait(250)
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    stopping = true
    release(true)
    removeAllHoses()
    if lib.progressActive() and preparing then lib.cancelProgress() end
    for _, entry in pairs(remoteGuns) do if DoesEntityExist(entry.object) then DeleteEntity(entry.object) end end
    if lib.getOpenContextMenu() == 'mrw_carwash_menu' then lib.hideContext(false) end
    for index in pairs(stands) do deleteStand(index) end
    for _, blip in ipairs(blips) do RemoveBlip(blip) end
    RemoveNamedPtfxAsset(Config.Washer.particleDict)
    RemoveAnimDict(anim.dict)
end)

