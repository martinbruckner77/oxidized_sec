# Oxidized Secure – Inbetriebnahme (Teststand)

> **Nicht produktionsfreigegeben.** Diese Entwicklung liegt ausschließlich im Branch `feature/aes256-gcm-secrets`. Der Original-Branch `master` bleibt unverändert. Ein Hardware-End-to-End-Test und ein vollständiger Sicherheitsreview sind weiterhin notwendig.

## Architektur

Gerätepasswörter stehen als `enc:v1:...`-Token in der CSV-Quelle oder in Gruppen-/Modelleinstellungen. Die Entschlüsselung findet erst **nach** der regulären Vorrangauflösung der Oxidized-Konfiguration statt, direkt bei der Erstellung der Geräteauthentifizierung. Ein Klartextpasswort wird abgelehnt. Der Schlüssel liegt als separate, vom Dienstbenutzer kontrollierte 32-Byte-Datei außerhalb des Git-Repositories.

Achtung: Dieser Stand schützt primär das Anmeldepasswort. Andere Gerätegeheimnisse in `vars`, alternative Quellen und im gesicherten Konfigurationstext müssen vor Produktiveinsatz separat geprüft werden. Einige Geräte benötigen ein Enable-Passwort.

## Ubuntu 24.04 / Beispielgerät 192.168.1.1

**Das ursprünglich im Chat gepostete Passwort muss geändert werden; es wird hier bewusst nicht reproduziert.**

1. Den Fork und den Testbranch klonen:

```bash
git clone --branch feature/aes256-gcm-secrets https://github.com/martinbruckner77/oxidized_sec.git
cd oxidized_sec
```

2. Abhängigkeiten nach `README.md` des Projekts installieren und Oxidized **aus dieser Arbeitskopie** starten. Das regulär installierte Upstream-Gem enthält die Änderungen nicht. `bundle install` und ggf. `bundle exec` sind abhängig vom vorhandenen Gemfile zu verwenden.

3. Separaten Dienstbenutzer und Key-Datei einrichten:

```bash
sudo adduser --system --group --home /var/lib/oxidized oxidized
sudo install -d -m 0700 -o oxidized -g oxidized /etc/oxidized/secrets
sudo sh -c 'umask 077; head -c 32 /dev/urandom > /etc/oxidized/secrets/key.bin'
sudo chown oxidized:oxidized /etc/oxidized/secrets/key.bin
sudo chmod 0600 /etc/oxidized/secrets/key.bin
```

4. Als Dienstbenutzer Passwort verschlüsseln. Die Eingabe erfolgt verdeckt und darf **nicht** als Shell-Argument verwendet werden:

```bash
sudo -u oxidized env OXIDIZED_CREDENTIAL_KEY_FILE=/etc/oxidized/secrets/key.bin ruby bin/oxidized-credential encrypt
```

5. `/var/lib/oxidized/.config/oxidized/router.db` (Verzeichnis ggf. vorher als oxidized erstellen):

```text
192.168.1.1;procurve;Administrator;enc:v1:HIER_TOKEN_EINFUEGEN
```

**`procurve` ist nur ein Beispiel**: Hersteller und Modell der IP 192.168.1.1 wurden noch nicht bestätigt. Für Cisco IOS z. B. `ios`, für FortiGate `fortios` je nach tatsächlich unterstützter Variante.

6. Beispiel `/var/lib/oxidized/.config/oxidized/config`:

```yaml
---
username: Administrator
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
    repo: /var/lib/oxidized/configs.git
source:
  default: csv
  csv:
    file: /var/lib/oxidized/.config/oxidized/router.db
    delimiter: !ruby/regexp /;/
    map:
      name: 0
      model: 1
      username: 2
      password: 3
```

Dateien `config` und `router.db` mit Modus 0600, Elternverzeichnis 0700, Besitzer oxidized. Systemd-Unit muss `Environment=OXIDIZED_CREDENTIAL_KEY_FILE=/etc/oxidized/secrets/key.bin` setzen und unter `User=oxidized` laufen.

7. Tests ausführen und erfolgreichen Git-Commit einer **echten** Switch-Konfiguration sowie Folgeversion nach Teständerung prüfen. Verifiziere den SSH-Host-Key unabhängig vor dem Verbinden; sichere Konfigurationen können ihrerseits sensible Geheimnisse enthalten.

## Freigabecheckliste

- [ ] Ruby-Tests der Verschlüsselung und der Node-Integration erfolgreich
- [ ] Klartext- und falsch verschlüsselte Gerätepasswörter werden ohne Rückfall abgelehnt
- [ ] Gesicherte SSH-Host-Key-Prüfung aktiv, kein Telnet-Fallback
- [ ] `vars`, alternative Quellen, Hooks und API auf Secret-Leaks geprüft
- [ ] Konfigurationsarchiv gegen unberechtigten Zugriff und Secret-Leaks geschützt
- [ ] Restore, Schlüsselverlust und Schlüsselrotation getestet
- [ ] End-to-End-Test am tatsächlichen Switch `192.168.1.1` erfolgreich

**Keine Produktivfreigabe, bevor die Liste vollständig geprüft ist.**
