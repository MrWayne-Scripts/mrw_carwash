local root=arg[1] or 'mrw_carwash'
function vector3(x,y,z) return {x=x,y=y,z=z} end
lib={locale=function() end}
dofile(root..'/config.lua')
dofile(root..'/shared/core.lua')
local n=0
local function check(ok,msg) assert(ok,msg) n=n+1 end
local accounts, debits, qbFail = {},{},false
local esxPlayer={
 getAccount=function(name) return accounts[name] and {money=accounts[name]} end,
 removeAccountMoney=function(name,cost) accounts[name]=accounts[name]-cost debits[#debits+1]=name end,
}
local qbPlayer={Functions={
 GetMoney=function(name) return accounts[name] end,
 RemoveMoney=function(name,cost)
  if qbFail then return false end
  accounts[name]=accounts[name]-cost debits[#debits+1]=name return true
 end,
}}
exports={
 ox_inventory={},
 es_extended={getSharedObject=function() return {GetPlayerFromId=function() return esxPlayer end} end},
 ['qb-core']={GetCoreObject=function() return {Functions={GetPlayer=function() return qbPlayer end}} end},
}
function GetResourceState(name) return name=='es_extended' and 'started' or 'missing' end
Config.Payment.provider='framework'
Config.Framework='auto'
dofile(root..'/server/bridge.lua')
accounts={money=0,bank=100}
check(Bridge.charge(7),'ESX bank fallback')
check(accounts.money==0 and accounts.bank==70 and debits[1]=='bank','ESX never overdraws cash')
accounts={money=100,bank=100}
check(Bridge.charge(7) and accounts.money==70 and accounts.bank==100,'ESX cash preferred')
accounts={bank=100}
check(Bridge.charge(7) and accounts.bank==70,'missing account safely skipped')
accounts={money=0,bank=0}
check(not Bridge.charge(7),'insufficient framework funds')
Config.Framework='qbcore';Config.Payment.accounts={'cash','bank'}
dofile(root..'/server/bridge.lua')
accounts={cash=0,bank=100}
check(Bridge.charge(7) and accounts.bank==70,'QBCore bank fallback')
qbFail=true
accounts={cash=100,bank=100}
check(not Bridge.charge(7) and accounts.cash==100 and accounts.bank==100,'QBCore failed debit cannot succeed')
qbFail=false
Config.Payment.cost=0
check(Bridge.charge(7),'free sessions')
Config.Framework='standalone'
check(not pcall(dofile,root..'/server/bridge.lua'),'standalone rejects framework payments')
print(('%d payment adapter assertions passed'):format(n))
