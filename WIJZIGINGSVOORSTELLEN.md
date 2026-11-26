# Wijzigingsvoorstellen voor GF Authentication

Concepttekst voor IG 26.1.1 en de vervolgnotitie 0.6.0. De tekst voor de Engelstalige IG is in het Engels. Elke wijziging noemt het invoegpunt, het beoogde contract en een conformiteitscriterium. De Design Authority en de betrokken profielhouders moeten de aangegeven beleidskeuzes vaststellen voordat die tekst normatief kan worden. [Review](REVIEW.md) · [Bronnen](bronnen/README.md).

## Heroordeel per voorstel

| Punt | Wat al in de stukken staat | Wat het voorstel onderbouwt |
| --- | --- | --- |
| 1. Doelbinding | De schrijvers benoemen het restrisico expliciet in S2. Zij laten de AS de doelcontext opslaan en rekenen in de pilot op de beperking via de notificatie. De PoC koppelt URA en URL al bij uitgifte en controleert de doelgroep bij gebruik. | Maak de bestaande bedoeling expliciet bij de AS en de RS. De interpretatie met twee losse controles is een mogelijke zwakke lezing van AS-stap 8. Het model bewijst geen fout in de PoC. |
| 2. Richting | De pilotpagina definieert beide rollen en beperkt de toegelaten handeling bij de RS. AS-stap 8 verwijst naar de toepassingsregels. | Verduidelijk de rolcontrole per richting. Bij één endpoint voor meerdere richtingen kan het profiel kiezen tussen vooraf binden bij de AS en een expliciete rolcontrole per operatie bij de RS. Een nieuw ondertekend veld is alleen een optie als de AS vooraf moet onderscheiden en de bestaande context daarvoor onvoldoende is. |
| 3. Zorgprofiel en beschikbaarstelling | De schrijvers laten de bron de toegang bepalen en houden de assertion voor de pilot bewust klein. Het gezamenlijke voorbeeld kondigt aan dat het de informatiestandaarden niet volgt. De normatieve Task-regel maakt zelf geen versie- of profielkeuze. | Leg het daadwerkelijke pilotprofiel, de bronnen voor de beslissing en het gedrag bij intrekking vast. De gewenste looptijd, patiëntcontext, granulariteit en gekozen overdrachtsreferentie zijn profielkeuzes. |
| 4. Geldigheid | ADR-5 maakt een bewuste keuze voor laten verlopen, zodat verificatie geen extra online statusvoorziening vereist. De issuer moet de goedkeuringsperiode kennen. De PoC neemt de geplande eindtijd al mee bij uitgifte. | Maak de betekenis van die geplande eindtijd expliciet. Of een bestaand access token na afloop van het mandaat nog kort geldig mag zijn, vraagt een besluit met een grens in de norm. Het bewijs geldt voor de gekozen grens en beslist die keuze niet. |
| 5. Eenmaligheid | De schrijvers hebben die garantie al vastgelegd, inclusief reservering bij een latere afwijzing. | Verduidelijk dat de garantie ook bij meerdere instanties geldt. Gebruik een gedeelde conformancetest. De opslagtechniek mag per implementatie verschillen. |
| 6. Uitgestelde uitgifte | PR #91 heeft uitgifte met een `transaction_id` toegevoegd. OpenID4VCI §9 regelt al een geldig token voor de eerder aangevraagde credential, invalidatie na gebruik en de fout bij weigering. | Leg vast hoe het GF-profiel doorwerkt bij een verlopen token, behandeltermijn en certificaatwissel. Er is geen bewijs dat daarvoor een nieuw foutprotocol nodig is. |

De beschikbare stukken geven geen motief voor alle open details. Ze geven wel concrete ontwerpkeuzes voor punten 1, 3 en 4 en laten zien dat 5 en een deel van 6 al zijn ondervangen. [Notitie, ADR-5 en S2](https://minvws.github.io/generiekefuncties-docs/en/authenticatie-en-autorisatie-vervolg-mandaat-clientregistratie.html) · [IG-validatie](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#validation) · [OpenID4VCI §9](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#name-deferred-credential-endpoint).

## 1. Bind het token aan doelzorgaanbieder en resource-base

**Plaats.** `authentication.md`, *Validation by the authorization server*, stap 8. Vervang de bullet met `locations_organization_id` en `locations` door onderstaande tekst. Pas de claimtabel onder *Assertion* aan en voeg in *Validation by the resource server*, na stap 3, de tweede alinea als nieuw controlepunt toe.

> The Authorization Server SHALL require a target care provider URA in `locations_organization_id` and a non-empty list of protected resource identifiers in `locations`. For every identifier in the list, it SHALL verify that it serves that identifier for that target care provider under this profile. It SHALL bind the issued access token to the validated pairs. The binding SHALL be available to the Resource Server as authenticated token data, including when the Resource Server uses introspection. In a notification, the target care provider is the receiving care provider. In retrieval, it is the care provider holding the data.
>
> The Resource Server SHALL resolve the target care provider and protected resource identifier from its trusted route and tenant configuration for the actual request. It SHALL reject the request unless that pair is authorized by the access token and the token is valid for this Resource Server. A shared protected resource identifier still requires the target care provider check. The protected resource identifier SHALL be the configured identifier advertised as `resource` in GF-AUTN-3. A client-supplied identifier alone SHALL NOT determine the target tenant.

**Claimtabel.** Vervang bij `locations_organization_id` de omschrijving “The URA of the source care provider” door “The URA of the target care provider for this interaction.” Omschrijf `locations` als “Non-empty list of RFC 9728 protected resource identifiers for that target care provider.”

**Notitie.** Pas bijlage C.5, S2 aan zodra de IG-eis is vastgesteld. Beschrijf dat de AS een doelpaar valideert en vastlegt en dat de RS het actuele doelpaar bij ieder verzoek controleert. De bron beslist daarnaast welke concrete gegevens de ontvanger mag ophalen.

**Conformiteit.** Test zowel gedeelde bases met verschillende tenants als verschillende bases met één issuer. Controleer het doelpaar bij de AS en opnieuw bij de RS voor zowel een lokaal ondertekend token als introspectie. Leg het gebruikte URI-vergelijkingsprofiel en foutresultaat vast. Voor een token dat niet voor deze RS of doeltenant geldt is `401 invalid_token` een voorstel. [IG AS/RS](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#validation) · [RFC 9700 §2.3](https://www.rfc-editor.org/rfc/rfc9700.html#section-2.3).

**Lean.** `separate_membership_does_not_establish_pairing` en `time_and_certificate_do_not_entail_target` tonen waarom beide controles nodig zijn. `verified_target_is_served` bewijst de samenstelling voor het aangescherpte contract.

## 2. Maak de richting van de interactie aantoonbaar

**Plaats.** `authentication.md`, *Validation by the authorization server*, stap 8, bij `<purpose>-user` en `<purpose>-custodian`. Voeg de tekst ook toe aan de profielpagina onder *Purpose and mandate codes*, met de bestaande tabel als normatieve mapping.

> The use-case profile SHALL define the mandate code required for each supported operation and which component determines the requested interaction. If the Authorization Server issues an interaction-specific token, it SHALL determine the interaction unambiguously from the signed assertion and trusted configuration, verify the corresponding mandate code, and bind the token to that interaction. The Resource Server SHALL verify the binding for the actual operation. If the profile allows a token for more than one interaction, the Resource Server SHALL require the authenticated mandate code for the actual operation on every request.
>
> In BgZ and eOverdracht the client role is `custodian` for notification and `user` for retrieval. The Authorization Client SHALL check the complementary role in the other party's mandate for the same interaction.

**Besluit.** Eerst vaststellen of de pilot interactiespecifieke tokens nodig heeft. Als de AS die uitgeeft en de bestaande gegevens onvoldoende zijn, kan de profielhouder bijvoorbeeld een endpointmapping gebruiken of `interaction` toevoegen aan de ondertekende `nl-gis-v1`-context.

**Conformiteit.** Toets beide richtingen met mandaten met één rol en met beide rollen. Toets welk onderdeel een rolmismatch weigert. Vereist het profiel een interactiespecifiek token, toets dan ook ontbrekende of dubbelzinnige context vóór uitgifte. [Pilotrollen](https://minvws.github.io/generiekefuncties-docs/en/authentication-bgz-eoverdracht.html#purpose-and-mandate-codes).

**Lean.** `role_disjunction_does_not_determine_direction` en `client_and_peer_roles_differ`.

## 3. Koppel toegang aan het juiste zorgprofiel en een actuele beschikbaarstelling

**Plaats.** `authentication-bgz-eoverdracht.md`, *Scope* en *Authorization by the resource server*. Vervang de gedeelde alinea die begint met “The notification is a `Task`” en de daaropvolgende uniforme Task-controles door een gedeeld contract en twee profielverwijzingen. Neem het gemeenschappelijke contract ook op bij de afbakening in de notitie.

> Each pilot profile SHALL identify the version of the care-content and notification specifications in use. It SHALL define the supported notification and retrieval interactions, the evidence associating the authenticated sender and recipient with the exchange, and how the Resource Server determines which dataset and operations are available to the recipient. Client-supplied FHIR references SHALL be validated under those profile rules.
>
> On each retrieval, the source Resource Server SHALL authorize the operation only when authoritative state at the source confirms an active availability for that source, the token subject as recipient, and the requested operation and dataset. The profile SHALL define which transitions create, replace, cancel and end an availability, and when each transition affects access. The profile SHALL specify the result for missing, ambiguous or inactive evidence and how patient context and resource references are resolved. Where searches are allowed, the profile SHALL specify the permitted query and how its results remain within the availability.
>
> If the profile restricts a token to a single transfer, it SHALL define how the transfer is bound to the token and how the Resource Server verifies that binding against the current availability. An opaque, source-issued reference is one possible representation. If the profile permits more than one transfer per token, the Resource Server SHALL authorize each request against a qualifying active availability.

**Profielinvulling vóór publicatie.**

- **BgZ.** Leg de geselecteerde Twiin-versie vast. Kies welke routes de pilot ondersteunt. Benoem afzonderlijk de Notification Task en de optionele Workflow Task, inclusief annulering en toegelaten zoekinteracties. [Twiin BgZ](https://afsprakenstelsel.twiin.nl/uitgefaseerd/ta140/z1-2-1-1-bgz-data-interactions).
- **eOverdracht.** Leg de gekozen Nictiz-versie en het notificatiepatroon vast. Beschrijf hoe de dienstverlener de ontvangende zorgaanbieder eenduidig uit de bron-Task en het geselecteerde profiel afleidt, ook als `owner` nog niet is ingevuld in een procesfase die de pilot ondersteunt. Leg de omgang met de overdrachts-Composition, indirecte verwijzingen en eventuele workflow-updates vast. [Nictiz eOverdracht 4.0.17](https://informatiestandaarden.nictiz.nl/wiki/vpk%3AV4.0_FHIR_eOverdracht) · [Twiin eOverdracht-notificatieconcept](https://ontwikkelsupplement.twiin.nl/actueel/eoverdracht-notifications-implementation-guide-notification-model-only-v0-2).
- **Pas het voorbeeld aan.** Geef per profiel een volledige notificatie en pull, met een geldige identiteitsmapping, een ingetrokken of geëindigde beschikbaarstelling en een verwacht resultaat. Als een profiel een overdrachtsreferentie in de assertion gebruikt, documenteer de naam, herkomst, geldigheid en plaats in de tokengegevens. Beslis met de profielhouder welke patiëntcontext de bron al kent en welke velden noodzakelijk zijn.

**Conformiteit.** Voor de gekozen profielversies ten minste een geldige huidige beschikbaarstelling, een andere patiënt of dataset, een verkeerde ontvanger, een geannuleerde beschikbaarstelling en een aanvraag na de eindtijd. Oefen ook de routes zonder workflow-Task en de haalbare zoekinteracties als het profiel die ondersteunt.

**Lean.** `task_membership_does_not_entail_active_transfer` onderbouwt waarom een Task-referentie en overeenkomende ontvanger onvoldoende zijn voor de geldigheid in de tijd. De concrete FHIR-mapping komt uit de informatiestandaarden en moet worden getest met hun profielen.

## 4. Laat afgesproken eindtijden doorwerken in mandaat en token

**Plaats.** `authentication-mandate.md` onder *Mandate Issuer*, `authentication.md` onder *Validity and renewal* en *GF-AUTN-4*, en ADR-5 van de notitie.

> For initial issuance, renewal and deferred issuance, the Mandate Issuer SHALL verify that approval applies at issuance to the care provider, service provider and every mandate code. The validity end of the mandate SHALL be at or before both the approved end time and the signing certificate's validity end. If the governing policy permits open-ended approval, the mandate validity and certificate limits still apply.
>
> If the profile requires the mandate to remain valid throughout token use, the Authorization Server SHALL cap the access token expiry at the mandate expiry and at any earlier applicable policy limit. The response's `expires_in` SHALL reflect the actual token validity. Expiry instant comparisons SHALL be consistent between issuers and verifiers. At the expiry instant the object is invalid.
>
> A withdrawal received before the agreed approval end SHALL stop future issuance and renewal for the withdrawn approval. The use-case or governance profile SHALL describe whether and how early withdrawal affects mandates that are already issued and access tokens that are already active.

**Besluit.** Gebruik bij de pilot één bindende maximaanduiding voor de mandaatduur, bijvoorbeeld 92 maal 24 uur, met dezelfde waarde in ADR, claimtabel en validatiestap. Beslis daarnaast of de pilot een normatief maximum voor access tokens krijgt. De getoonde 300 seconden zijn nu een voorbeeld. Spreek een toetsbaar maximum af voor het effect van vroegtijdige intrekking. Een statusvoorziening per mandaat vraagt een nieuw governancebesluit en een expliciete beschikbaarheidsregel.

**Notitie.** Pas in bijlage C.1 de aanname over een access token van vijf minuten aan de gekozen norm aan. Vermeld bij de assertion afzonderlijk de maximale tijd tussen `iat` en `exp` en de tolerantie voor een toekomstige `iat`.

**Conformiteit.** Toets het moment vlak vóór, op en na elk einde. Voeg een goedkeuring toe die eerder eindigt dan de standaard mandaatduur, een uitgestelde uitgifte rond dat moment en een positief geval met tijdige vernieuwing. [IG geldigheid](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#validity-and-renewal) · [IG mandaatuitgifte](https://minvws.github.io/generiekefuncties-docs/en/authentication-mandate.html).

**Lean.** `approval_at_issuance_does_not_bound_mandate_expiry`, `token_validity_does_not_end_with_mandate` en `bounded_lifetimes_compose`. Deze resultaten gaan over geplande eindtijden. Vroegtijdige intrekking vereist aanvullende informatie op het beslismoment.

## 5. Leg de reikwijdte van eenmalige reservering vast

**Plaats.** `authentication.md`, *Validation by the authorization server*, stap 4, bij de bestaande `jti`-regel.

> Across all instances accepting assertions for one logical issuer, at most one request for an authenticated client and assertion `jti` SHALL pass the one-time-use check. Once passed, the check SHALL reject subsequent uses while that assertion remains eligible, including when a later validation step rejects the first request. The server SHALL refuse token issuance if it cannot establish that this requirement is met.

**Conformiteit.** Neem een parallelle en een failovertest tussen twee AS-instanties op. Het totale aantal succesvolle AS-beslissingen voor dezelfde reservering is maximaal één. De norm vereist deze uitkomst al voor een enkele logische issuer. [IG AS-stap 4](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#validation-by-the-authorization-server).

**Lean.** `no_second_reservation` bewijst de eigenschap voor een atomaire toestandsovergang. De conformancetest toetst of de implementatie aan die voorwaarde voldoet.

## 6. Sluit het contract voor uitgestelde uitgifte

**Plaats.** `authentication-mandate.md`, *GF-AUTN-2 Obtain Mandate*, direct na de alinea over de Deferred Credential Endpoint.

> The Mandate Issuer SHALL document the pending transaction lifetime and the procedure to follow after access token expiry or certificate replacement. If the profile permits continuation with a replacement token, the issuer SHALL verify that it is valid for the pending credential and that the client's identity and certificate satisfy the profile's binding rules. The issuer SHALL recheck current approval before issuing the mandate and SHALL apply the terminal responses from OpenID4VCI §9.

Specificeer in dezelfde sectie de metadata die deze `client_credentials`-variant kenbaar maakt, waaronder de verwerking van `credential_configuration_id` en eventuele `credential_identifiers`. Leg de invulling van `locations` vast voor een afzonderlijke issuer-AS. Kies met de profielhouder of uitgesteld uitgeven met een nieuw token ondersteund moet worden. Documenteer de foutcodes met het gedrag van cliënt en issuer. Dit is een tekstuele interoperabiliteitsbevinding en is buiten het Lean-model gehouden. [GF-AUTN-2](https://minvws.github.io/generiekefuncties-docs/en/authentication-mandate.html#gf-autn-2-obtain-mandate) · [OpenID4VCI §§6–9](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#name-token-endpoint).

## Overige afstemming voor deze versie

- Werk de inleiding, actortabel, claimtabel en voorbeeldschema's bij na de keuze voor het pilotprofiel. Verwijs voor de grenzen van een concrete gegevenshandeling naar die profielregels. Maak bij GF-AUTN-1 expliciet dat het gevonden endpoint zowel het verwachte `connectionType` als `payloadType` en de bijbehorende codestelsels moet hebben.
- Presenteer NVI en LRZa in de mandaatcodetabel als mogelijke toekomstige toepassingen. Verwijs voor de nog onbesliste NVI-rol naar GF-LOC-5. Laat de Design Authority het interoperabele model voor AORTA/LSP-delegatie afzonderlijk vaststellen. Een eventuele pilotmarkering vereist afspraken over uitgifte, validatie en afbakening per omgeving.
- Vul Bijlage C.7 en de IG-roadmap aan met dezelfde conformiteitscriteria en volledige gesigneerde testvectoren. Neem twee richtingen, twee tenants en ongelijk verlopende geldigheidsperiodes op. Laat de pilots bevestigen welke autorisatieserverproducten, versies en gekozen profielen die vectoren ondersteunen.

[Open punten GF Localization](https://minvws.github.io/generiekefuncties-docs/en/localization.html#open-issues) · [IG-roadmap](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#roadmap-for-gf-authentication).

## 7. Maak de tweede reeks interoperabiliteitsregels toetsbaar

Deze voorstellen volgen uit de tweede broncontrole en het uitgebreide [pilotmodel](formeel/README.md). De precieze keuzes over cache en verlenging vragen een profielbesluit.

- **GF-AUTN-2 en de CIMD-tabel.** Vermeld per grant of en hoe de AS de metadata gebruikt. Als hetzelfde document voor beide transacties wordt gebruikt en grants uit CIMD worden onderhandeld, moet de cliënt daarin zowel JWT bearer als `client_credentials` declareren. Een document voor één rol declareert alleen de grants die het ondersteunt. Maak een voorbeeld met twee AS'en en één cliënt. [GF-AUTN-2](https://minvws.github.io/generiekefuncties-docs/en/authentication-mandate.html#gf-autn-2-obtain-mandate) · [CIMD-draft §6](https://datatracker.ietf.org/doc/html/draft-ietf-oauth-client-id-metadata-document-03#section-6).
- **GF-AUTN-3 en *Validity and renewal*.** Stel de effectieve cacheduur voor een PRM vast op basis van de beschikbare overlap en resterende geldigheid. Als 24 uur overlap niet haalbaar is, laat de client na een verlopen mandaat eerst actuele metadata proberen en weiger de tokenaanvraag bij afwezigheid van een geldig mandaat. Leg de cacheaanwijzingen en het gedrag van reeds opgehaalde kopieën vast. Test ook een mandaat dat minder dan 24 uur geldig kan zijn. [GF-AUTN-3](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#gf-autn-3-get-protected-resource-metadata).
- **GF-AUTN-6, na de laatste cachebullet.** Stel als regel voor dat een definitief ongeldige refresh het oudere document uitsluit van volgende fallback totdat een nieuw document is gevalideerd. Toets de reeks geldig, daarna definitief ongeldig, vervolgens tijdelijk onbereikbaar. [GF-AUTN-6](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#gf-autn-6-get-client-metadata).
- **Serviceprovideridentifier.** Maak de algemene formatregel en de OIN-afleidingsregel consistent. Leg een testvector vast voor een OIN zonder KvK-mapping, met dezelfde verwachte `may_act.sub` en `act.sub` bij issuer, AS en RS. [Afleidingsbijlage](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#appendix-deriving-the-service-provider-identifier).
- **AS-stap 4 en voorstel 5.** Formuleer expliciet dat profiel, afzender, handtekening, publiek en begrensde assertiontijd worden vastgesteld vóór reservering. Behoud het reserveringsresultaat voor latere mandaat- en profielafwijzingen. Test de volgorde en de bewaartermijn bij een afgewezen aanvraag. [AS-stap 4](https://minvws.github.io/generiekefuncties-docs/en/authentication.html#validation-by-the-authorization-server).
