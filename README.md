# Formele review GF Authentication

De review betreft PR #91, conceptnotitie 0.6.0, IG 26.1.1 en de Keycloak/Duende-PoC. De pilotflow is op hoofdlijnen consistent. De normatieve tekst moet preciezer over de doelbinding van access tokens, de verhouding tot de zorgprofielen en de grenzen van machtiging en toegang.

- [Review en advies over Lean](REVIEW.md)
- [Voorgestelde wijzigingen voor de specificaties](WIJZIGINGSVOORSTELLEN.md)
- [Openbare bronnen en exacte versies](bronnen/README.md)
- [Lean 4-pilotmodel en dekkingskaart](formeel/README.md)
- [Oorspronkelijke Lean 4-tegenmodellen](formeel/GFAuthentication.lean)

## Bewijzen opnieuw controleren

Gebruik Lean 4.19.0 met de meegeleverde `lean-toolchain`. Beide modellen importeren alleen `Std` en heeft geen extra projectafhankelijkheden.

```sh
lean --version
lean -t 0 -DwarningAsError=true formeel/GFAuthentication.lean
lean -t 0 -DwarningAsError=true formeel/Pilot.lean
```

Gecontroleerd met Lean 4.19.0 op macOS arm64. De review beschrijft welke controles het model abstraheert en welke conclusies daarvan afhangen.
