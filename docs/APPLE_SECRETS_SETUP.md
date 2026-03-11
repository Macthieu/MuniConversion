# Apple Secrets Setup (GitHub Actions)

## 1) Exporter le certificat Developer ID en `.p12`

Depuis Trousseau d'accès (Keychain Access), exporter le certificat + clé privée en `.p12`.

## 2) Convertir le certificat en base64

```bash
base64 -i certificate.p12 | pbcopy
```

Ajouter la valeur dans le secret GitHub: `APPLE_CERTIFICATE_BASE64`.

## 3) Secrets requis

- `APPLE_CERTIFICATE_BASE64`
- `APPLE_CERTIFICATE_PASSWORD`
- `APPLE_CODESIGN_IDENTITY`
- `KEYCHAIN_PASSWORD`
- `APPLE_ID`
- `APPLE_APP_SPECIFIC_PASSWORD`
- `APPLE_TEAM_ID`

## Option rapide (recommandée): script automatique

Depuis la racine du repo:

```bash
bash scripts/release/configure_github_secrets.sh --repo Macthieu/MuniConvert --cert /chemin/vers/certificate.p12
```

Le script configure tous les secrets requis dans GitHub.

## 4) Vérifier l'identité locale

```bash
security find-identity -v -p codesigning
```

Utiliser exactement cette identité pour `APPLE_CODESIGN_IDENTITY`.
