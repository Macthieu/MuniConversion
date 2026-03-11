#!/usr/bin/env bash
set -euo pipefail

REPO="${REPO:-Macthieu/MuniConvert}"
CERT_PATH="${CERT_PATH:-}"

usage() {
  cat <<USAGE
Usage:
  scripts/release/configure_github_secrets.sh [--repo owner/repo] [--cert /path/certificate.p12]

Description:
  Configure all Apple-related GitHub secrets required by release-macos workflow.

Secrets configured:
  - APPLE_CERTIFICATE_BASE64
  - APPLE_CERTIFICATE_PASSWORD
  - APPLE_CODESIGN_IDENTITY
  - KEYCHAIN_PASSWORD
  - APPLE_ID
  - APPLE_APP_SPECIFIC_PASSWORD
  - APPLE_TEAM_ID

You can provide values via environment variables, or interactively when prompted.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --repo)
      REPO="$2"
      shift 2
      ;;
    --cert)
      CERT_PATH="$2"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "Unknown argument: $1" >&2
      usage
      exit 1
      ;;
  esac
done

prompt_required() {
  local var_name="$1"
  local prompt_text="$2"
  local secret_mode="${3:-false}"

  if [[ -n "${!var_name:-}" ]]; then
    return
  fi

  if [[ "$secret_mode" == "true" ]]; then
    read -r -s -p "$prompt_text: " "$var_name"
    echo
  else
    read -r -p "$prompt_text: " "$var_name"
  fi

  if [[ -z "${!var_name}" ]]; then
    echo "[error] $var_name is required." >&2
    exit 1
  fi
}

if [[ -z "$CERT_PATH" ]]; then
  read -r -p "Path to .p12 certificate file: " CERT_PATH
fi

if [[ ! -f "$CERT_PATH" ]]; then
  echo "[error] Certificate file not found: $CERT_PATH" >&2
  exit 1
fi

# Inputs (env-first, interactive fallback)
prompt_required APPLE_CERTIFICATE_PASSWORD "Certificate password" true
prompt_required APPLE_CODESIGN_IDENTITY "Codesign identity (e.g. Developer ID Application: ... )"
prompt_required KEYCHAIN_PASSWORD "Temporary keychain password for runner" true
prompt_required APPLE_ID "Apple ID email"
prompt_required APPLE_APP_SPECIFIC_PASSWORD "Apple app-specific password" true
prompt_required APPLE_TEAM_ID "Apple Team ID"

if ! command -v gh >/dev/null 2>&1; then
  echo "[error] gh CLI is required." >&2
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "[error] gh auth is not configured. Run: gh auth login" >&2
  exit 1
fi

APPLE_CERTIFICATE_BASE64="$(base64 -i "$CERT_PATH" | tr -d '\n')"

echo "[info] Setting secrets for repo: $REPO"

printf "%s" "$APPLE_CERTIFICATE_BASE64" | gh secret set APPLE_CERTIFICATE_BASE64 --repo "$REPO"
printf "%s" "$APPLE_CERTIFICATE_PASSWORD" | gh secret set APPLE_CERTIFICATE_PASSWORD --repo "$REPO"
printf "%s" "$APPLE_CODESIGN_IDENTITY" | gh secret set APPLE_CODESIGN_IDENTITY --repo "$REPO"
printf "%s" "$KEYCHAIN_PASSWORD" | gh secret set KEYCHAIN_PASSWORD --repo "$REPO"
printf "%s" "$APPLE_ID" | gh secret set APPLE_ID --repo "$REPO"
printf "%s" "$APPLE_APP_SPECIFIC_PASSWORD" | gh secret set APPLE_APP_SPECIFIC_PASSWORD --repo "$REPO"
printf "%s" "$APPLE_TEAM_ID" | gh secret set APPLE_TEAM_ID --repo "$REPO"

echo "[ok] Secrets configured."
echo "[next] Run workflow: Release macOS App (workflow_dispatch) or push a new tag v*."
