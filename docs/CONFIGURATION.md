# Nastavení a ovládání

Všechny produktové volby jsou v `mrw_carwash/config.lua`. Změny vyžadují restart
resource, který ukončí probíhající relace. Před restartem upozorni hráče.

| Skupina | Význam |
| --- | --- |
| `Locale` | `cs` / `en`; ox_lib načte příslušný JSON s anglickým fallbackem. |
| `Debug` | Výpis začátků a ukončení relací do serverové konzole. |
| `Framework` | `auto`, `esxlegacy`, `qbcore`, `standalone`; pro platby přes účty. |
| `Payment.provider` | `inventory` nebo `framework`. |
| `Payment.item` | Jméno měnového předmětu u inventářové platby. |
| `Payment.accounts` | Seznam účtů v pořadí preference; u QBCore typicky `{'cash', 'bank'}`. |
| `Payment.cost` | Výchozí cena; celé nezáporné číslo, `0` znamená zdarma. |
| `Payment.symbol` | Znak měny v targetu; pouze vzhled. |
| `Inventory.required` | Zda je nutná vlastněná pistole; závislost na ox_inventory zůstává. |
| `Inventory.tool` | Nestohovatelná pistole, `consume = 0`, číselná životnost 0–100. |
| `Inventory.soap` | Předmět spotřebovaný při aktivaci šamponu. |
| `Inventory.wearPerTick` | Opotřebení za platný střik; kontroluje a zapisuje server. |
| `Washer.radius` | Maximální vzdálenost hráče od stojanu (metry). |
| `Washer.range` | Dosah proudu. Server připouští 0,75 m pro polohu ruky/trysky. |
| `Washer.tickMs` | Interval střiků; server toleruje 25 ms síťového kolísání. |
| `Washer.dirtPerTick` | Úbytek standardní GTA špíny (škála 0–15). |
| `Washer.sessionSeconds` | Maximální délka aktivované relace. |
| `Washer.waterTicks` | Počet platných střiků; počítají se i střiky mimo auto a na čisté auto. |
| `Washer.pickupMs` | Délka zrušitelné přípravy u stojanu před rezervací. |
| `Washer.targetDistance` | Dosah interakce ox_target. |
| `Washer.effectDistance` | Dosah distribuce vizuálních efektů kolem zásahu. |
| `Washer.animation` | Slovník, klip a flag animace držení. |
| `Washer.standModel/gunModel` | Vlastní modely přiložené v resource. |
| `Washer.gunOffset/gunRotation` | Posun a natočení vůči pravé ruce; doladit ve hře. |
| `Washer.nozzleOffset` | Lokální ústí trysky; dodaný model používá `(0, 0.745, 0.078)`. |
| `Foam.enabled` | Povolí spotřebu šamponu přes menu. |
| `Foam.multiplier` | Násobič čištění po spotřebování jedné dávky na relaci. |
| `Keys.menu/returnWasher` | Výchozí klávesy menu a ukončení; UI zobrazuje skutečné přemapované klávesy. |
| `UI.showHud` | Vypnutí/zapnutí stavové nápovědy. |
| `UI.hudPosition` | `right-center`, `left-center`, `top-center`, `bottom-center`. |
| `UI.notificationPosition` | Umístění oznámení ox_lib, výchozí `top-right`. |
| `UI.progressPosition` | `bottom` / `middle`. |
| `Blips` | Ikona, barva, velikost a viditelnost značek. |

Každá stanice má unikátní `id`, `name`, `location`, `heading`, `capacity` a `bucket`.
Výchozí kapacita je jeden hráč. `enabled = false` vypne stanici včetně modelu a značky, `showBlip = false` skryje jen značku. `price = nil` použije společnou cenu, `price = 0` je zdarma; jiná hodnota přepíše cenu pro tuto stanici. Cena se na serveru zachytí při rezervaci a pozdější změna configu ji zpětně nezmění. Rezervace se do kapacity počítá ihned; neaktivovaná
vyprší po 15 s. `bucket` omezuje použití serverem. Stojany a blipy jsou vizuálně
vytvořeny na všech klientech; samotné zobrazení není oprávněním použít jiný bucket.
Není implementováno dynamické vytváření instancí ani editor stanic ve hře.

## Hráč

- Pořiď si inventářovou pistoli. U stojanu zvol vyzvednutí přes ox_target,
  nebo použij pistoli z inventáře v dosahu stojanu.
- Přípravu můžeš zrušit; peníze se strhnou až po úspěšném vytvoření pistole.
- Drž levé tlačítko myši a zamiř na vozidlo. Voda i životnost ubývají při střiku.
- `G`: menu se šamponem a ukončením. Jedna dávka funguje do konce relace.
- `X`: okamžité ukončení; pistoli lze vrátit také přes target.
- Zobrazené množství vody je kapacita relace, ne inventářový předmět.
- Inventářový nástroj zůstane po ukončení v inventáři se zbývající životností.
  Během používání ho nelze přes ox_inventory přesunout ani darovat.

Klávesy `G` a `X` lze změnit ve FiveM nastavení kláves. Nápověda a úvodní oznámení používají aktuální klávesy vrácené ox_lib, včetně hráčského přemapování.

Časová degradace `metadata.durability > 100` není podporována; nepřidávej `degrade`
k definici pistole. Rozbitou pistoli může spravovat existující ekonomika serveru
pomocí dokumentovaného `ox_inventory:SetDurability`. Resource sám nástroj neopravuje.
