Carwash = {}
function Carwash.finite(value)
    return type(value) == 'number' and value == value and math.abs(value) < 1000000
end
function Carwash.integer(value, min, max)
    return Carwash.finite(value) and value % 1 == 0 and value >= min and value <= max
end
function Carwash.point(point)
    return type(point) == 'table' and Carwash.finite(point.x) and Carwash.finite(point.y) and Carwash.finite(point.z)
end
function Carwash.nextDirt(current, boost)
    return math.max(0, math.min(15, current) - Config.Washer.dirtPerTick * (boost and Config.Foam.multiplier or 1))
end
function Carwash.validateConfig()
    assert(Config.Locale == 'cs' or Config.Locale == 'en', 'Unsupported Config.Locale')
    assert(Carwash.integer(Config.Payment.cost, 0, 1000000), 'Invalid session price')
    assert(Config.Payment.provider == 'inventory' or Config.Payment.provider == 'framework', 'Invalid payment provider')
    assert(Config.Framework == 'auto' or Config.Framework == 'esxlegacy' or Config.Framework == 'qbcore' or Config.Framework == 'standalone', 'Invalid framework')
    assert(Carwash.integer(Config.Washer.tickMs, 100, 5000), 'tickMs must be 100..5000')
    assert(Carwash.integer(Config.Washer.waterTicks, 1, 10000), 'Invalid waterTicks')
    assert(Carwash.integer(Config.Washer.sessionSeconds, 10, 86400), 'Invalid sessionSeconds')
    assert(Carwash.finite(Config.Washer.range) and Config.Washer.range > 0 and Config.Washer.range <= 20, 'Invalid spray range')
    assert(Carwash.finite(Config.Washer.radius) and Config.Washer.radius >= Config.Washer.range and Config.Washer.radius <= 100, 'Invalid hose radius')
    assert(Carwash.finite(Config.Washer.dirtPerTick) and Config.Washer.dirtPerTick > 0 and Config.Washer.dirtPerTick <= 15, 'Invalid dirtPerTick')
    assert(Carwash.finite(Config.Inventory.wearPerTick) and Config.Inventory.wearPerTick > 0 and Config.Inventory.wearPerTick <= 100, 'Invalid tool wear')
    assert(Config.Inventory.tool ~= Config.Inventory.soap and Config.Inventory.tool ~= Config.Payment.item and Config.Inventory.soap ~= Config.Payment.item, 'Tool, soap and currency must be different items')
    assert(Carwash.finite(Config.Foam.multiplier) and Config.Foam.multiplier >= 1 and Config.Foam.multiplier <= 5, 'Invalid soap multiplier')
    assert(Carwash.finite(Config.Washer.targetDistance) and Config.Washer.targetDistance > 0 and Config.Washer.targetDistance <= 5, 'Invalid target distance')
    assert(Carwash.integer(Config.Washer.pickupMs, 0, 10000), 'Invalid pickup duration')
    assert(Carwash.finite(Config.Washer.effectDistance) and Config.Washer.effectDistance >= Config.Washer.range and Config.Washer.effectDistance <= 200, 'Invalid effect distance')
    assert(Carwash.finite(Config.Washer.hoseSlack) and Config.Washer.hoseSlack >= 0 and Config.Washer.hoseSlack <= 10, 'Invalid hose slack')
    assert(Carwash.finite(Config.Washer.hoseLength) and Config.Washer.hoseLength >= Config.Washer.radius + Config.Washer.hoseSlack and Config.Washer.hoseLength <= 100, 'Invalid hose length')
    assert(Carwash.integer(Config.Washer.hoseType, 0, 7), 'Invalid GTA rope type')
    assert(type(Config.Washer.hoseData) == 'string' and #Config.Washer.hoseData > 0 and #Config.Washer.hoseData <= 64, 'Invalid GTA rope preset')
    assert(type(Config.Payment.accounts) == 'table' and #Config.Payment.accounts > 0, 'Missing payment accounts')
    for _, name in ipairs({Config.Payment.item, Config.Inventory.tool, Config.Inventory.soap, Config.Washer.standModel, Config.Washer.gunModel}) do
        assert(type(name) == 'string' and #name > 0, 'Missing item or model name')
    end
    assert(type(Config.Payment.symbol) == 'string' and #Config.Payment.symbol <= 12, 'Invalid currency display symbol')
    for _, anchor in ipairs({Config.Washer.hoseStandAnchor, Config.Washer.hoseGunAnchor}) do
        assert(anchor and Carwash.finite(anchor.x) and Carwash.finite(anchor.y) and Carwash.finite(anchor.z), 'Invalid hose anchor')
    end
    assert(type(Config.Keys.menu) == 'string' and #Config.Keys.menu > 0 and type(Config.Keys.returnWasher) == 'string' and #Config.Keys.returnWasher > 0, 'Invalid keyboard bindings')
    local hudPositions = {['right-center']=true, ['left-center']=true, ['top-center']=true, ['bottom-center']=true}
    local notifyPositions = {top=true, bottom=true, ['top-right']=true, ['top-left']=true, ['bottom-right']=true, ['bottom-left']=true, ['center-right']=true, ['center-left']=true}
    assert(hudPositions[Config.UI.hudPosition], 'Invalid HUD position')
    assert(notifyPositions[Config.UI.notificationPosition], 'Invalid notification position')
    assert(Config.UI.progressPosition == 'bottom' or Config.UI.progressPosition == 'middle', 'Invalid progress position')
    assert(type(Config.UI.showHud) == 'boolean', 'Invalid HUD toggle')
    local ids = {}
    assert(#Config.locations > 0 and #Config.locations <= 100, 'Configure between 1 and 100 stations')
    for _, station in ipairs(Config.locations) do
        assert(type(station.id) == 'string' and station.id:match('^[%w_-]+$') and not ids[station.id], 'Station IDs must be unique and contain no spaces')
        assert(station.enabled == nil or type(station.enabled) == 'boolean', 'Invalid station enabled flag')
        assert(station.showBlip == nil or type(station.showBlip) == 'boolean', 'Invalid station blip flag')
        assert(station.price == nil or Carwash.integer(station.price, 0, 1000000), 'Invalid station price')
        assert(Carwash.integer(station.capacity, 1, 10), 'Invalid station capacity')
        assert(Carwash.integer(station.bucket, 0, 2147483647), 'Invalid station routing bucket')
        assert(station.location and Carwash.finite(station.location.x) and Carwash.finite(station.location.y) and Carwash.finite(station.location.z), 'Invalid station coordinates')
        assert(Carwash.finite(station.heading), 'Invalid station heading')
        ids[station.id] = true
    end
end
Carwash.validateConfig()
lib.locale(Config.Locale)
