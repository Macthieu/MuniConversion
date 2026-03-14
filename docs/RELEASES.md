# Plan de releases et tags

## Message de commit initial recommandé

`Initial commit – MVP macOS app for batch document conversion with LibreOffice`

## Stratégie de versionnement

Le projet suit un versionnement sémantique adapté à une montée en maturité progressive.

Tags/releases proposés :

- `v0.1.0-mvp` : MVP fonctionnel (scan, filtrage strict, conversion, logs, dry run)
- `v0.2.0-ui` : amélioration UX/interface, lisibilité et ergonomie
- `v0.3.0-profiles` : enrichissement des profils et comportements de sortie
- `v1.0.0` : première version stable publiable pour usage bureau

## Format de release GitHub (recommandé)

Titre de release :

`MuniConversion vX.Y.Z - <focus>`

Contenu minimal :

- Nouveautés
- Correctifs
- Limites connues
- Pré-requis (version macOS, LibreOffice)
- Notes de migration (si nécessaire)
