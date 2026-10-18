# Změny

## 3.0.0-rc.1

- Ruční tlakové mytí místo původní automatické myčky.
- Původní vlastní modely MRW stojanu a pistole, Gen8 YDR/YTYP, vložené DDS a LODy.
- ox_inventory nástroj s životností, šampon, blokace přesunu používaného slotu.
- ox_target interakce a ox_lib callbacky, menu, oznámení, progress a nápověda.
- Neplacená rezervace a následná idempotentní aktivace s jedním poplatkem.
- Kapacita stojanů, routing buckety, serverové limity a pravidelný úklid.
- Lokální repliky drženého nástroje a distribuce efektů jen hráčům poblíž.
- Čeština/angličtina, inventářové definice/ikony, zdrojové modely a dokumentace.
- Podrobný český config: ceny a zapnutí jednotlivých stanic, měna, klávesy a rozhraní.
- Automatické testy serveru, platebních adaptérů a klientského životního cyklu.

### Migrace z 1.x / pracovního 2.x

Konfigurace se změnila: původní ploché `cost`, `cash_account_name`, `double_clean`,
`button` a `show_all_blips` se nepoužívají. Nepřenášej starý config bez úprav.
Framework API se přesunulo do `server/bridge.lua`; staré `framework.lua` a `server.lua`
byly odstraněny. Inventářové předměty je nutné přidat podle instalace.
Původní `carwash:DoVehicleWashParticles` a `carwash:CanPurchaseCarWash` byly odstraněny.
