# Krónikás – Projektkoncepció v0.1

## Cél
Rendszerfüggetlen narratív RPG kaland- és kampánymenedzser GM-eknek, one-shot és többalkalmas kalandokhoz. Nem mechanikai szabálykezelő. Windows és Android, közös állapot, minimális adminisztráció, ember által olvasható adatok, saját backend lehetőség szerinti kerülése. A szoftver nem birtokolja a kalandokat, hanem kezeli azokat.

## Munkafolyamat
A GM előkészíti a leírást, jeleneteket, mérföldköveket, lehetséges kimeneteleket, opcionális eseményeket, jegyzeteket és titkokat. A mérföldkövek nem lineárisak. Játék közben státuszokat, tényleges kimeneteleket, improvizált eseményeket és jegyzeteket rögzít. A session lezárható a kaland lezárása nélkül; a következő alkalom az aktuális állapotból folytatódik.

A tényleges eseményekből olvasható narratív összefoglaló készül, opcionális LLM segítségével. Az AI nem találhat ki eseményt, nem változtathat kimenetelt, nem fedhet fel titkot és nem kezelhet kihagyott jelenetet megtörténtként. Csak publikálható információt kap. A GM szerkeszt és jóváhagy; az összefoglaló menthető és Discord webhookkal publikálható.

## Logikai adatmodell
Campaign, Adventure, Session, Scene, Milestone, Milestone Outcome, Session Event, GM Note, Narrative Summary. Egy kampány több kalandból, egy kaland több sessionből állhat. Eredeti terv, aktuális állapot és eseménytörténet külön kezelendő. Nem szükséges teljes Event Sourcing.
Mérföldkő státuszjavaslat: Pending, Completed, Partially Completed, Failed, Skipped; szöveges kimenetellel. A státusz nem feltétlen végleges, sikertelen mérföldkőhöz vissza lehet térni.

## Tárolás és szinkronizáció
A valódi kalandok a termék repójától elkülönített Git repositorykban vannak. A távoli repo a szinkronizált állapot hiteles forrása; konfigurálható repo és könyvtár, rugalmas struktúra. Példa: campaign.json, Adventure-001/adventure.json, state.json, sessions/session-001.json, summaries/session-001.md. One-shot külön is tárolható. JSON és Markdown javasolt, nem végleges séma. Kaland felismerhető adventure.json alapján.
Megnyitáskor friss állapot lekérése, automatikus lokális mentés és távoli sync, manuális sync lehetősége. Offline a letöltött kaland használható, változások később szinkronizálhatók. Elavult állapot felismerése, nincs csendes felülírás, lokális változások megőrzése, hiba/konfliktus jelzése. A független módosításokat a Krónikás egyesíti. Tényleges ütközésnél a mesélő dönt, és az eredeti változatok visszaállíthatók. A Git-műveletek a GM számára lehetőleg láthatatlanok.

## Technológia és architektúra (javaslat)
Flutter, .NET MAUI, PWA vizsgálandó; Flutter kezdeti preferencia. Natív Git vs GitHub REST API, utóbbi egyszerűbb kiindulásként vizsgálandó. Lokális JSON/cache, SQLite csak indokolt esetben. Presentation → Application CORE → Storage, Summary, Publishing modulok. CORE: kampány, kaland, session, mérföldkő, kimenetel, eseménytörténet, validáció, üzleti logika. UI és szolgáltatók függetlenek a CORE-tól. Tokenek, API-kulcsok és webhook URL-ek biztonságos tárolása, nem a kalandfájlokban vagy repóban.

## Hatókörön kívül
Karakterlap, kockadobás, harcrendszer, initiative tracker, rendszer-specifikus szabályok, automatikus GM, VTT, interaktív harci térkép, tokenek/miniatűrök, valós idejű multiplayer, játékosi fiókok/komplex jogosultság, saját központi adatbázisszerver.

## Az alkalmazás elfogadási kritériumai
Windows alatt kaland előkészítése és Git-tárolása; Androidon megnyitás, mérföldkövek és kimenetelek rögzítése, automatikus mentés/sync; Windows alatt friss állapot folytatása; tényleges eseményekből összefoglaló, ellenőrzés/jóváhagyás és Discord publikáció. Saját backend nélkül, ha megvalósítható.

A koncepció nem végleges implementációs specifikáció. Lásd a követelményeket, roadmapet és nyitott kérdéseket.
