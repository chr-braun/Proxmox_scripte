

## Installation und Verwendung:

**1. Script speichern:**
```bash
# Auf dem Proxmox-Host
nano /usr/local/bin/nas-mount.sh
# Script-Inhalt einfügen und speichern
```

**2. Ausführbar machen:**
```bash
chmod +x /usr/local/bin/nas-mount.sh
```

**3. Script ausführen:**
```bash
sudo /usr/local/bin/nas-mount.sh
```

## Features des Scripts:

- ✅ **Interaktive Eingabe** aller Parameter
- ✅ **Eingabe-Validierung** (IP-Adresse, Container-ID, etc.)
- ✅ **Versteckte Passwort-Eingabe**
- ✅ **Automatische SMB-Versions-Auswahl**
- ✅ **Sicherheitscheck** (Root-Rechte, Proxmox-Host)
- ✅ **Automatische MP-Nummer-Vergabe**
- ✅ **Container-Neustart**
- ✅ **Fehlerbehandlung**
- ✅ **Aufräumen** (temporäre Dateien löschen)

Das Script fragt dich nach:
- NAS IP-Adresse
- Freigabename
- Benutzername/Passwort
- Container-ID
- Gewünschter Pfad im Container
- SMB-Version
