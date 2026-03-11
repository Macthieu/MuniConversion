# Build & Release Guide

Ce guide documente une procédure simple et répétable pour préparer une release MuniConvert.

## 1. Préparation locale

1. Vérifier l'état Git:
   - `git status`
2. Mettre la branche à jour:
   - `git pull --ff-only`
3. Vérifier le build et les tests:
   - `swift build`
   - `swift test`

## 2. Vérifications produit

- Vérifier les profils de conversion critiques
- Vérifier le mode simulation
- Vérifier les garde-fous UX avant conversion réelle
- Vérifier l'export du journal

## 3. Mise à jour documentaire

- Mettre à jour `CHANGELOG.md`
- Mettre à jour `README.md` si fonctionnalités visibles changées

## 4. Tag et release GitHub

1. Commit final:
   - `git add ...`
   - `git commit -m "<message>"`
2. Push `main`:
   - `git push origin main`
3. Créer et pousser un tag annoté:
   - `git tag -a vX.Y.Z -m "MuniConvert vX.Y.Z"`
   - `git push origin vX.Y.Z`
4. Créer la release GitHub:
   - `gh release create vX.Y.Z --title "MuniConvert vX.Y.Z" --notes "..."`

## 5. Distribution `.app` locale

Scripts disponibles:

- `bash scripts/release/build_dist.sh`
  - build release
  - crée `dist/MuniConvert.app`
  - crée `dist/MuniConvert-<version>-unsigned.zip`

- `bash scripts/release/sign_notarize.sh dist/MuniConvert.app`
  - signe l'app
  - notarise si credentials présents
  - crée `dist/MuniConvert-<version>-macOS.zip`

## 6. Distribution via GitHub Actions

Workflow dédié:

- `.github/workflows/release-macos.yml`

Déclenchement:

- push d'un tag `v*`
- lancement manuel `workflow_dispatch`

Le workflow publie les archives `.zip` sur la release GitHub.

## 7. Signature / notarisation Apple

Consulter:

- `docs/MACOS_DISTRIBUTION.md`
- `docs/APPLE_SECRETS_SETUP.md`

Ces étapes nécessitent un compte Apple Developer actif et les secrets GitHub appropriés.
