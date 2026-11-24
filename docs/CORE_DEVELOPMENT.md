# Dart CORE fejlesztés – IMP-001–003

A tiszta Dart csomag publikus belépési pontja a `core/lib/kronikas_core.dart`. A `Chronicle` kezeli a kampányt, az önálló vagy kampányhoz tartozó kalandot, a jeleneteket, a mérföldköveket, a mesélői jegyzeteket és a játékalkalmakat. A mérföldkő rögzítése együtt frissíti az aktuális állapotot és az eseménytörténetet. Egy kalandhoz egyszerre egy nyitott alkalom tartozhat. Az azonosítókat és időpontokat a hívó adja meg.

## Helyi mentés

A `local_chronicle_store.dart` adapter `open()` művelete a legutóbbi mentést nyitja meg. A helyi alkalmazás a módosítást az `update((chronicle) { ... })` hívásban végzi. Az adapter betölti a legutóbbi mentést, lefuttatja a szinkron műveletet, és a tartós mentés után tér vissza. Egy folyamatban ugyanaz az isolate kezelje az adott mentési könyvtár írásait. A folyamatok között fájlzár védi a mentést, sikertelen zárfoglaláskor a művelet hibával tér vissza.

A séma első verziója egy olvasható JSON-pillanatkép. A kampány és kaland azonosítója a tárolón, a jelenet, mérföldkő, alkalom és esemény azonosítója a kalandon belül értelmezett, saját entitástípusán belül. A tervezett kimenetel azonosítója a mérföldkőhöz tartozik. A hivatkozások stabil azonosítóra mutatnak. A mérföldkő aktuális állapota az eseménytörténet sorrendjéből áll helyre. A séma mintája a `core/test/fixtures/chronicle_v1.json`. Ismeretlen séma vagy hibás mentés olvasási hibát eredményez, és a fájl megmarad.

A mentési commitpont az új, sorszámozott revízióra történő átnevezés ugyanazon a fájlrendszeren, a tartalom flusholása után. A félbemaradt átmeneti könyvtár nem része a mentési történetnek. A korábbi revíziók megmaradnak. A megőrzési szabály és a fizikai eszközön végzett megszakítási próba későbbi feladat.

## Futtatás

A repó gyökerében, PowerShell 7.2 vagy újabb környezetben futtasd az alábbi parancsot. A Dart SDK elérhető lehet a PATH-on vagy a `-Dart` paraméterrel megadott helyen.

```powershell
pwsh -NoProfile -File tool/test.ps1
```

A futtató ellenőrzi a Dart verzióját, a lockfile-t, a formázást és a statikus elemzést. A CORE tesztek a publikus belépési ponton ellenőrzik a kampány és a one-shot előkészítését, a nemlineáris kimeneteleket és a játékalkalmak közti folytonosságot, valamint a hibás műveletek hatását. A függőségek feloldása offline történik. Minden futás külön JSON-jelentést és lépésnaplókat ír a `build/test-results` könyvtárba. A kilépési kód 0 siker, 1 teszt- vagy kódellenőrzési hiba, 2 infrastruktúra- vagy eredményhiba, 3 érvénytelen konfiguráció. A Windows CI ugyanezt a parancsot futtatja, és hiba esetén is megőrzi a létrejött jelentéseket.

## Ellenőrzött eszközkészlet

| Összetevő | Pontos verzió és licenc | Alkalmazás |
|---|---|---|
| Flutter | 3.50.1, framework és engine BSD-3-Clause | Rögzített platformos jelölt. A motor csomagolt összetevőit és notice-ait az IMP-004 ellenőrzi. [Framework](https://github.com/flutter/flutter/blob/3.50.1/LICENSE) · [Engine](https://github.com/flutter/flutter/blob/3.50.1/engine/src/flutter/LICENSE) |
| Dart | 3.14.0, BSD-3-Clause | A Flutter 3.50.1-hez tartozó verzió. A CORE CI önálló SDK-archívumot használ, rögzített SHA-256 ellenőrzéssel. [SDK-licenc](https://github.com/dart-lang/sdk/blob/3.14.0/LICENSE) · [Flutter archívum](https://docs.flutter.dev/install/archive) |
| GitHub Actions | checkout v6 és upload-artifact v7, a workflow-ban rögzített commitokon, MIT | Csak CI-ban használt eszközök. [Checkout licenc](https://github.com/actions/checkout/blob/d23441a48e516b6c34aea4fa41551a30e30af803/LICENSE) · [Artifact licenc](https://github.com/actions/upload-artifact/blob/cf430e030ddbb5b0abf93d22962f4752f3646cd9/LICENSE) |

Az ellenőrzött CORE lockfile csomaglistája üres. A termékcsomag, platformos buildeszközök és terjesztési feltételek auditja az IMP-004 része. A géppel olvasható verziót és az archívum hashét a `tool/sdk.json` tartalmazza.
