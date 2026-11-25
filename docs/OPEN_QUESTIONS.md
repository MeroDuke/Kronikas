# Nyitott kérdések

- Flutter 3.50.1 és Dart 3.14.0 rögzítve. Az első Windows x64 és Android 35 x86_64 próba átment. A támogatott architektúrák Windows x64 és Android ARM64. Nyitott a konkrét fizikai Android eszközök köre és a csomagolt megszakítási próba.
- A [technológiai vizsgálat](TECHNOLOGY_FEASIBILITY.md) alapján a GitHub REST az első adapter iránya. A szerver nélküli GitHub App device flow felülete kipróbálható a helyi demóban. A GitHub App regisztrációja és az élő felületi próba nyitott. [Beállítás](../platform_probe/README.md)
- A [logikai modell](requirements/DOMAIN_MODEL.md) jóváhagyott. Nyitott a végleges fájlséma, a séma verziózása és migrációja, az azonosítók konkrét formátuma és a történeti hivatkozások kezelése tervmódosításkor.
- A jelenethez rendelhető, kötetlen sorrendű mérföldkövek javasoltak a logikai modellben. Nyitott, hogy szükséges-e előfeltételeket kezelni.
- A szinkron gyakorisága, az offline mentés és a több fájlt érintő mentés szabályai. A konfliktusfeloldás viselkedése jóváhagyva. A CORE helyi revízióban őrzi a feloldás előtti távoli pillanatképet és a helyi revízió hivatkozását. Nyitott a megőrzési idő és a felületi visszaállítás menete. [UC-005](requirements/USE_CASES.md#uc-005)
- LLM szolgáltató, költség, opcionális működés.
- Discord küldési hibák, ismételt publikáció.
- Session- és kalandszintű összefoglalók eltérései.
- Saját licenc és üzleti modell. A nyilvános terjesztési csatorna, a pontos buildeszközök feltételei és a tényleges platformcsomagok licencleltára a [licencelési átvilágítás](LICENSING_FEASIBILITY.md) alapján ellenőrzendő.
- Pontos lokalizációs követelmények.
- Támogatott Windows- és Android-verziók, valamint a játékközbeni műveletek esetleges mérhető használhatósági célértékei (NFR-001, NFR-002, NFR-004).
