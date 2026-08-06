#!/usr/bin/env bash
# Builds a private CA and a server certificate for the backend (section 8.3).
#
# The app pins the certificate, so the pair produced here is what the mobile
# client trusts — nothing else. Re-run this and you must update
# `app/lib/core/network/certificate_pinning.dart` with the new fingerprint,
# which the script prints at the end.
#
#   ./scripts/generate_certs.sh [extra-ip ...]
#
# 10.0.2.2 is always included: that is how the Android emulator reaches the
# host machine.

set -euo pipefail

CERT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/certs"
DAYS_CA=3650
DAYS_SERVER=825

mkdir -p "$CERT_DIR"
cd "$CERT_DIR"

EXTRA_IPS=()
if [[ $# -gt 0 ]]; then EXTRA_IPS=("$@"); fi
LAN_IP="$(ipconfig getifaddr en0 2>/dev/null || echo "")"

{
  echo "[req]"
  echo "distinguished_name = dn"
  echo "req_extensions = v3_req"
  echo "prompt = no"
  echo "[dn]"
  echo "C = IR"
  echo "O = Sharif University of Technology"
  echo "OU = FilmBin"
  echo "CN = filmbin.local"
  echo "[v3_req]"
  echo "basicConstraints = CA:FALSE"
  echo "keyUsage = digitalSignature, keyEncipherment"
  echo "extendedKeyUsage = serverAuth"
  echo "subjectAltName = @alt"
  echo "[alt]"
  echo "DNS.1 = filmbin.local"
  echo "DNS.2 = localhost"
  echo "IP.1 = 127.0.0.1"
  echo "IP.2 = 10.0.2.2"
  index=3
  if [[ -n "$LAN_IP" ]]; then
    echo "IP.${index} = ${LAN_IP}"
    index=$((index + 1))
  fi
  for ip in ${EXTRA_IPS[@]+"${EXTRA_IPS[@]}"}; do
    echo "IP.${index} = ${ip}"
    index=$((index + 1))
  done
} > server.cnf

echo "→ private certificate authority"
openssl genrsa -out ca.key 4096 2>/dev/null
openssl req -x509 -new -nodes -key ca.key -sha256 -days "$DAYS_CA" -out ca.crt \
  -subj "/C=IR/O=Sharif University of Technology/OU=FilmBin/CN=FilmBin Root CA"

echo "→ server certificate"
openssl genrsa -out server.key 2048 2>/dev/null
openssl req -new -key server.key -out server.csr -config server.cnf
openssl x509 -req -in server.csr -CA ca.crt -CAkey ca.key -CAcreateserial \
  -out server.crt -days "$DAYS_SERVER" -sha256 -extfile server.cnf -extensions v3_req

rm -f server.csr ca.srl

FINGERPRINT="$(openssl x509 -in server.crt -noout -fingerprint -sha256 |
  cut -d= -f2 | tr -d ':' | tr '[:upper:]' '[:lower:]')"

cat > pin.txt <<EOF
# SHA-256 fingerprint of certs/server.crt — paste into the Flutter client.
$FINGERPRINT
EOF

echo
echo "certificates written to $CERT_DIR"
echo "  ca.crt      → trust anchor (also bundled with the app)"
echo "  server.crt  → serve with uvicorn --ssl-certfile"
echo "  server.key  → serve with uvicorn --ssl-keyfile"
echo
echo "pinned SHA-256 fingerprint:"
echo "  $FINGERPRINT"
echo
echo "run over HTTPS with:"
echo "  uvicorn app.main:app --host 0.0.0.0 --port 8443 \\"
echo "      --ssl-certfile certs/server.crt --ssl-keyfile certs/server.key"
