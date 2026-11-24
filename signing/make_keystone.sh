#!/usr/bin/env bash
# Makes the keystone key ONCE (run by .github/workflows/make_keystone.yml, never by hand).
# Writes signing/keystone.keystore.enc (encrypted with $KEYSTONE_PASS) + signing/keystone.sha256
# (the public fingerprint CI checks against). Refuses if a keystone already exists.
set -euo pipefail
cd "$(dirname "$0")/.."
ENC=signing/keystone.keystore.enc
FP=signing/keystone.sha256
if [ -f "$ENC" ]; then
  echo "::error::$ENC already exists. The keystone is never replaced (installed games could never update)."
  exit 1
fi
P=$(printf '%s' "${KEYSTONE_PASS:-}" | tr -d '[:space:]`')
if [ "${#P}" -lt 20 ]; then
  echo "::error::KEYSTONE_PASS secret missing or under 20 characters (spaces don't count). Use 5+ random words."
  exit 1
fi
export P
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
keytool -genkeypair -keystore "$TMP/ks" -storetype PKCS12 -storepass android -keypass android \
  -alias androiddebugkey -keyalg RSA -keysize 4096 -validity 36500 \
  -dname "CN=Keystone Games Key,O=Wild Dreams,C=US" 2>&1 | grep -v JAVA_TOOL_OPTIONS || true
openssl enc -aes-256-cbc -pbkdf2 -iter 200000 -salt -in "$TMP/ks" -out "$ENC" -pass env:P
# Round trip: the committed file must unlock with the same secret.
openssl enc -d -aes-256-cbc -pbkdf2 -iter 200000 -in "$ENC" -out "$TMP/back" -pass env:P
cmp -s "$TMP/ks" "$TMP/back"
keytool -list -keystore "$TMP/ks" -storepass android 2>/dev/null \
  | grep -o '[0-9A-F]\{2\}\(:[0-9A-F]\{2\}\)\{31\}' | head -1 > "$FP"
test -s "$FP"
echo "Keystone made. SHA-256: $(cat "$FP")"
