# GitHub App böngészős belépés

A tokenváltó a GitHub App titkát a szerveren használja. A kliens megnyitja a GitHub engedélyezési oldalát, majd rövid időközönként lekéri a belépés eredményét. A callback állapotot és PKCE-t ellenőriz. A tokent egy külön, egyszer használható jeggyel lehet lekérni, a jegy öt perc után lejár. Az aktív kapcsolat felhasználói tokenje a kliens memóriájában marad.

## Élő konfiguráció

1. Regisztrálj GitHub Appot, és állítsd be a `https://<tokenváltó-host>/github/callback` callback URL-t. A kiválasztott privát meserepókhoz engedélyezd a **Contents: Read and write** jogosultságot, valamint a lejáró felhasználói tokeneket.
2. A tokenváltót Node.js 20 vagy újabb környezetben indítsd a `node auth_backend/server.mjs` paranccsal. Állítsd be a `GITHUB_APP_CLIENT_ID`, `GITHUB_APP_CLIENT_SECRET` és `KRONIKAS_AUTH_PUBLIC_URL` környezeti változókat. A `PORT` alapértéke 8080.
3. A szolgáltatást HTTPS reverse proxy mögött, egy példányban futtasd. A folyamat memóriában tárolja a függő kéréseket. A callback URL query részét és az Authorization fejlécet hagyd ki a proxy hozzáférési naplójából.
4. A meseválasztó buildhez add meg a `--dart-define=KRONIKAS_AUTH_URL=https://<tokenváltó-host>` opciót. A GitHub App titkát a szerver környezetében add meg.
5. A GitHub Appot telepítsd a kiválasztott privát meserepóra. A jóváhagyás után térj vissza a Krónikásba, és válassz repót. A repó tulajdonosa előre beállítja a hozzáférést. Egyetlen elérhető mesetár esetén a Krónikás automatikusan megnyitja a meselistát.

A `node --test auth_backend/server.test.mjs` szintetikus GitHub-válasszal ellenőrzi a PKCE-t, az elutasított állapotot és az egyszeri tokenátadást. A Flutter-widgetteszt a sikeres belépés utáni repóválasztást igazolja. Az élő belépés ellenőrzéséhez a végpont és a GitHub App tényleges beállítása kell.

[GitHub App tokenváltás](https://docs.github.com/en/apps/creating-github-apps/authenticating-with-a-github-app/generating-a-user-access-token-for-a-github-app)
