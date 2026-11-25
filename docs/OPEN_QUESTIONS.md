# Nyitott kérdések

- Flutter 3.50.1 és Dart 3.14.0 rögzítve. Az első Windows x64 és Android 35 x86_64 próba átment. A támogatott architektúrák Windows x64 és Android ARM64. Nyitott a konkrét fizikai Android eszközök köre és a csomagolt megszakítási próba.
- A Drive élő próba Google Cloud projektje, platformonkénti OAuth-konfigurációja és a játékosmegosztás nyitott. [ADR-0002](decisions/ADR-0002-local-stories-and-cloud-storage.md)
- A [logikai modell](requirements/DOMAIN_MODEL.md) jóváhagyott. Nyitott a végleges fájlséma, a séma verziózása és migrációja, az azonosítók konkrét formátuma és a történeti hivatkozások kezelése tervmódosításkor.
- A jelenethez rendelhető, kötetlen sorrendű mérföldkövek javasoltak a logikai modellben. Nyitott, hogy szükséges-e előfeltételeket kezelni.
- A Drive fájlverzióhoz kötött írás és az élő kétklienses próba nyitott. A konfliktusfeloldás viselkedése jóváhagyva. A CORE helyi revízióban őrzi a feloldás előtti távoli pillanatképet és a helyi revízió hivatkozását. Nyitott a megőrzési idő és a felületi visszaállítás menete. [UC-005](requirements/USE_CASES.md#uc-005)
- A [narratív kampányértékelő](IMPLEMENTATION_PLAN.md#narratív-kampányértékelő) opcionális LLM-jéhez az OpenAI az első szolgáltatójelölt. Nyitott az adatkezelés, az API-hozzáférés és a költség. A ChatGPT felület és az alkalmazásból hívott API számlázása külön működik. [OpenAI számlázási útmutató](https://help.openai.com/en/articles/9039756-managing-billing-for-chatgpt-and-the-api-platform)
- Discord küldési hibák, ismételt publikáció.
- Session- és kalandszintű összefoglalók eltérései.
- Saját licenc és üzleti modell. A nyilvános terjesztési csatorna, a pontos buildeszközök feltételei és a tényleges platformcsomagok licencleltára a [licencelési átvilágítás](LICENSING_FEASIBILITY.md) alapján ellenőrzendő.
- Pontos lokalizációs követelmények.
- Támogatott Windows- és Android-verziók, valamint a játékközbeni műveletek esetleges mérhető használhatósági célértékei (NFR-001, NFR-002, NFR-004).
