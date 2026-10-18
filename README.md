# Ruční myčka vozidel pro FiveM

Autor: **MrW**

![Stojan a tlaková pistole](assets/previews/mrw_carwash_props.png)

Hráč si u stojanu vezme tlakovou pistoli a sám umyje vozidlo. Hadice vede od
stojanu k pistoli, na zemi má vůli a při pohybu se průběžně přizpůsobuje její
délka. Stojan i pistole mají vlastní červenočerné 3D modely.

Mytí odstraňuje běžnou špínu vozidel v GTA V. Spotřebovává vodu a opotřebovává
pistoli z ox_inventory; šampon přidá dočasný bonus k čištění. Pro interakce
slouží ox_target a nabídky, klávesy i stavový panel zajišťuje ox_lib.

## Instalace

Resource vyžaduje OneSync, ox_lib, ox_target a ox_inventory. Postup instalace,
včetně položek do inventáře a pořadí spuštění, je v [návodu](docs/INSTALLATION.md).
Výchozí stanice, účtování, klávesy a chování mytí upravíš v
[config.lua](mrw_carwash/config.lua); přehled možností je v
[dokumentaci konfigurace](docs/CONFIGURATION.md).

## Součásti

- ruční tlakové mytí s rezervací místa a serverově ověřovanou platbou;
- vybavení a jeho životnost vedené přes ox_inventory;
- volitelný šampon, který se spotřebuje při zapnutí;
- vlastní model stojanu a pistole včetně volně vedené hadice;
- české a anglické texty a ikony inventářových položek;
- platební adaptéry pro ox_inventory, ESX Legacy a QBCore.

Podrobnosti o interním API a zdrojových modelech najdeš v
[dokumentaci vývoje](docs/DEVELOPMENT.md) a [části věnované modelům](assets/README.md).
Změny od předchozí verze jsou v [changelogu](CHANGELOG.md).

## Stav verze

Aktuální tag je `v3.0.0-rc.2`. Automatické kontroly kódu a převodu modelů jsou
zdokumentované v [testovacím přehledu](docs/TESTING.md). Resource ani vzhled
modelů zatím nebyly ověřené na živém FXServeru a GTA klientovi; před ostrým
nasazením je potřeba projít herní scénáře.
