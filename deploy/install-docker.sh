#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ "$(id -u)" -eq 0 ]] || { echo "Bitte mit sudo ausführen: sudo bash deploy/install-docker.sh" >&2; exit 1; }
command -v docker >/dev/null || { echo "Docker fehlt." >&2; exit 1; }
docker compose version >/dev/null || { echo "Docker Compose Plugin fehlt." >&2; exit 1; }
[[ -f docker-compose.secure.yml ]] || { echo "Compose-Datei fehlt." >&2; exit 1; }
mkdir -p deploy/data/config deploy/data/secrets
chown -R 30000:30000 deploy/data
chmod 0700 deploy/data/config deploy/data/secrets
KEY=deploy/data/secrets/key.bin
if [[ ! -e "$KEY" ]]; then
  head -c 32 /dev/urandom > "$KEY"
  chown 30000:30000 "$KEY"
  chmod 0600 "$KEY"
  echo "Neuer AES-Schlüssel erstellt. Separat sicher sichern!"
else
  echo "Vorhandener AES-Schlüssel bleibt unverändert."
fi
[[ "$(stat -c %s "$KEY")" == 32 ]] || { echo "Ungültige Schlüssellänge." >&2; exit 1; }
CONFIG=deploy/data/config/config
DB=deploy/data/config/router.db
if [[ ! -e "$CONFIG" ]]; then
cat > "$CONFIG" <<'YAML'
---
username: null
password: null
interval: 3600
resolve_dns: false
input:
  default: ssh
  ssh:
    secure: true
output:
  default: git
  git:
    user: Oxidized
    email: oxidized@localhost
    repo: /home/oxidized/.config/oxidized/configs.git
source:
  default: csv
  csv:
    file: /home/oxidized/.config/oxidized/router.db
    delimiter: !ruby/regexp /;/
    map:
      name: 0
      model: 1
      username: 2
      password: 3
YAML
fi
[[ -e "$DB" ]] || printf '# ip;model;username;encrypted-password\n' > "$DB"
chown 30000:30000 "$CONFIG" "$DB"
chmod 0600 "$CONFIG" "$DB"
echo "Baue Oxidized Secure Image (kann mehrere Minuten dauern)..."
docker compose -f docker-compose.secure.yml build
echo
echo "Installiert. Gerät hinzufügen mit: sudo bash deploy/add-switch.sh"
echo "Danach starten: sudo docker compose -f docker-compose.secure.yml up -d"
echo "Logs: sudo docker compose -f docker-compose.secure.yml logs -f --tail=100"
echo "Keine Produktivfreigabe ohne erfolgreiches End-to-End- und Sicherheitsreview."
