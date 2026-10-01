#!/bin/bash
# Creates a self-signed code signing certificate "MultiDock Local Signing" in your login keychain.
# Builds signed with it keep macOS permissions (Accessibility) across rebuilds; ad-hoc builds lose them.
# Safe to run again: does nothing if the certificate already exists. macOS asks for your password once.
set -euo pipefail
NAME="MultiDock Local Signing"
KEYCHAIN="$HOME/Library/Keychains/login.keychain-db"

if security find-identity -v -p codesigning | grep -q "\"$NAME\""; then
    echo "\"$NAME\" already exists"; exit 0
fi

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT
cat > "$TMP/cert.conf" <<CONF
[req]
distinguished_name = dn
x509_extensions = ext
prompt = no
[dn]
CN = $NAME
[ext]
basicConstraints = critical, CA:false
keyUsage = critical, digitalSignature
extendedKeyUsage = critical, codeSigning
CONF
openssl req -x509 -newkey rsa:2048 -nodes -days 3650 -config "$TMP/cert.conf" \
    -keyout "$TMP/key.pem" -out "$TMP/cert.pem" 2>/dev/null
# The .p12 only carries the key into the keychain; its password never leaves this temp folder
P12PASS=$(openssl rand -hex 16)
openssl pkcs12 -export -inkey "$TMP/key.pem" -in "$TMP/cert.pem" -name "$NAME" \
    -out "$TMP/id.p12" -passout "pass:$P12PASS"
security import "$TMP/id.p12" -k "$KEYCHAIN" -P "$P12PASS" -T /usr/bin/codesign >/dev/null
echo "Trusting the certificate for code signing (macOS asks for your password)..."
security add-trusted-cert -r trustRoot -p codeSign -k "$KEYCHAIN" "$TMP/cert.pem"
security find-identity -v -p codesigning | grep "\"$NAME\""
