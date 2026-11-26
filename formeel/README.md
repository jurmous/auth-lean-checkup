# Formele pilotketen van GF Authentication

[Pilot.lean](Pilot.lean) modelleert alle zes GF-AUTN-transacties als toestandsovergangen. Het vormt één keten voor notificatie en ophalen. De afzonderlijke [GFAuthentication.lean](GFAuthentication.lean) behoudt de oorspronkelijke tegenmodellen voor zwakke lezingen van de IG.

## Dekkingskaart

| Transactie | Overgangen en controles |
| --- | --- |
| GF-AUTN-1 | `discover` registreert een via LRZa of een andere toegelaten route gevonden issuer voor een specifieke zorgaanbieder en dienstverlener. Uitgifte vereist afzonderlijk een bevoegd ondertekenaar. |
| GF-AUTN-2 | `credentialGrant` legt issuer, cliënt, certificaat, zorgaanbieder, rollen en tijd vast. `issueImmediate`, `issueSelf` en `issueDeferred` hanteren dezelfde uitgifte- en goedkeuringsvoorwaarden. Een wachtende aanvraag heeft eigen looptijd en pollinterval. Hernieuwde uitgifte loopt door dezelfde controles. `withdraw` sluit verdere uitgifte op de oude goedkeuring uit. |
| GF-AUTN-3 | `readProtected` en `verifyPeer` verbinden de verwachte route, resource, URA, issuer, tokenendpoint, dienstverlener uit het TLS-certificaat en complementaire mandaatrol. Bij ophalen komt de route uit een eerdere geaccepteerde notificatie. Cachegebruik vereist een actuele mandaatcontrole. |
| GF-AUTN-4 | `reserve` verbruikt de sleutel (issuer, client, jti) tot `exp`. `rejectGrant` laat die reservering staan. `issueToken` koppelt de assertion aan de voorafgaande client- en broncontroles. Het token bewaart in de semantiek de geauthenticeerde begunstigde, dienstverlener, doelcontext, rol, certificaat en uitgiftegegevens. |
| GF-AUTN-5 | `acceptNotification` en `acceptRetrieval` vereisen een uitgegeven, geldig en certificaatgebonden token voor het actuele doel en de actuele operatie. Notificatie gebruikt de geauthenticeerde afzender en bedoelde ontvanger. Ophalen vereist actuele beschikbaarstelling met overeenkomende bron, ontvanger, profiel en operatie, aangevuld met de zorgprofielcontrole op de dataset en patiëntcontext. |
| GF-AUTN-6 | `fetchClient`, `useCachedClient`, `useStaleClient`, `fetchInvalid` en `fetchUnavailable` modelleren gebonden cliëntidentiteit, metadata, normale cache, tijdelijke uitval, de 24-uursgrens en de twee foutklassen. |

## Wat Lean controleert

- `accepted_exchange_chain` reconstrueert voor iedere bereikbare geaccepteerde aanvraag de voorafgaande bron- en clientcontroles, uitgiftevoorwaarden, reservering en de actuele zorgprofielbeslissing.
- `issued_mandate_has_enrollment` en `credential_authorization_has_discovery` koppelen geregistreerde mandaten aan hun uitgiftepad en, bij externe uitgifte met een credential grant, aan eerdere issuer-discovery. `issued_mandate_has_approval` geeft voor elk in dit model uitgegeven mandaat een herleidbaar uitgiftemoment met geldige goedkeuring. Een verifier van een extern ondertekend mandaat controleert de ondertekening en claims volgens het vertrouwensmodel. Zo'n verifier heeft de goedkeuring van die externe uitgever niet zelfstandig waargenomen.
- `accepted_before_mandate_expiry` geeft de eindtijdgarantie voor het profiel dat de tokenlooptijd tot het mandaat begrenst.
- `issued_assertion_cannot_be_resolved_again` en `closed_credential_cannot_be_polled` bewaken de afhandeling van reserveringen en uitgestelde aanvragen.
- `withdrawal_prevents_minting`, `cancelled_transfer_no_longer_qualifies` en `invalid_metadata_discards_snapshot` tonen de directe toestandseffecten van de drie gebeurtenissen.
- `Example.notified_pull_is_reachable` construeert vanuit de lege toestand een succesvolle notificatie en pull voor elk van de twee profielen. Beide dienstverleners verkrijgen hun eigen mandaat en de trace doorloopt alle zes transacties. De voorbeelddata en adapter zijn synthetisch.

## Modelgrens en gemaakte keuzes

Dit is een **end-to-end model op het niveau van het pilotcontract**. `Policy` is de grens naar genormaliseerde URA's en URL's, TLS, certificaatvalidatie, JOSE, transport, LRZa en FHIR. Een implementatie moet die invoer en waarnemingen apart conform de gekozen standaardversies opleveren. Het model bewijst geen cryptografische veiligheid, netwerkliveness of conformiteit van Keycloak, Duende of HAPI.

- De formele kernel gebruikt één logische geordende toestand, met monotone tijd. De client- en broncontroles direct rond tokenuitgifte delen één logisch beslismoment. De kalender en verschillende systeemtijden zijn geabstraheerd. Tests moeten de fysieke kloktolerantie en geclusterde opslag apart dekken.
- Een opslaggebeurtenis is atomair als modelovergang. Dat is de specificatie van observeerbaar gedrag. De onderliggende opslag en synchronisatie mogen verschillen.
- De pilot abstraheert de reeds als `TREAT` gevalideerde purpose en de verplichte JOSE-, mTLS- en attestatievorm via de adapters. Eén token is in dit aangescherpte profiel gebonden aan één bekende doelroute en interactie, ook als de assertion meerdere locaties bevat. De IG moet bevestigen of het profiel die beperking wil.
- Het model kiest uitsluitende eindtijden, verifieert opnieuw bij gebruik en verwijdert de eerdere CIMD-cachekopie na een definitief ongeldige refresh. De cachekeuze wordt voorgesteld in de IG-review. Caching tijdens tijdelijke uitval volgt een afzonderlijke overgang.
- Looptijden voor de twee soorten access tokens en voor openstaande aanvragen zijn parameters. Begrenzing op de goedkeuring en op het mandaat kan expliciet aan of uit. Intrekking stopt toekomstige uitgifte. Een bestaande beschikbaarstelling voor zorgdata kan worden geannuleerd via de daarvoor bevoegde bron en wordt per gebruik beoordeeld.
- BgZ en eOverdracht delen het autorisatiecontract. De exacte FHIR-mapping, profielen, processtatussen, queryvormen en notificatievarianten moeten uit de vastgestelde pilotversies komen. `notificationOK` en `retrievalOK` zijn de formele invoergrens daarvoor. `Example` demonstreert de structuur van beide richtingen zonder een concrete FHIR-versie te veronderstellen.

[Review en tweede scan](../REVIEW.md) · [Wijzigingsvoorstellen](../WIJZIGINGSVOORSTELLEN.md).

## Aanvullende checks op de ingestuurde versie

Deze stellingen staan in `GFAuthentication.SubmittedRules`. De analyse gebruikt de aangeleverde notitie, IG en PoC. De PoC-vergelijking is gebaseerd op de twee validatorbronnen.

| Check | Uitkomst | Voorstel |
| --- | --- | --- |
| **Assertiontijd ten opzichte van de AS-klok** | AS-stap 4 begrenst `exp` tot 300 seconden na `iat` en laat `iat` maximaal 60 seconden vooruit liggen. Lean bewijst dat `exp` daardoor precies 360 seconden na het controlemoment kan liggen. De notitie noemt voor assertions vijf minuten. | Vermeld in de notitie beide grenzen en noem bij de zes minuten expliciet de klok van de AS op het controlemoment. Houd de looptijd van het uitgegeven access token afzonderlijk. [AS-stap 4](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#validation-by-the-authorization-server) · [Vervolgnotitie](https://minvws.github.io/generiekefuncties-docs/en/authenticatie-en-autorisatie-vervolg-mandaat-clientregistratie.html). |
| **Volgorde van de tijdstempels** | De drie afzonderlijke tijdsvergelijkingen bewijzen op zichzelf geen volgorde tussen `iat` en `exp`. De Java-validator heeft geen aparte controle op `exp < iat`. De .NET-validator weigert die volgorde wel. Beide laten met hun tijdsregels gelijkheid toe, terwijl het pilotmodel `iat < exp` eist. | Schrijf in AS-stap 4 de gewenste grens expliciet op, inclusief het geval `iat = exp`, en gebruik dezelfde conformiteitsverwachting voor beide validators. [PoC op de beoordeelde commit](https://code.overheid.nl/MinVWS/GfAuthenticatie-transmuraal-PoC/commit/3aaac1f101261bae9539a80242f497663a7e5f0c). |
| **CIMD-cache bij tijdelijke uitval** | De IG rekent maximaal 24 uur vanaf het ophalen. Lean laat zien dat 24 uur gerekend vanaf het einde van de normale versheidsduur een andere grens geeft. De formulering in de notitie kan met deze laatste lezing worden gelezen. | Laat de notitie hetzelfde startmoment noemen als de IG. Test op en na de 24-uursgrens, ongeacht de versheidsduur. [GF-AUTN-6](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#gf-autn-6-get-client-metadata). |
| **Correlatie van AS- en RS-logs** | Alleen `jti` onderscheidt de logrecords niet zodra verschillende client- of issuerruimtes dezelfde waarde kunnen gebruiken. Dit is een controle van de bewering over logcorrelatie, geen bewijs van een collision in de PoC. De IG laat beide partijen al `client_id` loggen. | Leg vast welke gegevens de correlatie uniek maken. Gebruik waar nodig ook de uitgegevende AS en een tijd- of uitgiftekenmerk voor correlatie over lange bewaartermijnen. [Logging](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#logging). |
