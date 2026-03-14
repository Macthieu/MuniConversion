# MuniConversion v1.1.0

Utilitaire macOS natif pour la conversion documentaire en lot via LibreOffice, local et open source.

## Ce que fait MuniConversion

- Scan d'un dossier (avec ou sans sous-dossiers)
- Filtrage strict des fichiers selon le profil choisi
- Conversion en lot via LibreOffice headless
- Journal détaillé (`matched`, `ignored`, `converted`, `failed`, `skippedExisting`, `dryRun`)
- Mode simulation (dry run)
- Gestion des collisions (ignorer / remplacer / renommer)

## Nouveautés de cette version

- Interface multilingue avec choix de langue dans l'app:
  - Français
  - English
- Captures d'écran intégrées dans le README
- Améliorations de structure des ressources localisées

## Prérequis

- macOS 13+
- LibreOffice installé et accessible

## Sécurité et prudence

- Le logiciel ne modifie jamais les originaux.
- Commencer par une simulation sur un nouveau lot est recommandé.
- Vérifier le dossier de sortie et la politique de collision avant une conversion réelle.

## Téléchargement

- Archive macOS: `MuniConvert-v1.1.0-unsigned.zip`
- Pour une release notarisée Apple, voir la documentation de distribution (`docs/MACOS_DISTRIBUTION.md`).
