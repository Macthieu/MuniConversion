# MuniConversion

**Sous-titre :** utilitaire macOS natif pour la conversion documentaire en lot, localement, de façon fiable et prévisible.

MuniConversion est une application macOS (Swift + SwiftUI) qui orchestre des conversions de documents en lot via LibreOffice en mode headless, avec filtrage strict, journalisation claire et mode simulation.

## Positionnement

- Rôle: outil spécialisé de conversion dans l'écosystème Orchiviste.
- Orchiviste reste le cockpit/hub; MuniConversion reste un outil autonome dédié.

## Mission

- Standardiser les conversions documentaires bureautiques de façon locale, fiable et auditable.
- Réduire la manipulation manuelle répétitive avant archivage et traitement métier.

## Pourquoi MuniConversion ?

- Éviter les manipulations manuelles répétitives de conversion fichier par fichier.
- Standardiser les traitements bureautiques (archives, administration, dossiers partagés).
- Garder un outil simple, local, auditable, open source et maintenable.
- Réduire les erreurs humaines grâce au filtrage strict et au mode simulation.

## Cas d’usage

- Préparer des lots de documents bureautiques pour archivage PDF.
- Migrer des anciens formats (`.doc`, `.xls`, `.ppt`) vers des formats récents.
- Uniformiser un dossier de travail avant diffusion.
- Vérifier en simulation ce qui serait converti avant toute exécution réelle.

## Fonctionnalités actuelles

- Sélection d’un dossier source (sélecteur natif macOS)
- Scan avec ou sans sous-dossiers
- Profils de conversion prédéfinis :
  - DOC -> DOCX
  - DOC -> PDF
  - DOCX -> PDF
  - DOCX -> DOC
  - XLS -> XLSX
  - XLS -> PDF
  - XLSX -> PDF
  - XLSX -> XLS
  - PPT -> PPTX
  - PPT -> PDF
  - PPTX -> PDF
  - PPTX -> PPT
  - RTF -> DOCX
  - RTF -> PDF
  - TXT -> PDF
  - ODT -> PDF
  - ODS -> PDF
  - ODP -> PDF
- Filtrage strict par extension source, insensible à la casse
- Recherche rapide de profil dans la zone Conversion
- Résumé explicite du profil actif (filtre source, cible, format LibreOffice)
- Exclusion des fichiers temporaires/système (`~$*`, `.DS_Store`, fichiers cachés selon option)
- Sortie au choix : dossier source ou dossier de sortie distinct
- Option de préservation de l’arborescence relative
- Gestion des collisions : ignorer, remplacer, renommer automatiquement
- Journal détaillé : `matched`, `ignored`, `converted`, `failed`, `skippedExisting`, `dryRun`
- Export du journal en `.txt`
- Mode simulation (dry run)
- Détection et test de LibreOffice
- Arrêt en cours de traitement
- Mémorisation des derniers réglages
- Interface multilingue (Français / English / Español) avec sélection de langue dans l'app

## Captures d’écran

![Vue principale](docs/images/screenshot-main-view.png)
![Conversion en cours](docs/images/screenshot-conversion-running.png)
![Table des résultats](docs/images/screenshot-results-table.png)
![Paramètres et langue](docs/images/screenshot-settings-locale.png)

## Le logiciel ne modifie jamais les originaux

MuniConversion **ne modifie pas** et **ne supprime pas** les fichiers d’origine.

- Les conversions créent uniquement de nouveaux fichiers de sortie.
- En mode simulation, aucune conversion réelle n’est exécutée.
- En cas d’erreur sur un fichier, le lot continue sur les autres fichiers.

## Sécurité et prudence

- Toujours commencer par un passage en mode simulation sur un nouveau lot.
- Vérifier le dossier de sortie et la politique de collision avant lancement.
- Conserver des sauvegardes de vos dossiers sensibles.
- Contrôler un échantillon de fichiers convertis avant diffusion massive.

## Dépendance à LibreOffice

MuniConversion est une interface graphique : le moteur de conversion repose sur LibreOffice (`soffice`).

Chemins testés automatiquement :

- `/Applications/LibreOffice.app/Contents/MacOS/soffice`
- `/Applications/LibreOfficeDev.app/Contents/MacOS/soffice`
- `/opt/homebrew/bin/soffice`
- `/usr/local/bin/soffice`

Sans LibreOffice exécutable, la conversion réelle est bloquée avec un message explicite.

## Prérequis

- macOS 13+
- Xcode 15+ (recommandé)
- LibreOffice installé

## Compilation / ouverture du projet

Le projet est un Swift Package macOS ouvrable dans Xcode.

1. Ouvrir `Package.swift` dans Xcode.
2. Sélectionner le schéma `MuniConvert`.
3. Lancer l’application.

En ligne de commande :

```bash
swift build
swift run MuniConvert
```

## Utilisation

1. Choisir un dossier source.
2. Choisir le profil de conversion.
3. Configurer les options (sous-dossiers, sortie, collisions).
4. Choisir la langue de l’interface dans `Paramètres` si besoin.
5. Optionnel : activer `Simulation seulement`.
6. Cliquer sur `Analyser` puis `Lancer la conversion`.
7. Contrôler le journal et exporter le log si nécessaire.

## Structure du projet

```text
MuniConversion/
├── Package.swift
├── Sources/
│   └── MuniConvert/
│       ├── App/
│       ├── Models/
│       ├── Services/
│       ├── Utilities/
│       ├── ViewModels/
│       └── Views/
├── .github/workflows/ci.yml
├── docs/RELEASES.md
├── ROADMAP.md
├── README.md
├── LICENSE
├── CONTRIBUTING.md
└── CHANGELOG.md
```

## Limites actuelles

- Qualité de conversion dépendante de LibreOffice et des documents d’entrée.
- Traitement séquentiel (pas de parallélisation dans ce MVP).
- Traduction actuellement fournie en 3 langues (FR/EN/ES).

## Feuille de route courte

- Ajouter des tests unitaires (filtrage, collisions, chemins cibles)
- Ajouter davantage de profils de conversion
- Ajouter un packaging `.app` signé/notarisé
- Améliorer le reporting de fin de lot

Feuille de route détaillée: voir `ROADMAP.md`.

## Publication GitHub et versions

- Plan de releases : voir `docs/RELEASES.md`
- Guide build/release : voir `docs/BUILD_AND_RELEASE.md`
- CI GitHub : `swift build` + `swift test` sur macOS à chaque `push` / `pull_request`
- Workflow de release macOS (`.app` + `.zip`) : `.github/workflows/release-macos.yml`

## Distribution macOS

- Guide distribution : `docs/MACOS_DISTRIBUTION.md`
- Setup secrets Apple pour signature/notarisation : `docs/APPLE_SECRETS_SETUP.md`
- Icône app personnalisée : déposer `assets/AppIcon.png` (le build génère automatiquement `assets/AppIcon.icns`)

### Sans compte Apple Developer

MuniConversion peut être distribué sans signature/notarisation:

- Le workflow release publie un ZIP ad-hoc signé (`*-unsigned.zip`) mais non notarisé
- L'application reste utilisable localement

Premier lancement sur macOS (app non signée):

1. Clic droit sur l'app > `Ouvrir`
2. Confirmer l'ouverture
3. Si nécessaire: `Réglages Système > Confidentialité et sécurité > Ouvrir quand même`

Si macOS affiche `MuniConvert est endommagé` (nom technique actuel du bundle):

1. Supprimer l'ancienne copie de `MuniConvert.app`
2. Télécharger une release >= `v1.0.3`
3. Redécompresser puis relancer avec clic droit > `Ouvrir`

## Licence GPLv3

Ce projet est distribué sous licence **GNU General Public License v3.0**.

- Voir [LICENSE](LICENSE)
- Les fichiers source incluent un en-tête court `SPDX-License-Identifier: GPL-3.0-only`

## Versionnage

- Le projet suit `Semantic Versioning`.
- Référence actuelle: `1.1.0`.

## Note de transition de nommage

Le nom public est `MuniConversion`.
Certains identifiants techniques internes historiques restent temporairement en `MuniConvert` (package, targets, nom d'app dans les scripts et commandes) pour éviter un refactor applicatif dans cette passe.

## Sécurité

- Politique de sécurité : [SECURITY.md](SECURITY.md)
