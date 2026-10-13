# Docker-Installer (experimentell)

**Nicht produktionsfreigegeben.** Dieser Branch integriert verschlüsselte SSH-Anmeldepasswörter, aber weitere Geräte-Secrets (`vars`, Enable-Passwörter), Log-Ausgaben und Backups sind noch nicht vollständig geprüft.

## Installation auf Ubuntu 24.04

Docker Engine inklusive Compose-Plugin installieren. Anschließend:

```bash
git clone --branch feature/aes256-gcm-secrets https://github.com/martinbruckner77/oxidized_sec.git
cd oxidized_sec
sudo bash deploy/install-docker.sh
sudo bash deploy/add-switch.sh
sudo docker compose -f docker-compose.secure.yml up -d
sudo docker compose -f docker-compose.secure.yml logs -f --tail=100
```

Der Installer baut das Image aus dem **lokalen Fork**, erstellt einen eigenen 32-Byte-AES-Schlüssel unter `deploy/data/secrets/key.bin` und legt Konfiguration sowie Geräteliste unter `deploy/data/config/` ab. Bereits vorhandene Schlüssel werden **nicht überschrieben**. Der Schlüssel wird read-only in den Container gemountet. Der Dienst läuft im Container mit UID 30000.

`add-switch.sh` fragt IP, Modell, Benutzer und Passwort ab. Die Passwort-Eingabe ist verdeckt. Die Verschlüsselung erfolgt im Container; in `router.db` landet nur `enc:v1:...`. Pro Switch eine Zeile. Das Gerätemodell muss zur tatsächlichen Hardware passen.

**Für den Switch 192.168.1.1**: IP `192.168.1.1`, Benutzer `Administrator`; `procurve` nur wählen, wenn das Gerät wirklich ein kompatibler HP-ProCurve-Switch ist. Das zuvor im Chat genannte Passwort vor Verwendung ändern.

## Sicherheitsgrenzen

* Der AES-Schlüssel ist lokal vorhanden. Root oder ein kompromittierter Oxidized-Prozess kann Zugangsdaten entschlüsseln.
* `deploy/data` niemals committen oder in öffentliche Backups aufnehmen. Key und Konfigurationsarchive getrennt sichern.
* Das Image veröffentlicht keine Netzwerkports. Eine Weboberfläche muss gesondert abgesichert werden.
* SSH-Host-Key-Prüfung unabhängig verifizieren, kein Telnet-Fallback.
* Für den Produktivbetrieb müssen Tests am konkreten Gerät, Schlüsselrotation, Backup/Restore und die Verarbeitung aller weiteren Secrets geprüft werden.
* Der Container wird aus dem Git-Stand gebaut; Abhängigkeiten sind nicht vollständig gepinnt. Vor produktivem Einsatz Versionen fixieren und Image prüfen.

## Diagnose

```bash
sudo docker compose -f docker-compose.secure.yml ps
sudo docker compose -f docker-compose.secure.yml logs --tail=150
sudo cat deploy/data/config/router.db
```

**Vorsicht:** `router.db` enthält vertrauliche Tokens, auch wenn die Passwörter verschlüsselt sind.
