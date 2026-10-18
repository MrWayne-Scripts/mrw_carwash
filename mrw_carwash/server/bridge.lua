Bridge = {}
local inventory = exports.ox_inventory
local framework
local frameworkName = Config.Framework
if frameworkName == 'auto' then
    if GetResourceState('es_extended') == 'started' then frameworkName = 'esxlegacy'
    elseif GetResourceState('qb-core') == 'started' then frameworkName = 'qbcore'
    else frameworkName = 'standalone' end
end
if Config.Payment.provider == 'framework' then
    if frameworkName == 'esxlegacy' then framework = exports.es_extended:getSharedObject()
    elseif frameworkName == 'qbcore' then framework = exports['qb-core']:GetCoreObject()
    else error('Framework payments require a running ESX or QBCore; use inventory payments for standalone') end
end
function Bridge.charge(src, price)
    local cost = price or Config.Payment.cost
    if cost == 0 then return true end
    if Config.Payment.provider == 'inventory' then
        return inventory:RemoveItem(src, Config.Payment.item, cost) == true
    end
    local player = frameworkName == 'esxlegacy' and framework.GetPlayerFromId(src) or framework.Functions.GetPlayer(src)
    if not player then return false end
    for _, account in ipairs(Config.Payment.accounts) do
        if frameworkName == 'esxlegacy' then
            local balance = player.getAccount(account)
            if balance and balance.money >= cost then player.removeAccountMoney(account, cost, 'Pressure wash') return true end
        elseif (player.Functions.GetMoney(account) or 0) >= cost then
            if player.Functions.RemoveMoney(account, cost, 'pressure-wash') then return true end
        end
    end
    return false
end
function Bridge.findTool(src, requestedSlot)
    if not Config.Inventory.required then return {slot = 0, metadata = {durability = 100}} end
    local slots = requestedSlot and {inventory:GetSlot(src, requestedSlot)} or inventory:Search(src, 'slots', Config.Inventory.tool) or {}
    for _, item in pairs(slots) do
        if item and item.name == Config.Inventory.tool and item.count == 1 then
            local durability = item.metadata and item.metadata.durability or 100
            -- Timestamp-based degradation is deliberately unsupported for this reusable tool.
            if Carwash.finite(durability) and durability <= 100 and durability >= Config.Inventory.wearPerTick then return item end
        end
    end
end
function Bridge.toolValid(src, session)
    if not Config.Inventory.required then return true end
    local item = inventory:GetSlot(src, session.slot)
    if not item or item.name ~= Config.Inventory.tool or item.count ~= 1 then return false end
    local durability = item.metadata and item.metadata.durability or 100
    return Carwash.finite(durability) and durability <= 100 and durability >= Config.Inventory.wearPerTick
end
function Bridge.wear(src, session)
    if not Config.Inventory.required then return end
    local item = inventory:GetSlot(src, session.slot)
    local durability = math.max(0, (item.metadata.durability or 100) - Config.Inventory.wearPerTick)
    inventory:SetDurability(src, session.slot, durability)
end
function Bridge.soap(src)
    return inventory:RemoveItem(src, Config.Inventory.soap, 1) == true
end
