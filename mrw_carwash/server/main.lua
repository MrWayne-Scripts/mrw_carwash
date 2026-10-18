local sessions, lastRequest, vehicleDirt, locks = {}, {}, {}, {}
local nextSession, revision = 0, 0
local inventory = exports.ox_inventory
local function reply(error) return {ok = false, error = error} end
local function eligible(src, station, distance)
    local ped = GetPlayerPed(src)
    return station.enabled ~= false and ped ~= 0 and GetEntityHealth(ped) > 0 and GetVehiclePedIsIn(ped, false) == 0
        and GetPlayerRoutingBucket(src) == station.bucket
        and #(GetEntityCoords(ped) - station.location) <= distance
end
local function snapshot(session)
    return {id = session.id, station = session.station, water = session.water, foam = session.foam,
        seconds = math.max(0, session.expires - os.time()), confirmed = session.confirmed, price = session.price}
end
local function finish(src, reason)
    local session = sessions[src]
    if not session then return end
    sessions[src] = nil
    Player(src).state:set('mrw_carwash:station', nil, true)
    Player(src).state:set('mrw_carwash:equipped', false, true)
    TriggerClientEvent('mrw_carwash:release', src, session.id, reason or 'returned')
    if Config.Debug then print(('[mrw_carwash] session=%s end=%s'):format(session.id, reason or 'returned')) end
end
local function validSession(src, id, allowPending)
    local session = sessions[src]
    if not session or session.id ~= id then return nil end
    if os.time() >= session.expires then finish(src, 'expired') return nil end
    if session.confirmed and GetGameTimer() - session.heartbeat > 15000 then finish(src, 'connection_error') return nil end
    if not allowPending and not session.confirmed then return nil end
    if not eligible(src, Config.locations[session.station], Config.Washer.radius) then finish(src, 'out_of_range') return nil end
    if not Bridge.toolValid(src, session) then finish(src, 'tool_missing') return nil end
    return session
end
lib.callback.register('mrw_carwash:take', function(src, stationIndex, requestedSlot)
    local now = GetGameTimer()
    if locks[src] or lastRequest[src] and now - lastRequest[src] < 1500 then return reply('rate_limit') end
    lastRequest[src] = now
    if not Carwash.integer(stationIndex, 1, #Config.locations) then return reply('invalid_station') end
    if requestedSlot ~= nil and not Carwash.integer(requestedSlot, 1, 1000) then return reply('tool_missing') end
    if sessions[src] then return reply('already_active') end
    local station = Config.locations[stationIndex]
    if not eligible(src, station, Config.Washer.targetDistance + 0.75) then return reply('out_of_range') end
    local occupied = 0
    for other, session in pairs(sessions) do
        if session.station == stationIndex then
            if session.expires <= os.time() or not eligible(other, station, Config.Washer.radius) then finish(other, 'expired')
            else occupied = occupied + 1 end
        end
    end
    if occupied >= station.capacity then return reply('station_busy') end
    local tool = Bridge.findTool(src, requestedSlot)
    if not tool then return reply('tool_missing') end
    nextSession = nextSession + 1
    local session = {id = ('%d:%d:%d'):format(os.time(), src, nextSession), station = stationIndex,
        slot = tool.slot, price = station.price or Config.Payment.cost, water = Config.Washer.waterTicks, foam = false,
        confirmed = false, heartbeat = now, expires = os.time() + 15, lastHit = now - Config.Washer.tickMs, lastFoam = now - 1500}
    sessions[src] = session
    if Config.Debug then print(('[mrw_carwash] session=%s start station=%s'):format(session.id, station.id)) end
    return {ok = true, session = snapshot(session)}
end)
lib.callback.register('mrw_carwash:confirm', function(src, id)
    if locks[src] then return reply('rate_limit') end
    local session = validSession(src, id, true)
    if not session then return reply('no_session') end
    if session.confirmed then return {ok = true, session = snapshot(session)} end
    locks[src] = true
    local ok, paid = pcall(Bridge.charge, src, session.price)
    locks[src] = nil
    if not ok then
        print('[mrw_carwash] Payment provider failed; verify its resource and configuration.')
        finish(src, 'connection_error')
        return reply('connection_error')
    end
    if not paid then finish(src, 'no_money') return reply('no_money') end
    session.confirmed, session.heartbeat = true, GetGameTimer()
    session.expires = os.time() + Config.Washer.sessionSeconds
    Player(src).state:set('mrw_carwash:station', session.station, true)
    Player(src).state:set('mrw_carwash:equipped', true, true)
    return {ok = true, session = snapshot(session)}
end)
RegisterNetEvent('mrw_carwash:heartbeat', function(id)
    local session = sessions[source]
    if session and session.id == id and session.confirmed then session.heartbeat = GetGameTimer()
    else TriggerClientEvent('mrw_carwash:release', source, id, 'no_session') end
end)
lib.callback.register('mrw_carwash:foam', function(src, id)
    local session = validSession(src, id)
    if not session then return reply('no_session') end
    local now = GetGameTimer()
    if now - session.lastFoam < 1500 then return reply('rate_limit') end
    session.lastFoam = now
    if not Config.Foam.enabled then return reply('foam_disabled') end
    if session.foam then return {ok = true} end
    if not Bridge.soap(src) then return reply('no_soap') end
    session.foam = true
    TriggerClientEvent('mrw_carwash:status', src, snapshot(session))
    return {ok = true}
end)
RegisterNetEvent('mrw_carwash:return', function(id)
    local session = sessions[source]
    if session and session.id == id then finish(source, 'returned') end
end)
RegisterNetEvent('mrw_carwash:spray', function(id, netId, hit)
    local src = source
    local candidate = sessions[src]
    if not candidate or candidate.id ~= id or not candidate.confirmed then return end
    local now = GetGameTimer()
    if now - candidate.lastHit < Config.Washer.tickMs - 25 then return end
    candidate.lastHit = now -- cheap limiter before inventory/position lookups
    local session = validSession(src, id)
    if not session then return end
    if not Carwash.integer(netId, 0, 2147483647) or not Carwash.point(hit) then return end
    local impact, ped = vector3(hit.x, hit.y, hit.z), GetPlayerPed(src)
    if #(GetEntityCoords(ped) - impact) > Config.Washer.range + 0.75 then return end
    local vehicle, current, dirt
    if netId ~= 0 then
        vehicle = NetworkGetEntityFromNetworkId(netId)
        if vehicle == 0 or not DoesEntityExist(vehicle) or GetEntityType(vehicle) ~= 2 then return end
        if GetEntityRoutingBucket(vehicle) ~= GetPlayerRoutingBucket(src)
            or #(GetEntityCoords(vehicle) - impact) > 6.0 then return end
        current = GetVehicleDirtLevel(vehicle)
        if not Carwash.finite(current) then return end
        local record = vehicleDirt[vehicle]
        if record and record.netId == netId then current = math.min(current, record.dirt) end
        dirt = Carwash.nextDirt(current, session.foam)
    end
    Bridge.wear(src, session)
    session.water = session.water - 1
    if vehicle and current > 0 then
        revision = revision + 1
        vehicleDirt[vehicle] = {netId = netId, dirt = dirt, at = now, revision = revision}
        Entity(vehicle).state:set('mrw_carwash:dirt', {level = dirt, revision = revision}, true)
    end
    -- Send only to nearby players in this routing bucket, not the entire server.
    for _, player in ipairs(GetPlayers()) do
        local target = tonumber(player)
        local targetPed = GetPlayerPed(target)
        if targetPed ~= 0 and GetPlayerRoutingBucket(target) == GetPlayerRoutingBucket(src)
            and #(GetEntityCoords(targetPed) - impact) <= Config.Washer.effectDistance then
            TriggerClientEvent('mrw_carwash:waterImpact', target, src, hit, session.foam)
        end
    end
    TriggerClientEvent('mrw_carwash:status', src, snapshot(session))
    if dirt == 0 and current > 0 then TriggerClientEvent('mrw_carwash:cleaned', src) end
    if session.water <= 0 then finish(src, 'water_empty') end
end)
-- ox_inventory automatically removes this resource's hook on resource stop.
inventory:registerHook('swapItems', function(payload)
    local function blocked(inv, slot)
        local src = tonumber(inv)
        local session = src and sessions[src]
        return session and type(slot) == 'table' and slot.slot == session.slot
    end
    if blocked(payload.fromInventory, payload.fromSlot) or blocked(payload.toInventory, payload.toSlot) then return false end
end, {itemFilter = {[Config.Inventory.tool] = true}})
AddEventHandler('playerDropped', function()
    sessions[source], lastRequest[source], locks[source] = nil, nil, nil
end)
CreateThread(function()
    while true do
        Wait(1000)
        for src, session in pairs(sessions) do validSession(src, session.id, true) end
        for src, at in pairs(lastRequest) do if GetGameTimer() - at > 60000 then lastRequest[src] = nil end end
        for vehicle, record in pairs(vehicleDirt) do
            if not DoesEntityExist(vehicle) then vehicleDirt[vehicle] = nil
            elseif GetGameTimer() - record.at > 10000 then
                Entity(vehicle).state:set('mrw_carwash:dirt', nil, true)
                vehicleDirt[vehicle] = nil
            end
        end
    end
end)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() then return end
    for src in pairs(sessions) do finish(src, 'stopped') end
    for vehicle in pairs(vehicleDirt) do
        if DoesEntityExist(vehicle) then Entity(vehicle).state:set('mrw_carwash:dirt', nil, true) end
    end
end)
exports('GetSession', function(src)
    local session = sessions[src]
    return session and snapshot(session) or nil
end)
exports('EndSession', function(src) finish(src, 'returned') end)
