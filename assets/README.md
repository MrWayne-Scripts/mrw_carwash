# Modely tlakové myčky

Autor modelů: **MrW**

![Render stojanu a pistole](previews/mrw_carwash_props.png)

Render ukazuje modely vytvořené pro tento resource, nejde o snímek ze hry.
Na stojanu není žádný název ani logo. Skříň má červený lak, černé rámy,
ovládací panel, manometr, čtečku a naviják.

- `../mrw_carwash/stream/mrw_pressure_stand.ydr` je model stojanu včetně navijáku,
  části hadice vedené po zemi a koncovky pro připojení volné hadice.
- `../mrw_carwash/stream/mrw_pressure_gun.ydr` obsahuje rukojeť, spoušť, trubici,
  trysku a připojení hadice. Počátek modelu je v dlani, tryska míří po ose `+Y`.
- `../mrw_carwash/stream/mrw_carwash_props.ytyp` registruje oba modely v GTA V.
- `source/mrw_carwash_props.blend` obsahuje upravitelný projekt Blenderu.
- `source/build_models.py` sestaví geometrii, materiály, LODy, kolizi a náhled.
- `source/render_inventory_icons.py` z projektu vykreslí ikony inventáře.
- `export/` obsahuje XML modelů a původní textury použité při sestavení.

Krátká hadice na stojanu končí u země. Při používání resource připojí volnou
část k pistoli fyzika lan ve hře; její délka se průběžně upravuje s pohybem hráče.
Stojan má zjednodušenou kolizi, pistole kolizi nemá. Oba modely mají vysoký,
střední i nízký LOD a vložené BC1 textury, takže nevyžadují samostatný texture
dictionary.

Modely jsou sestavené pro GTA V Legacy (Gen8). Jejich počty trojúhelníků jsou
uvedené v `model_metrics.json`.

## Sestavení modelů

Pro přegenerování je potřeba Blender 4.3.2, Sollumz `e6278bc441289ecaf3e034755f730b729a48e035`,
`szio==1.4.0.dev2`, .NET SDK 8.0.426 a nemodifikovaný CodeWalker.Core
`485d56bec00262ed7fa472261cce7bbc6202b96e`. Závislosti se do resource
nepřibalují. Sollumz běží v Blenderu; CodeWalker převede exportované XML
na herní soubory.

Nastav `MRW_ASSET_TOOLS` na adresář s checkoutem Sollumz a složkou `python/`,
kde je nainstalované szio. Potom spusť z kořene repozitáře:

```bash
blender -b --factory-startup -t 4 --python-exit-code 1 --python assets/source/build_models.py
dotnet build assets/tools/Converter.csproj -c Release -p:CodeWalkerRoot=/path/to/CodeWalker
dotnet assets/tools/bin/Release/net8.0/Converter.dll assets/export/mrw_pressure_stand.ydr.xml assets/export/mrw_pressure_gun.ydr.xml assets/export/mrw_carwash_props.ytyp.xml
cp assets/export/mrw_pressure_stand.ydr assets/export/mrw_pressure_gun.ydr assets/export/mrw_carwash_props.ytyp mrw_carwash/stream/
```

Převodník při sestavení znovu otevře vytvořené soubory a zkontroluje geometrii,
LOD, textury i kolizi stojanu. Přiložené modely jsou offline ověřené; jejich
streamování, kolizi, hadici a natočení pistole je stále potřeba vyzkoušet ve hře.
