-- Pure Lua regression tests. Mocks simulate API contracts, not the FiveM game engine.
local root = arg[1] or 'mrw_carwash'
local passed = 0
local function check(value, message)
    assert(value, message)
    passed = passed + 1
end
local vector = {}
vector.__sub = function(a,b) return setmetatable({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z},vector) end
vector.__len = function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
function vector3(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
local callbacks, events, handlers, threads, publicExports = {}, {}, {}, {}, {}
local now, wallTime = 10000, 1700000000
local positions, health, buckets, insideVehicle, players, states, inventories = {}, {}, {}, {}, {}, {}, {}
local nativeDirt, dirtState, messages, debitCalls, worn = 15, nil, {}, 0, 0
local hook
local resources = {ox_inventory='started',ox_lib='started',ox_target='started'}
local function inventory(src) inventories[src] = inventories[src] or {} return inventories[src] end
local function item(name,count,slot,durability) return {name=name,count=count,slot=slot,metadata={durability=durability}} end
local function seed(src, durability)
    positions[src]=Config.locations[1].location
    health[src],buckets[src],insideVehicle[src]=200,0,0
    players[src] = true
    inventories[src]={[1]=item(Config.Inventory.tool,1,1,durability or 100),[2]=item('money',1000,2),[3]=item(Config.Inventory.soap,2,3)}
end
local ox = {}
function ox:Search(src, mode, name)
    local result={}
    for _, value in pairs(inventory(src)) do if value.name==name then result[#result+1]=value end end
    return result
end
function ox:GetSlot(src, slot) return inventory(src)[slot] end
function ox:RemoveItem(src,name,count)
    debitCalls=debitCalls+1
    for slot, value in pairs(inventory(src)) do
        if value.name==name and value.count>=count then
            value.count=value.count-count
            if value.count==0 then inventory(src)[slot]=nil end
            return true
        end
    end
    return false
end
function ox:SetDurability(src,slot,value) inventory(src)[slot].metadata.durability=value worn=worn+1 end
function ox:registerHook(_,fn) hook=fn return 'test-hook' end
exports=setmetatable({ox_inventory=ox},{__call=function(_,name,fn) publicExports[name]=fn end})
lib={locale=function() end, callback={register=function(name,fn) callbacks[name]=fn end}}
function GetResourceState(name) return resources[name] or 'missing' end
function GetCurrentResourceName() return 'mrw_carwash' end
function RegisterNetEvent(name,fn) events[name]=fn end
function AddEventHandler(name,fn) handlers[name]=fn end
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function Wait(ms) coroutine.yield(ms) end
function GetGameTimer() return now end
function GetPlayerPed(src) return players[src] and src or 0 end
function GetEntityCoords(entity) return entity==999 and vector3(25,-1391,29) or positions[entity] end
function GetEntityHealth(src) return health[src] end
function GetVehiclePedIsIn(src) return insideVehicle[src] end
function GetPlayerRoutingBucket(src) return buckets[src] or 0 end
function GetEntityRoutingBucket() return 0 end
function NetworkGetEntityFromNetworkId(id) return id==99 and 999 or 0 end
function DoesEntityExist(entity) return entity==999 or players[entity]==true end
function GetEntityType() return 2 end
function GetVehicleDirtLevel() return nativeDirt end
function GetPlayers() local list={} for src in pairs(players) do list[#list+1]=tostring(src) end return list end
function Player(src)
    states[src]=states[src] or {}
    return {state={set=function(_,key,value) states[src][key]=value end}}
end
function Entity() return {state={set=function(_,key,value) dirtState=value end}} end
function TriggerClientEvent(name,target,...) messages[#messages+1]={name=name,target=target,args={...}} end
local originalTime=os.time
os.time=function() return wallTime end

dofile(root..'/config.lua')
dofile(root..'/shared/core.lua')
dofile(root..'/server/bridge.lua')
dofile(root..'/server/main.lua')
local function advance(ms) now=now+ms end
local function take(src, station, slot)
    advance(1600)
    local result=callbacks['mrw_carwash:take'](src,station or 1,slot)
    if result.ok then return callbacks['mrw_carwash:confirm'](src,result.session.id) end
    return result
end
local function session(src) return publicExports.GetSession(src) end
local function event(src,name,...) source=src events['mrw_carwash:'..name](...) end
local hit={x=25,y=-1391,z=29}
local function spray(src,netId,point,id)
    advance(Config.Washer.tickMs)
    event(src,'heartbeat',session(src) and session(src).id or 'none')
    event(src,'spray',id or session(src).id,netId or 99,point or hit)
end
local function endSession(src)
    local s=session(src)
    if s then event(src,'return',s.id) end
end

seed(7);seed(8)
local reserved=callbacks['mrw_carwash:take'](7,1)
check(reserved.ok and not reserved.session.confirmed,'unpaid reservation')
check(inventory(7)[2].count==1000,'reservation does not charge')
check(not (states[7] and states[7]['mrw_carwash:equipped']),'reservation is not public equipment')
local reservedWater=session(7).water
event(7,'spray',reserved.session.id,99,hit)
check(session(7).water==reservedWater and dirtState==nil,'unconfirmed session cannot wash')
event(7,'return',reserved.session.id)
check(not session(7) and inventory(7)[2].count==1000,'failed model return costs nothing')

local result=take(7)
check(result.ok,'inventory-backed pickup')
check(inventory(7)[2].count==970,'single currency debit')
check(states[7]['mrw_carwash:equipped']==true,'replicated equip flag')
check(callbacks['mrw_carwash:confirm'](7,result.session.id).ok,'confirmation is idempotent')
check(inventory(7)[2].count==970,'confirmation cannot double charge')
check(not take(7).ok,'duplicate pickup')
check(inventory(7)[2].count==970,'duplicate must not charge')
check(take(8).error=='station_busy','station capacity')
check(inventory(8)[2].count==1000,'busy station must not charge')
check(hook({fromInventory=7,fromSlot=inventory(7)[1]})==false,'cannot drop active tool')
check(hook({toInventory=7,toSlot=inventory(7)[1],fromInventory=8,fromSlot=inventory(8)[2]})==false,'cannot swap into active slot')
check(hook({fromInventory=7,fromSlot=inventory(7)[2]})~=false,'other inventory items usable')
spray(7)
check(math.abs(dirtState.level-14.65)<0.0001,'native dirt reduced')
check(session(7).water==Config.Washer.waterTicks-1,'water decremented')
check(inventory(7)[1].metadata.durability<100,'tool wears')
local revision=dirtState.revision
local water=session(7).water
event(7,'spray',session(7).id,99,hit)
check(dirtState.revision==revision and session(7).water==water,'same-frame spam rejected')
local foam=callbacks['mrw_carwash:foam'](7,session(7).id)
check(foam.ok and inventory(7)[3].count==1,'one shampoo consumed')
advance(1600)
check(callbacks['mrw_carwash:foam'](7,session(7).id).ok and inventory(7)[3].count==1,'shampoo idempotent')
spray(7)
check(math.abs(dirtState.level-(14.65-.35*Config.Foam.multiplier))<0.0001,'shampoo boost')
revision=dirtState.revision
water=session(7).water
for _,invalid in ipairs({{x=0/0,y=0,z=0},{x=math.huge,y=0,z=0},{x='25',y=0,z=0},{x=10000,y=0,z=0}}) do spray(7,99,invalid) end
check(dirtState.revision==revision and session(7).water==water,'malformed/distant points rejected')
spray(7,99,hit,'stale-session')
check(dirtState.revision==revision,'stale session token rejected')
spray(7,88)
check(dirtState.revision==revision,'unknown vehicle rejected')
local oldWater=session(7).water
spray(7,0)
check(session(7).water==oldWater-1 and dirtState.revision==revision,'spraying air consumes supply only')
buckets[7]=1
spray(7)
check(not session(7),'routing bucket change ends session')
check(states[7]['mrw_carwash:equipped']==false,'equip flag cleared')
check(hook({fromInventory=7,fromSlot=inventory(7)[1]})~=false,'item unlocked after end')
check(take(7).error=='out_of_range','wrong station bucket cannot rent')
buckets[7]=0
inventory(7)[2].count=0
check(take(7).error=='no_money','insufficient currency')
inventory(7)[2].count=1000
inventory(7)[1].metadata.durability=0
check(take(7).error=='tool_missing','broken tool rejected')
inventory(7)[1].metadata.durability=wallTime+10000
check(take(7).error=='tool_missing','timestamp durability rejected')
inventory(7)[1].metadata.durability=100
health[7]=0
check(take(7).error=='out_of_range','dead player rejected')
health[7]=200;insideVehicle[7]=999
check(take(7).error=='out_of_range','seated player rejected')
insideVehicle[7]=0
check(take(7,1,400).error=='tool_missing','invalid tool slot rejected')
advance(1600)
check(callbacks['mrw_carwash:take'](7,1.5).error=='invalid_station','fractional station rejected')
check(callbacks['mrw_carwash:take'](7,1).error=='rate_limit','pickup rate limit')
check(take(7).ok,'rent again')
local prior=session(7).id
wallTime=wallTime+Config.Washer.sessionSeconds+1
spray(7)
check(not session(7),'session expiry')
check(take(7).ok,'new session after expiry')
event(7,'return',prior)
check(session(7)~=nil,'stale return cannot end newer session')
endSession(7)
check(take(8).ok,'station released for next player')
health[8]=0
for _,thread in ipairs(threads) do check(coroutine.resume(thread),'start housekeeping') check(coroutine.resume(thread),'run housekeeping') end
check(not session(8),'housekeeping ends dead sessions')
health[8]=200
check(take(8).ok,'rent after death reset')
inventory(8)[1]=nil
spray(8)
check(not session(8),'external inventory removal ends session')
seed(8)
check(take(8).ok,'reset inventory')
wallTime=wallTime+1
source=8;handlers.playerDropped()
check(not session(8),'disconnect cleanup')
players[8]=nil
seed(7)
check(take(7).ok,'rent for depletion test')
for i=1,Config.Washer.waterTicks do spray(7,0) end
check(not session(7),'supply exhaustion ends rental')
check(inventory(7)[1].metadata.durability>0,'normal use does not instantly destroy tool')
check(take(7).ok,'rent for complete clean test')
for i=1,50 do spray(7) end
check(dirtState.level==0,'dirt clamps at zero')
check(dirtState.level>=0,'no negative dirt')
local count=0
for _,message in ipairs(messages) do if message.name=='mrw_carwash:cleaned' then count=count+1 end end
check(count==1,'clean completion notified once')
publicExports.EndSession(7)
check(not session(7),'server API end session')
check(take(7).ok,'rent for resource stop')
handlers.onResourceStop('mrw_carwash')
check(not session(7) and dirtState==nil,'resource stop clears session and dirt state')
-- Provisional leases and heartbeats cannot strand a station after a client failure.
advance(1600)
local unconfirmed=callbacks['mrw_carwash:take'](7,1)
check(unconfirmed.ok,'reserve for timeout test')
local beforeMoney=inventory(7)[2].count
wallTime=wallTime+16
for _,thread in ipairs(threads) do check(coroutine.resume(thread),'reservation housekeeping') end
check(not session(7) and inventory(7)[2].count==beforeMoney,'unconfirmed timeout has no payment')
check(take(7).ok,'reserve for heartbeat timeout')
advance(16000)
for _,thread in ipairs(threads) do check(coroutine.resume(thread),'heartbeat housekeeping') end
check(not session(7),'missing heartbeat releases station')
check(take(7).ok,'reserve for no shampoo test')
inventory(7)[3]=nil
check(callbacks['mrw_carwash:foam'](7,session(7).id).error=='no_soap','missing shampoo rejected')
check(not session(7).foam,'missing shampoo does not boost')
inventory(7)[1].metadata.durability='broken'
event(7,'heartbeat',session(7).id)
advance(350)
event(7,'spray',session(7).id,0,hit)
check(not session(7),'malformed external item metadata safely ends session')
seed(7)
local originalCharge=Bridge.charge
Bridge.charge=function() error('provider stopped') end
check(take(7).error=='connection_error' and not session(7),'payment provider exception clears reservation')
Bridge.charge=originalCharge
check(take(7).ok,'provider exception cannot leave lock stuck')
endSession(7)
-- Per-station economics are captured by the server at reservation time.
seed(7)
Config.locations[1].enabled=false
check(take(7).error=='out_of_range','disabled station cannot reserve')
check(inventory(7)[2].count==1000,'disabled station cannot charge')
Config.locations[1].enabled=true
Config.locations[1].price=65
advance(1600)
local priced=callbacks['mrw_carwash:take'](7,1)
check(priced.ok and priced.session.price==65,'per-station price exposed')
Config.locations[1].price=999
check(callbacks['mrw_carwash:confirm'](7,priced.session.id).ok,'reserved price confirms')
check(inventory(7)[2].count==935,'server captures immutable reservation price')
endSession(7)
Config.locations[1].price=0
check(take(7).ok and inventory(7)[2].count==935,'zero station price is free, not fallback')
endSession(7)
Config.locations[1].price=nil
local badPrice=-1
Config.locations[1].price=badPrice
check(not pcall(Carwash.validateConfig),'negative station price rejected')
Config.locations[1].price=nil
local oldHud=Config.UI.hudPosition
Config.UI.hudPosition='not-a-position'
check(not pcall(Carwash.validateConfig),'invalid UI configuration rejected')
Config.UI.hudPosition=oldHud
-- Core boundary/property checks, including configuration rejection.
check(not Carwash.integer(0/0,0,1),'NaN integer rejected')
check(not Carwash.integer(math.huge,0,100),'infinite integer rejected')
check(not Carwash.point({x=1,y=2}),'incomplete impact rejected')
for i=0,150 do
 local level=Carwash.nextDirt(i/10,true)
 check(level>=0 and level<=15 and level<=i/10,'dirt monotonic and bounded')
end
local oldCost=Config.Payment.cost
Config.Payment.cost=-1
check(not pcall(Carwash.validateConfig),'invalid cost fails startup')
Config.Payment.cost=oldCost
os.time=originalTime
print(('%d server/core assertions passed'):format(passed))
