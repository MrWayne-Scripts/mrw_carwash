# Vydání a prodej

Aktuální označení: **3.0.0-rc.1**. Implementace, modely a automatické kontroly jsou
připravené; plné herní ověření zatím chybí. Neexistuje technická kontrola, která by
zaručila nulový počet chyb nebo porovnala tento resource s 99 % komunitních scriptů.

Před stabilním vydáním:

1. Proveď a zaznamenej celou herní matici z `TESTING.md`, zejména modely a multiplayer.
2. Dolaď skutečné offsety ruky a souřadnice na podporované mapě.
3. Ověř podporované verze FXServeru a ox stacku; zveřejni konkrétní rozsah podpory.
4. Proveď profilování s očekávaným počtem hráčů a uveď naměřené podmínky.
5. Uzavři potvrzené chyby, znovu spusť ovlivněné testy a sestav nový balíček.
6. Označ stabilní verzi, zabal konzistentní Lua kód/modely/dokumentaci a vytvoř checksum.
7. Připrav produktový návod, kontakt pro podporu a přehled známých omezení.

Konfigurace, lokalizace a platební adaptér jsou v manifestu uvedeny v `escrow_ignore`.
To pouze připravuje editovatelné cesty pro případné použití FiveM Asset Escrow;
nevytváří ani nepublikuje escrow, obchod či produkt. Žádné vzdálené licenční kontroly,
telemetrie, webhooky ani automatické aktualizace tento resource neobsahuje.

Prodávaný popis má odpovídat dodanému chování: standardní GTA špína, šamponový bonus,
pevná stočená hadice a vlastní modely. Lokální vrstvy bláta, fyzikální hadice ani
ověřená integrace s 17Movement nejsou součástí této verze.
