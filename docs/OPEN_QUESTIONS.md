# Nyitott kérdések

- Flutter 3.50.1 és Dart 3.14.0 rögzítve. Az első Windows x64 és Android 35 x86_64 próba átment. Nyitott a fizikai Android célmátrix és a csomagolt megszakítási próba.
- A [technológiai vizsgálat](TECHNOLOGY_FEASIBILITY.md) alapján a GitHub REST az első adapter iránya. Nyitott az éles belépési mód és az adapter próbája.
- A [logikai modell](requirements/DOMAIN_MODEL.md) jóváhagyott. Nyitott a végleges fájlséma, a séma verziózása és migrációja, az azonosítók konkrét formátuma és a történeti hivatkozások kezelése tervmódosításkor.
- A jelenethez rendelhető, kötetlen sorrendű mérföldkövek javasoltak a logikai modellben. Nyitott, hogy az MVP-ben kell-e előfeltételeket kezelni.
- Sync gyakoriság, offline mentés, több fájl konzisztens mentése és a mesélő számára elérhető MVP feloldási út két eszköz eltérő módosításai esetén (UC-005).
- LLM szolgáltató, költség, opcionális működés.
- Discord küldési hibák, ismételt publikáció.
- Session- és kalandszintű összefoglalók eltérései.
- Saját licenc és üzleti modell. A nyilvános terjesztési csatorna, a pontos buildeszközök feltételei és a tényleges platformcsomagok licencleltára a [licencelési átvilágítás](LICENSING_FEASIBILITY.md) alapján ellenőrzendő.
- Pontos lokalizációs követelmények.
- Támogatott Windows- és Android-verziók, valamint a játékközbeni műveletek esetleges mérhető használhatósági célértékei (NFR-001, NFR-002, NFR-004).
