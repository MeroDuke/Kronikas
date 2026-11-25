# ADR-0002 – Helyi mesék és opcionális felhőtárolás

2026-11-25 · Jóváhagyott termékirány

A Krónikás induláskor a helyi meséket nyitja meg. A mesélő felhőtárhelyet külön kapcsolhat hozzá. Az első cél a saját Windows és Android eszközök közötti folytatás, saját kiszolgáló üzemeltetése nélkül. Első szolgáltatójelölt a Google Drive. A GitHub-adapter és a vele készült próbák a korábbi technológiai vizsgálat részei.

Minden mese saját fájlban tárolható, stabil azonosítóval. Induláskor a kliens először a helyi listát mutatja. Bekapcsolt felhőkapcsolat esetén lekéri a távoli verzióadatokat, és csak a hiányzó vagy megváltozott mesék tartalmát tölti le. Jóváhagyott módosításkor helyben ment, majd kezdeményezi az érintett fájl feltöltését. A függő mentés újraindítás után is megmarad. Ütközésnél egyik példány sem íródhat felül észrevétlenül. Távoli hiány önmagában nem törli a helyi mesét.

Az első próba szintetikus tárolóval is futtatható. Az élő Drive-integrációhoz közös Google Cloud projekt, Drive API, Windows és Android OAuth-konfiguráció szükséges. A végleges felhőadapternek igazolnia kell a két eszköz közötti fájlfelderítést, a szűk jogosultságot és a párhuzamos mentés védelmét. A játékosmegosztás külön döntés.

[UC-002 és UC-005](../TRACEABILITY.md) · [IMP-009](../IMPLEMENTATION_PLAN.md#imp-009) · [TST-012](../TEST_EXECUTION.md#tst-012)

A GitHub-tárolási adapter és belépési demó kikerült az aktív kódból. A korábbi próba a [PR #11-ben](https://github.com/MeroDuke/Kronikas/pull/11) visszakereshető. A szolgáltatótól független konfliktuskezelés, a helyi revíziók és a szintetikus platformtesztek megmaradtak.

## Google Drive megvalósíthatóság

2026-11-25 · Dokumentációs vizsgálat. Élő API-próba még nem futott.

| Terület | Megvalósítás és ellenőrzendő feltétel |
| --- | --- |
| Tárhely és jogosultság | A `drive.file` hozzáféréssel a Krónikás a saját maga által létrehozott vagy külön engedélyezett fájlokat kezeli. Látható Drive-mappában tárolt JSON-fájlokat próbálunk, külön Krónikás meseazonosítóval és Drive-fájlazonosítóval. Közös Cloud projekt, külön platformkliens. Az azonos fiókkal létrehozott fájl kölcsönös felderítését a két platform között élőben kell igazolni. Már létező, kézzel feltöltött fájl kiválasztása külön folyamat lehet. [Jogosultságok](https://developers.google.com/workspace/drive/api/guides/api-specific-auth) · [Fájlmetaadatok](https://developers.google.com/workspace/drive/api/reference/rest/v3/files) |
| Windows x64 | Desktop OAuth-kliens, rendszerböngésző, PKCE és állapotellenőrzés, rövid életű visszahívás a helyi loopback címen. A visszahívás a futó kliens része. A frissítőtokent a platform védett tárában kell kezelni. [Desktop OAuth](https://developers.google.com/identity/protocols/oauth2/native-app) · [Tokenkezelés](https://developers.google.com/identity/protocols/oauth2/resources/best-practices) |
| Android ARM64 | Google Play services AuthorizationClient. A regisztrált Android-klienshez a csomagnév és az adott APK aláírásához tartozó SHA-1 szükséges. Előzetesen engedélyezett fióknál az API visszaadhat hozzáférést felületi jóváhagyás nélkül. Induláskor a felület csak állapotot jelez, ha új jóváhagyás szükséges. A teszt és a terjesztés aláírását külön ellenőrizni kell. [AuthorizationClient](https://developers.google.com/android/reference/com/google/android/gms/auth/api/identity/AuthorizationClient) · [OAuth kliens létrehozása](https://developers.google.com/workspace/guides/create-credentials) |
| Adatforgalom | A lapozott katalógus csak a meseazonosítóhoz, fájlazonosítóhoz és tartalom-ellenőrzőösszeghez szükséges mezőket kéri. A Drive `version` metaadat-változáskor is nőhet, ezért a JSON tartalmának változását az ellenőrzőösszeg alapján érdemes megállapítani. A hálózati próbán mérendő a kérések száma és bájtja, valamint a változatlan indulás nulla tartalomletöltése. [Fájllista](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/list) · [Fájlmetaadatok](https://developers.google.com/workspace/drive/api/reference/rest/v3/files) |
| Ütközés és újrapróbálás | A meglévő `StoryStorage.write` csak a várt verzióra írhat. A Drive v3 `files.update` referenciája nem dokumentálja az ehhez szükséges `If-Match` feltételt. Az előzetes verziólekérés és a feltétel nélküli írás között másik kliens menthet. Az élő próbán két azonos alapú párhuzamos feltöltésből legfeljebb egy írhatja az adott verziót. Ha nincs megbízható feltételes írás, vizsgálandó a külön, változatlan revíziófájl, amely közös előd esetén megőrzi mindkét ágat. Előre generált Drive-azonosítóval ugyanazon létrehozás hálózati újrapróbálása deduplikálható. Ez a két külön eszközről indított létrehozás deduplikálását önmagában nem oldja meg. [Fájl frissítése](https://developers.google.com/workspace/drive/api/reference/rest/v3/files/update) · [Fájl létrehozása](https://developers.google.com/workspace/drive/api/guides/create-file) |
| Tesztüzem | Külső OAuth-alkalmazás Testing állapotában a Drive-jogosultsággal kiadott frissítőtoken hét nap után lejár. A regisztráció és a terjesztési beállítás külön projektgazdai lépés. Fiókváltáskor a függő mentéseket az eredeti tárolóhoz kell kötni. [Google OAuth tokenlejárat](https://developers.google.com/identity/protocols/oauth2#expiration) |

### Élő próba elfogadási feltételei

1. Szintetikus mesét hozunk létre Windowson, és ugyanazzal a Google-fiókkal Androidon automatikusan megtaláljuk. A próbát a másik irányban is megismételjük. Egy másik fiókhoz nem kerül át függő mentés.
2. Hidegindításkor működik az újbóli engedélykérés nélküli hozzáférés, ha a Google-jogosultság érvényes. Változatlan állapotban nulla tartalomletöltést mérünk. Egy mese mentésekor a többi mese tartalma nem mozog.
3. Két író ugyanabból a revízióból indul. Ellenőrizzük, hogy mindkét jóváhagyott változat megmarad, akkor is, ha egy sikeres feltöltés válasza elvész. A tesztet az alkalmazásban használt tényleges médiafeltöltési móddal kell futtatni.

A Drive fájltárolás dokumentáltan megvalósítható. A kétplatformos használhatóság és az adatvesztésmentes írás együtt az élő próba után tekinthető igazoltnak. [IMP-009](../IMPLEMENTATION_PLAN.md#imp-009) · [TST-012](../TEST_EXECUTION.md#tst-012)
