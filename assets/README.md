# Assets MuniConversion

Dépose ici les fichiers visuels utilisés par le packaging.

## Icône application

1. Place l'image source au format PNG dans:
   - `assets/AppIcon.png`
2. Le script de release génère automatiquement:
   - `assets/AppIcon.icns`
3. L'icône `.icns` est copiée dans `MuniConvert.app/Contents/Resources/AppIcon.icns` pendant `build_dist.sh`.

Recommandation image source:

- format carré (1024x1024 idéal)
- fond transparent ou fond uniforme
