# MuniConvert

**Sous-titre :** utilitaire macOS natif pour la conversion documentaire en lot, localement, de façon fiable et prévisible.

MuniConvert est une application macOS (Swift + SwiftUI) qui orchestre des conversions de documents en lot via LibreOffice en mode headless, avec filtrage strict, journalisation claire et mode simulation.

## Pourquoi MuniConvert ?

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
  - XLS -> XLSX
  - XLS -> PDF
  - XLSX -> PDF
  - PPT -> PPTX
  - PPT -> PDF
  - PPTX -> PDF
  - RTF -> DOCX
  - RTF -> PDF
  - TXT -> PDF
- Filtrage strict par extension source, insensible à la casse
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

## Le logiciel ne modifie jamais les originaux

MuniConvert **ne modifie pas** et **ne supprime pas** les fichiers d’origine.

- Les conversions créent uniquement de nouveaux fichiers de sortie.
- En mode simulation, aucune conversion réelle n’est exécutée.
- En cas d’erreur sur un fichier, le lot continue sur les autres fichiers.

## Sécurité et prudence

- Toujours commencer par un passage en mode simulation sur un nouveau lot.
- Vérifier le dossier de sortie et la politique de collision avant lancement.
- Conserver des sauvegardes de vos dossiers sensibles.
- Contrôler un échantillon de fichiers convertis avant diffusion massive.

## Dépendance à LibreOffice

MuniConvert est une interface graphique : le moteur de conversion repose sur LibreOffice (`soffice`).

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
4. Optionnel : activer `Simulation seulement`.
5. Cliquer sur `Analyser` puis `Lancer la conversion`.
6. Contrôler le journal et exporter le log si nécessaire.

## Structure du projet

```text
MuniConvert/
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
├── README.md
├── LICENSE
├── CONTRIBUTING.md
└── CHANGELOG.md
```

## Limites actuelles

- Qualité de conversion dépendante de LibreOffice et des documents d’entrée.
- Traitement séquentiel (pas de parallélisation dans ce MVP).
- Pas encore de suite de tests unitaires automatisés.

## Feuille de route courte

- Ajouter des tests unitaires (filtrage, collisions, chemins cibles)
- Ajouter davantage de profils de conversion
- Ajouter un packaging `.app` signé/notarisé
- Améliorer le reporting de fin de lot

## Publication GitHub et versions

- Plan de releases : voir `docs/RELEASES.md`
- CI GitHub : `swift build` + `swift test` sur macOS à chaque `push` / `pull_request`

## Licence GPLv3

Ce projet est distribué sous licence **GNU General Public License v3.0**.

- Voir [LICENSE](LICENSE)
- Les fichiers source incluent un en-tête court `SPDX-License-Identifier: GPL-3.0-only`
