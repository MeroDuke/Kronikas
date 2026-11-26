# Mesesablon és import

Jóváhagyott első változat. [IMP-010](IMPLEMENTATION_PLAN.md#imp-010) · [UC-001](TRACEABILITY.md#uc-001) · [TST-013](TEST_EXECUTION.md#tst-013)

A mesélő másolható Word-sablont és kitöltött példát kap. A fejezeteket saját szerkesztőjében töltheti ki, másolhatja és átrendezheti. A Krónikás a címsorok elején álló magyar jelölést és a dokumentum sorrendjét használja.

| Jelölés | Eredmény |
| --- | --- |
| Dokumentum címe | Mese címe |
| Bevezetés | A mese bevezető szövege |
| Jelenet – cím | Új jelenet |
| Mérföldkő – cím | Az aktuális jelenet mérföldköve |
| Lehetséges kimenetel – szöveg | Az aktuális mérföldkő tervezett kimenetele |
| Mesélői jegyzet | A mesélőnek szóló szöveg |
| Összegzés | A dokumentum végén szereplő lezárás vagy annak vázlata |

## Kitöltött példa

> **Az eltűnt korona**
>
> **Bevezetés**<br>
> A koronázás reggelén üresen találják a kincstárat.
>
> **Jelenet – A kincstár**<br>
> A zár ép, az ablak alatt sárnyomok látszanak.
>
> **Mérföldkő – Kiderül, hol van a korona**
>
> **Lehetséges kimenetel – Követik a nyomokat.**<br>
> Eljutnak a régi vízimalomhoz.
>
> **Lehetséges kimenetel – Kihallgatják az őrt.**<br>
> Az őr elárulja, hogy éjjel látta a molnárt.
>
> **Mesélői jegyzet**<br>
> A kapitány tudja, hogy az őr hazudott.
>
> **Jelenet – A régi vízimalom**<br>
> A korona egy liszteszsák alatt lapul.
>
> **Összegzés**<br>
> A nyomok a vízimalomhoz vezettek. A csapat visszavitte a koronát.

Az előnézet megmutatja a felismert szerkezetet. Ismeretlen vagy nem besorolható szöveg az Egyéb szöveg részben látható. A fájlt a Krónikás-mese jelölés vagy a korábbi sablon felismerhető jelenet–mérföldkő szerkezete azonosítja. A Mese létrehozása művelet menti az új mesét. A tervezett kimenetelek a játék során választható lehetőségek.

A Drive Behozandó mesék mappájának automatikus felismerése külön jogosultsági próba tárgya. [Tárolási döntés](decisions/ADR-0002-local-stories-and-cloud-storage.md)

Az IMP-010 első lépése a helyi Word-fájl kiválasztása és olvasható előnézete. A jóváhagyott mentés a következő lépéshez tartozik. A Word-sablon és a kitöltött minta az [importminták](../templates/) könyvtárában van.

A helyi előnézet Word (.docx), UTF-8 szöveg (.txt) és Markdown (.md) formátummal működik. Mindhárom formátum ugyanazokat a magyar kulcsszavakat használja. A TXT első nem üres sora a cím, a Markdown címsorai kettőskereszttel kezdődnek. A Word-változat a beépített Cím és Címsor stílusokat használja. A megnyitott dokumentum a mesélői előnézetben jelenik meg.

## Mesefájl felismerése

Az első nem üres sorban álló Krónikás-mese jelölést mindhárom formátum elfogadja, és az előnézet kihagyja. A korábbi sablon jelölés nélkül is megnyitható, ha jelenetet és annak mérföldkövét tartalmazza. Az egyéb olvasható dokumentumokra az app az „Ez a fájl nem Krónikás-mese.” üzenetet mutatja. A sérült fájlokra külön megnyitási hiba jelenik meg. [TST-013](TEST_EXECUTION.md#tst-013)

A fájlmegnyitási hibát külön, kontrasztos doboz és félkövér cím jelzi a fájlválasztás alatt.

Az előnézet külön **Bevezető megosztása Discordon** és **Összegzés megosztása Discordon** műveletet kínál, ha az adott szakasznak van szövege. Mindkettő a mentett webhookot használja. A bevezető előnézete és üzenete a mese címét és a bevezetőt tartalmazza. Az összegzés előnézete és üzenete az összegzés szövegét tartalmazza. A Küldés Discordra művelet indítja a küldést. [TST-007](TEST_EXECUTION.md#tst-007)
