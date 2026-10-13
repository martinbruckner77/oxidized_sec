#!/usr/bin/env bash
set -Eeuo pipefail
umask 077
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
[[ "$(id -u)" -eq 0 ]] || { echo "Bitte mit sudo ausführen." >&2; exit 1; }
[[ -f deploy/data/secrets/key.bin && -f deploy/data/config/router.db ]] || { echo "Zuerst Installer ausführen." >&2; exit 1; }
read -r -p "IP-Adresse/Hostname: " HOST
read -r -p "Oxidized-Modell (z.B. procurve oder ios): " MODEL
read -r -p "SSH-Benutzername: " USERNAME
for value in "$HOST" "$MODEL" "$USERNAME"; do
  [[ -n "$value" && "$value" != *';'* && "$value" != *$'\n'* && "$value" != *$'\r'* ]] || { echo "Ungültige Eingabe." >&2; exit 1; }
done
DB=deploy/data/config/router.db
if awk -F';' -v h="$HOST" '$1==h {found=1} END {exit !found}' "$DB"; then
  echo "Gerät existiert bereits. Bitte bestehende Zeile gezielt bearbeiten, um Duplikate zu vermeiden." >&2
  exit 1
fi
echo "Passwort wird verdeckt abgefragt und direkt im Container verschlüsselt."
read -r -s -p "Switch-Passwort: " PASSWORD </dev/tty\necho >&2\nTOKEN="$(printf '%s\\n' "$PASSWORD" | docker compose -f docker-compose.secure.yml run --rm --no-deps -T --entrypoint /usr/local/bin/oxidized-credential oxidized encrypt)" || exit 1\nunset PASSWORD
[[ "$TOKEN" == enc:v1:* ]] || { echo "Verschlüsselung fehlgeschlagen." >&2; exit 1; }
printf '%s;%s;%s;%s\n' "$HOST" "$MODEL" "$USERNAME" "$TOKEN" >> "$DB"
chown 30000:30000 "$DB"; chmod 0600 "$DB"
echo "Gerät hinzugefügt. Bei laufendem Dienst: sudo docker compose -f docker-compose.secure.yml restart oxidized"
