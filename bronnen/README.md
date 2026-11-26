# Openbare bronnen voor de review van GF Authentication

Gecontroleerd op 26 november 2026. De publieke IG toont package `nl.generiekefuncties.fhir#26.1.1`, FHIR 4.0.1 en buildtijd 24 november 2026 15:58 UTC. De vervolgnotitie is concept 0.6.0 van 23 november. De melding in de PR dat de IG-versie gelijk bleef betreft die wijziging. De bestaande packageversie in de merge is 26.1.1. Publieke `main` stond bij deze controle op dezelfde mergecommit als PR #91.

## Specificatie en besluitvorming

| Bron | Publicatie en vastgelegde versie |
| --- | --- |
| PR #91, inclusief discussie, drie commits, FSH- en documentdiff | [Gesprek en merge](https://github.com/minvws/generiekefuncties-docs/pull/91) · [gewijzigde bestanden](https://github.com/minvws/generiekefuncties-docs/pull/91/files) · [merge 717e1a4](https://github.com/minvws/generiekefuncties-docs/commit/717e1a4a1a58e8496a96b7b1f6badbaa928c4030) |
| Vervolgnotitie v0.6.0 met ADR's, alternatieven en risicobijlage | [Publicatie](https://minvws.github.io/generiekefuncties-docs/en/authenticatie-en-autorisatie-vervolg-mandaat-clientregistratie.html) · [bron op mergecommit](https://github.com/minvws/generiekefuncties-docs/blob/717e1a4/input/pagecontent/authenticatie-en-autorisatie-vervolg-mandaat-clientregistratie.md) |
| GF Authentication, generieke koppelvlakken en controles | [Publicatie](https://minvws.github.io/generiekefuncties-docs/en/authentication.html) · [bron op mergecommit](https://github.com/minvws/generiekefuncties-docs/blob/717e1a4/input/pagecontent/authentication.md) |
| Aanvullende IG-pagina's | [Mandate Issuer, GF-AUTN-1/2](https://github.com/minvws/generiekefuncties-docs/blob/717e1a4/input/pagecontent/authentication-mandate.md) · [BgZ en eOverdracht](https://github.com/minvws/generiekefuncties-docs/blob/717e1a4/input/pagecontent/authentication-bgz-eoverdracht.md) |
| Aangrenzende specificaties | [GF Authorization](https://github.com/minvws/generiekefuncties-docs/blob/717e1a4/input/pagecontent/authorization.md) · [GF Localization](https://github.com/minvws/generiekefuncties-docs/blob/717e1a4/input/pagecontent/localization.md) · [Care Service Directory](https://github.com/minvws/generiekefuncties-docs/blob/717e1a4/input/pagecontent/csd.md) |

De twee inline discussies in PR #91 gingen over de verhouding LRZa–Protected Resource Metadata en de omvang van een gedeeld metadatadocument. De merge vereist dat een elders gevonden AS ook in `authorization_servers` staat en staat gedeelde documenten met meerdere mandaten toe. De discussie noemt een toekomstige resolutie per URA als optie.

## PoC

[Repository](https://code.overheid.nl/MinVWS/GfAuthenticatie-transmuraal-PoC/) · [commit 3aaac1f](https://code.overheid.nl/MinVWS/GfAuthenticatie-transmuraal-PoC/commit/3aaac1f101261bae9539a80242f497663a7e5f0c) · [README](https://code.overheid.nl/MinVWS/GfAuthenticatie-transmuraal-PoC/src/commit/3aaac1f101261bae9539a80242f497663a7e5f0c/README.md) · [ontwerp en testmatrix](https://code.overheid.nl/MinVWS/GfAuthenticatie-transmuraal-PoC/src/commit/3aaac1f101261bae9539a80242f497663a7e5f0c/docs/design.md) · [F1–F15](https://code.overheid.nl/MinVWS/GfAuthenticatie-transmuraal-PoC/src/commit/3aaac1f101261bae9539a80242f497663a7e5f0c/docs/findings.md).

In de checkout zijn vooral de Java- en .NET-tokenvalidators, HAPI-autorisatie, de Python Mandate Issuer en de bijbehorende tests bekeken. Zie [review](../REVIEW.md#wat-de-poc-aantoont) voor de bewijskracht.

## Primaire referenties voor grensgevallen

- JWT bearer en mTLS, inclusief scheiding tussen assertion en access token. [RFC 7523](https://www.rfc-editor.org/rfc/rfc7523) · [RFC 8705](https://www.rfc-editor.org/rfc/rfc8705).
- RAR, doelgroep van access tokens en metadata. [RFC 9396](https://www.rfc-editor.org/rfc/rfc9396) · [RFC 9700 §2.3](https://www.rfc-editor.org/rfc/rfc9700.html#section-2.3) · [RFC 9728](https://www.rfc-editor.org/rfc/rfc9728).
- Uitgifte en periodiek opvragen van een credential. [OpenID4VCI 1.0 §§6–9](https://openid.net/specs/openid-4-verifiable-credential-issuance-1_0.html#name-token-endpoint).
- eOverdracht-workflow, notificatie en adressering van de ontvanger. [Nictiz eOverdracht 4.0.17](https://informatiestandaarden.nictiz.nl/wiki/vpk%3AV4.0_FHIR_eOverdracht) · [Twiin eOverdracht-notificatieconcept](https://ontwikkelsupplement.twiin.nl/actueel/eoverdracht-notifications-implementation-guide-notification-model-only-v0-2).
- BgZ Notified Pull met aparte notificatie- en workflow-Tasks en meerdere pull-interacties. De gekoppelde webpagina is een historische versie. Deze vergelijking onderbouwt dat de pilot de gekozen versie moet vastzetten. [Twiin TA Notified Pull v1.0.1](https://www.twiin.nl/media/downloads/ta-notified-pull-v101/download) · [Twiin BgZ-data-interacties, TA 1.4](https://afsprakenstelsel.twiin.nl/uitgefaseerd/ta140/z1-2-1-1-bgz-data-interactions).
