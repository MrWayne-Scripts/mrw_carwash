-- Client lifecycle contracts with native/UI stubs. Rendering still requires FiveM.
local root=arg[1] or 'mrw_carwash'
local n=0
local function check(ok,msg) assert(ok,msg) n=n+1 end
local vector={}
vector.__sub=function(a,b) return setmetatable({x=a.x-b.x,y=a.y-b.y,z=a.z-b.z},vector) end
vector.__len=function(a) return math.sqrt(a.x*a.x+a.y*a.y+a.z*a.z) end
function vector3(x,y,z) return setmetatable({x=x,y=y,z=z},vector) end
local handlers,events,threads,targets,keybinds,public,serverEvents={},{},{},{},{},{},{}
local objects,nextObject,progressResult,modelOk,createOk={},100,true,true,true
local callbacks,charges,notifications={},0,{}
local uiOpen,uiText=false,nil
local pedDead,inVehicle=false,false
local function returned(id)
 for _,event in ipairs(serverEvents) do if event[1]=='mrw_carwash:return' and event[2]==id then return true end end
 return false
end
function GetGameTimer() return 1000 end
function Wait(ms) coroutine.yield(ms) end
function CreateThread(fn) threads[#threads+1]=coroutine.create(fn) end
function RegisterNetEvent(name,fn) events[name]=fn end
function AddEventHandler(name,fn) handlers[name]=fn end
function TriggerServerEvent(...) serverEvents[#serverEvents+1]={...} end
function GetCurrentResourceName() return 'mrw_carwash' end
function GetResourceState() return 'started' end
function PlayerPedId() return 1 end
function PlayerId() return 0 end
function GetPlayerServerId() return 7 end
function GetEntityCoords() return Config.locations[1].location end
function joaat(value) return value end
function IsModelInCdimage() return modelOk end
function RequestModel() end
function HasModelLoaded() return modelOk end
function RequestAnimDict() end
function HasAnimDictLoaded() return true end
function SetModelAsNoLongerNeeded() end
function CreateObjectNoOffset()
 if not createOk then return 0 end
 nextObject=nextObject+1;objects[nextObject]=true return nextObject
end
function DoesEntityExist(object) return objects[object]==true end
function DeleteEntity(object) objects[object]=nil end
function StopAnimTask() end
function HasPedGotWeapon() return true end
function SetCurrentPedWeapon() end
function GetSelectedPedWeapon() return 123 end
function SetEntityCollision() end
function GetPedBoneIndex() return 57005 end
function AttachEntityToEntity() end
function SetEntityHeading() end
function PlaceObjectOnGroundProperly() end
function FreezeEntityPosition() end
function SetEntityInvincible() end
function AddBlipForCoord() return 1 end
function SetBlipSprite() end
function SetBlipColour() end
function SetBlipScale() end
function SetBlipAsShortRange() end
function BeginTextCommandSetBlipName() end
function AddTextComponentString() end
function EndTextCommandSetBlipName() end
function RemoveBlip() end
function RequestNamedPtfxAsset() end
function HasNamedPtfxAssetLoaded() return true end
function RemoveNamedPtfxAsset() end
function RemoveAnimDict() end
function IsPedInAnyVehicle() return inVehicle end
function IsEntityDead() return pedDead end
local target={}
function target:addLocalEntity(object,options) targets[object]=options end
function target:removeLocalEntity(object) targets[object]=nil end
exports=setmetatable({ox_target=target,ox_inventory={useItem=function(_,data,cb) cb(true) end}},
 {__call=function(_,name,fn) public[name]=fn end})
function locale(key,...) return key end
lib={
 locale=function() end,
 notify=function(data) notifications[#notifications+1]=data.description end,
 isTextUIOpen=function() return uiOpen,uiText end,
 hideTextUI=function() uiOpen=false end,
 showTextUI=function(text) uiOpen,uiText=true,text end,
 progressActive=function() return false end,
 progressCircle=function() return progressResult end,
 registerContext=function() end,showContext=function() end,getOpenContextMenu=function() return nil end,
 addKeybind=function(binding) keybinds[binding.name]=binding end,
 callback={await=function(name,_,...) return callbacks[name](...) end},
}
dofile(root..'/config.lua')
dofile(root..'/shared/core.lua')
Config.Blips.enabled=false
dofile(root..'/client.lua')
check(coroutine.resume(threads[1]),'stand startup')
local options
for _,entry in pairs(targets) do if entry[1].name=='mrw_carwash_take_strawberry' then options=entry end end
check(options and #options==3,'take/menu/return target entries')
local serial=0
callbacks['mrw_carwash:take']=function()
 serial=serial+1
 return {ok=true,session={id='test'..serial,station=1,water=100,foam=false,seconds=15,confirmed=false}}
end
callbacks['mrw_carwash:confirm']=function(id)
 charges=charges+1
 return {ok=true,session={id=id,station=1,water=100,foam=false,seconds=600,confirmed=true}}
end
progressResult=false
options[1].onSelect()
check(serial==0 and charges==0,'cancelled progress cannot reserve or charge')
progressResult=true
modelOk=false
options[1].onSelect()
check(serial==0 and charges==0,'asset failure cannot reserve or charge')
modelOk=true
createOk=false
options[1].onSelect()
check(serial==1 and charges==0 and returned('test1'),'object creation failure returns unpaid reservation')
createOk=true
options[1].onSelect()
check(charges==1 and not options[1].canInteract(),'successful confirm equips gun')
check(options[3].canInteract(),'return enabled while active')
events['mrw_carwash:release']('old-session','expired')
check(not options[1].canInteract(),'stale release cannot remove active gun')
uiOpen,uiText=true,'another resource'
keybinds.mrw_carwash_return.onPressed()
check(options[1].canInteract() and returned('test2'),'hotkey returns session')
check(uiOpen,'does not hide another resource text UI')
options[1].onSelect()
check(charges==2,'new rental confirmation')
pedDead=true
check(coroutine.resume(threads[2]),'start active update')
check(coroutine.resume(threads[2]),'update death cleanup')
check(options[1].canInteract(),'death clears client equipment')
pedDead=false
callbacks['mrw_carwash:take']=function() error('network timeout') end
options[1].onSelect()
check(options[1].canInteract(),'callback failure clears pending state')
callbacks['mrw_carwash:take']=function()
 handlers.onResourceStop('mrw_carwash')
 return {ok=true,session={id='late',station=1,water=100,foam=false,seconds=15}}
end
options[1].onSelect()
check(returned('late'),'late callback after stop returns reservation')
check(next(objects)==nil and next(targets)==nil,'stop deletes all local props and targets')
print(('%d client lifecycle assertions passed'):format(n))
