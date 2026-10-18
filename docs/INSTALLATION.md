# Instalace

## Předpoklady

- FiveM FXServer s OneSync a GTA V Legacy / Gen8 assets.
- Funkční `ox_lib`, `ox_inventory` a `ox_target`, včetně jejich vlastních závislostí.
- Funkční databáze a framework bridge vyžadovaný tvou instalací ox_inventory.
  Zdejší „standalone“ znamená bez dalšího ESX/QBCore platebního adaptéru;
  neznamená to, že ox_inventory nevyžaduje vlastní backend.
- Výchozí ekonomika používá inventářový předmět `money`. Ověř jeho existenci.

Používej vzájemně kompatibilní vydání ox resources. Kontrakty byly čteny proti
upstream `overextended/ox_inventory` (`488aa6d754dfbf7d169f355ccbd647dc60c5ec3a`)
a `overextended/ox_lib` (`1f87a022ca430370c02f7ce10807a2803bf596e5`).
To není doklad skutečného herního testu těchto verzí.

## Postup

1. Zálohuj nastavení a zastav původní carwash. Nespouštěj starou a novou verzi současně.
2. Zkopíruj **vnitřní** složku `mrw_carwash` mezi serverové resources. Název ponech
   `mrw_carwash`; inventářová definice na něj odkazuje exportem.
3. Do návratové tabulky `ox_inventory/data/items.lua` přidej položky z
   [`install/items.lua`](../install/items.lua). Tento soubor je fragment tabulky,
   nikoli samostatný resource. Nenahrazuj celý existující soubor položek.
4. Zkopíruj oba PNG z [`install/images`](../install/images) do
   `ox_inventory/web/images/`. Názvy obrázků odpovídají názvům předmětů.
5. Zajisti získání pistole a šamponu. Volitelný obchod je ve fragmentu
   [`install/shop.lua`](../install/shop.lua); ceny a souřadnice přizpůsob ekonomice.
   Myčka sama nevytváří inventářové vybavení ani nepřidává obchod automaticky.
6. Restartuj ox_inventory podle jeho instalačních pravidel, aby načetl položky.
7. Nastav `config.lua`, včetně přesné polohy stojanů na tvém MLO/mapě.
8. Spusť závislosti a resource; proveď scénáře v [TESTING.md](TESTING.md).

Příklad části `server.cfg` (framework/databázi spouštěj podle své instalace):

```cfg
set onesync on
ensure ox_lib
# zde databáze/framework a ostatní předpoklady ox_inventory
ensure ox_inventory
ensure ox_target
ensure mrw_carwash
```

## Platby

Výchozí `Config.Payment.provider = 'inventory'` odebere cenu pomocí
`ox_inventory:RemoveItem`. `Config.Payment.item` musí být skutečná měna používaná
serverem. Není potřeba zvláštní přístup k ESX/QBCore účtům.

Pro účty nastav `provider = 'framework'` a framework `esxlegacy` nebo `qbcore`
(případně `auto`). ESX hotovost se běžně jmenuje `money`, QBCore `cash`.
Celá částka se strhne z prvního účtu s dostatečným zůstatkem. Účty se nesčítají.
QBCore platební adaptér neznamená podporu QBCore v libovolné distribuci ox_inventory;
kompatibilní inventory bridge musí zajistit provozovatel serveru.

Poplatek se strhne až při potvrzení vyzvednutí po načtení a vytvoření modelu.
Neaktivovaná rezervace vyprší za 15 sekund bez poplatku. Aktivovaná relace má
časový limit z konfigurace. Poplatek není vratná záloha; vrácení, výpadek sítě,
smrt ani restart nemají automatický refund. Není implementován platební deník
s obnovou po pádu celého procesu/serveru.

## Řešení problémů

| Projev | Ověření |
| --- | --- |
| Resource se nespustí | OneSync, všechny tři ox závislosti a chyby konfigurace v konzoli. |
| Chybí stojan/pistole | Obě `.ydr` a `.ytyp` v `stream`, `DLC_ITYP_REQUEST` v manifestu a cache klienta. |
| Pistole nejde vyzvednout | Inventářová definice, životnost > 0, peníze, kapacita, bucket a vzdálenost. |
| Ikona inventáře chybí | PNG v `ox_inventory/web/images` a restart/obnova inventory UI. |
| Inventář předmět smaže při použití | Musí být `consume = 0`, `stack = false`, bez `degrade` a s `durability = true`. |
| Nesprávné držení | Doladit `gunOffset` a `gunRotation` při zachování správné polohy trysky. |
| Špína se vrací okamžitě | Jiný dirt resource může průběžně přepisovat nativní úroveň špíny. |
| Mytí za rohem nefunguje | Záměrná kontrola druhým raycastem z ústí pistole. |
| Standalone nefunguje | Nejprve zprovoznit framework/backend požadovaný samotným ox_inventory. |
| Stojan plave nebo překáží | Ověřit souřadnice vůči skutečné mapě, kolizi a natočení. |

Pro diagnostiku zapni `Config.Debug`. Logy obsahují ID relace a stanice;
neobsahují inventářové obsahy ani přihlašovací údaje.
