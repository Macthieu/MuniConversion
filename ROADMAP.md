# Roadmap MuniConversion

Cette feuille de route garde MuniConversion simple, local, et maintenable.

## Court terme (v1.2.x)

- Stabiliser et valider l'interface multilingue (FR / EN / ES)
- Ajouter des tests dédiés à la localisation (clés critiques)
- Finaliser les workflows GitHub Actions sans warnings de runtime obsolète
- Affiner les messages d'erreur utilisateur (accès fichiers, collisions, LibreOffice)

## Moyen terme (v1.3.x - v1.5.x)

- Ajouter de nouveaux profils de conversion utiles (ODT/ODS/ODP inverse, images vers PDF si pertinent)
- Ajouter des presets utilisateur (ensembles d'options sauvegardables)
- Ajouter un mode "traitement incrémental" (ignorer fichiers déjà traités)
- Ajouter une meilleure visualisation du journal (filtres par statut, recherche)

## Long terme (v2.x)

- Packager une distribution signée + notarisée (quand compte Apple Developer disponible)
- Préparer une architecture de convertisseurs extensible (autres moteurs que LibreOffice)
- Ajouter une stratégie de tests d'intégration de bout en bout sur échantillons documentaires
- Améliorer la résilience sur gros volumes (performance, parallélisme contrôlé)

## Principes directeurs

- Ne jamais modifier les originaux
- Favoriser la prévisibilité des résultats
- Garder une architecture simple et lisible
- Privilégier les dépendances minimales
