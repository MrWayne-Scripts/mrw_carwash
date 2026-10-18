# Testování a připravenost

## Provedené automatické kontroly

Z kořene repozitáře s Lua 5.4:

```bash
lua5.4 tests/server_spec.lua
lua5.4 tests/bridge_spec.lua
lua5.4 tests/client_spec.lua
```

V připraveném cloudu je Lua na `/workspace/.carwash-tools/lua/usr/bin/lua5.4`.
Celkem 263 kontrol: 237 server/core, 9 platebních adaptérů a 17 klientského
životního cyklu. Část serverových kontrol ověřuje vlastnosti monotónnosti čištění
na různých vstupních úrovních; číslo není počtem nezávislých herních scénářů.

Ověřené větve zahrnují rezervaci bez platby, selhání modelu, zrušení přípravy,
opakované potvrzení, nedostatek peněz, konkurenci o stojan, vypnuté stanice, individuální a nulové ceny, neměnnou cenu rezervace, nastavení UI, blokaci inventářového
slotu, spotřebu a životnost, šampon jednou, neplatné eventy, stale ID, routing bucket,
smrt, odpojení, heartbeat, vypršení času, výpadek platebního adaptéru a resource stop.
Testy načítají skutečný Lua kód s náhradami nativních funkcí a ox API. Neběží v GTA.

Modely byly z XML zkompilovány přes nemodifikovaný CodeWalker.Core a znovu načteny.
Převodník ověřuje LODy, textury včetně mipů, mesh buffery, kolizi stojanu a dvě
archetypové definice. Postup je v [assets](../assets/README.md).

125 kontrol balení, lokalizací a assetů lze spustit příkazem `python3 tests/package_spec.py`.

## Povinný herní test před vydáním — dosud NEPROVEDENÝ

Použij testovací FXServer, existující ox stack, dva GTA/FiveM klienty a zálohu ekonomiky.
Zaznamenej verze artifacts/resources, konfiguraci, počet hráčů a výsledek každého bodu.

| Oblast | Scénáře a očekávání |
| --- | --- |
| Modely | Všechny tři stojany viditelné, správný ground Z a natočení, funkční kolize a target. |
| Držení | Pravá ruka drží rukojeť, tryska míří dopředu, proud vychází z ústí; doladit offsety. |
| Inventář | Ikony, použití itemu u stojanu, odmítnutí mimo stojan, nulová/poškozená životnost. |
| Vyzvednutí | Zrušení bez poplatku, úspěch s jednou platbou, plný stojan bez platby. |
| Platby | Správný currency item nebo hotovost/banka dle konfigurace; nemíchat providery. |
| Šampon | Jedna dávka na relaci, chybějící dávka bez boostu, rychlejší čištění. |
| Mytí | Zásah špinavého auta, smytí do nuly, decals, střik do prázdna a na čisté auto. |
| Překážky | Kamera za rohem nestačí, voda nesmí legitimnímu klientovi projít pevnou zdí. |
| Více hráčů | Oba vidí pistoli a efekty; čištění cizího vozidla, předání vlastníka. |
| Buckety | Hráč v jiném bucketu nepoužije stojan ani neuvidí jeho efekty. |
| Kapacita | Dva souběžné požadavky na poslední místo: aktivuje se jen jeden. |
| Inventář aktivně | Darování, drop, stash, výměna slotu a swap z jiného inventáře se odmítnou. |
| Úklid | Smrt, vozidlo, konec dosahu, konec vody, konec času, konec životnosti. |
| Síť | Ztráta heartbeatů, pozdní odpověď callbacku, odpojení/reconnect, odstreamování hráče. |
| Restart | Resource stop/start bez osiřelých propů, blipů a targetů; inventory nástroj zůstává. |
| Konflikty | Jiné TextUI/menu, změna kláves, další dirt resource, jiná ekonomika. |
| Výkon | resmon klienta v idle/aktivně a server profiler při očekávaném počtu hráčů. |

Bez těchto výsledků nepoužívej označení „otestováno ve hře“, „bez chyb“,
„ověřeno pro 128 hráčů“ ani srovnávací marketingové tvrzení o kvalitě ostatních scriptů.
