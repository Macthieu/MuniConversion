# macOS Distribution (Signed / Notarized)

Ce document décrit la préparation d'un artefact `.app` distribuable sur macOS.

## Scripts disponibles

- `scripts/release/build_dist.sh`
  - Build release Swift
  - Génération `MuniConvert.app`
  - Signature ad-hoc du bundle (compatibilité Gatekeeper de base)
  - Création d'un ZIP non notarisé (`dist/*-unsigned.zip`)

- `scripts/release/sign_notarize.sh`
  - Signature du bundle `.app`
  - Notarisation (si credentials fournis)
  - Création d'un ZIP signé (`dist/*-macOS.zip`)

## Variables d'environnement

### Requises pour signature

- `APPLE_CODESIGN_IDENTITY`

### Requises pour notarisation

- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`

## Exécution locale

```bash
bash scripts/release/build_dist.sh

# Optionnel: signature + notarisation
export APPLE_CODESIGN_IDENTITY="Developer ID Application: ..."
export APPLE_ID="..."
export APPLE_APP_SPECIFIC_PASSWORD="..."
export APPLE_TEAM_ID="..."
bash scripts/release/sign_notarize.sh dist/MuniConvert.app
```

## CI GitHub Release

Workflow: `.github/workflows/release-macos.yml`

Déclenchement:

- push de tag `v*`
- `workflow_dispatch`

Comportement:

- Sur tag (`refs/tags/v*`): publication des ZIP sur la Release GitHub
- Hors tag (ex: `main` en manuel): upload des ZIP comme artifact de workflow

Secrets recommandés pour release signée/notarisée:

- `APPLE_CERTIFICATE_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_CODESIGN_IDENTITY`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`
- `KEYCHAIN_PASSWORD`

Sans ces secrets, le workflow publie tout de même un ZIP ad-hoc signé (non notarisé).

Astuce:

- Utiliser `scripts/release/configure_github_secrets.sh` pour injecter tous les secrets en une seule commande.

## Mode sans compte Apple Developer

Si tu n'as pas de compte Apple Developer, conserve simplement le mode non signé:

- ne configure pas les secrets Apple
- déclenche le workflow release
- récupère l'archive `*-unsigned.zip`

Installation côté utilisateur:

1. Décompresser le ZIP
2. Clic droit sur `MuniConvert.app` puis `Ouvrir`
3. Confirmer dans la fenêtre de sécurité macOS
4. Si blocage persistant: `Réglages Système > Confidentialité et sécurité > Ouvrir quand même`

Si macOS affiche `MuniConvert est endommagé`:

1. Supprimer l'ancienne app copiée dans `/Applications`
2. Télécharger une release `v1.0.3` ou plus récente
3. Redécompresser l'archive puis relancer l'app

Note:

- Ce mode est adapté à un usage personnel/interne.
- Pour une distribution large sans alertes Gatekeeper, la signature/notarisation reste recommandée.
