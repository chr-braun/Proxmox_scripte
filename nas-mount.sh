#!/bin/bash

# NAS Mount Script für Proxmox LXC Container
# Autor: Automatisches Mounting von CIFS/SMB Freigaben

echo "=================================="
echo "    NAS Mount Script für Proxmox"
echo "=================================="
echo

# Prüfen ob das Script als root ausgeführt wird
if [ "$EUID" -ne 0 ]; then
    echo "❌ Dieses Script muss als root ausgeführt werden!"
    echo "Starte mit: sudo $0"
    exit 1
fi

# Prüfen ob wir auf dem Proxmox Host sind
if ! command -v pct &> /dev/null; then
    echo "❌ Dieses Script muss auf dem Proxmox-Host ausgeführt werden!"
    echo "Nicht im LXC-Container!"
    exit 1
fi

echo "📋 Bitte geben Sie die folgenden Informationen ein:"
echo

# NAS IP-Adresse
read -p "🌐 NAS IP-Adresse (z.B. 192.168.178.67): " nas_ip
if [[ ! $nas_ip =~ ^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$ ]]; then
    echo "❌ Ungültige IP-Adresse!"
    exit 1
fi

# Freigabename
read -p "📁 Freigabename auf dem NAS (z.B. Upload, video): " share_name
if [ -z "$share_name" ]; then
    echo "❌ Freigabename darf nicht leer sein!"
    exit 1
fi

# Benutzername
read -p "👤 Benutzername: " username
if [ -z "$username" ]; then
    echo "❌ Benutzername darf nicht leer sein!"
    exit 1
fi

# Passwort (versteckt eingeben)
read -sp "🔒 Passwort: " password
echo
if [ -z "$password" ]; then
    echo "❌ Passwort darf nicht leer sein!"
    exit 1
fi

# Container ID
read -p "📦 Container ID (z.B. 100): " container_id
if ! [[ "$container_id" =~ ^[0-9]+$ ]]; then
    echo "❌ Container ID muss eine Zahl sein!"
    exit 1
fi

# Prüfen ob Container existiert
if ! pct status $container_id &> /dev/null; then
    echo "❌ Container $container_id existiert nicht!"
    exit 1
fi

# Container-Pfad
read -p "📂 Pfad im Container (z.B. /srv/media/nas): " container_path
if [ -z "$container_path" ]; then
    echo "❌ Container-Pfad darf nicht leer sein!"
    exit 1
fi

# SMB Version
echo
echo "🔧 SMB Version wählen:"
echo "1) SMB 2.1 (Standard für Synology)"
echo "2) SMB 3.0 (Modern)"
echo "3) SMB 1.0 (Veraltet, nur für alte Systeme)"
read -p "Wählen Sie (1-3) [Standard: 1]: " smb_choice
case $smb_choice in
    2) smb_version="3.0" ;;
    3) smb_version="1.0" ;;
    *) smb_version="2.1" ;;
esac

echo
echo "📝 Zusammenfassung:"
echo "==================="
echo "NAS IP:          $nas_ip"
echo "Freigabe:        $share_name"
echo "Benutzername:    $username"
echo "Container ID:    $container_id"
echo "Container-Pfad:  $container_path"
echo "SMB Version:     $smb_version"
echo

read -p "❓ Soll das Mount erstellt werden? (j/N): " confirm
if [[ ! $confirm =~ ^[jJyY]$ ]]; then
    echo "❌ Abgebrochen."
    exit 0
fi

echo
echo "🚀 Starte Mounting-Prozess..."

# Host-Pfad erstellen
host_path="/mnt/nas-${share_name,,}"
echo "📁 Erstelle Host-Verzeichnis: $host_path"
mkdir -p "$host_path"

# Credentials-Datei erstellen
creds_file="/tmp/nas-creds-$$"
echo "🔐 Erstelle temporäre Credentials-Datei..."
cat > "$creds_file" << EOF
username=$username
password=$password
EOF
chmod 600 "$creds_file"

echo "🔗 Mounte NAS-Freigabe..."
# Mount-Befehl ausführen
if mount -t cifs "//$nas_ip/$share_name" "$host_path" -o "credentials=$creds_file,vers=$smb_version,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,noperm,nobrl"; then
    echo "✅ NAS-Freigabe erfolgreich gemountet!"
    
    # Credentials-Datei löschen
    rm -f "$creds_file"
    
    echo "📦 Füge Bind-Mount zu Container $container_id hinzu..."
    
    # Nächste freie MP-Nummer finden
    mp_num=0
    while pct config $container_id | grep -q "mp$mp_num:"; do
        ((mp_num++))
    done
    
    # Bind-Mount hinzufügen
    if pct set $container_id -mp$mp_num "$host_path,mp=$container_path,acl=1"; then
        echo "✅ Bind-Mount erfolgreich hinzugefügt!"
        
        echo "🔄 Starte Container neu..."
        if pct restart $container_id; then
            echo "✅ Container erfolgreich neugestartet!"
            echo
            echo "🎉 Setup abgeschlossen!"
            echo "=================================="
            echo "Die NAS-Freigabe ist jetzt verfügbar unter:"
            echo "Container-Pfad: $container_path"
            echo "Host-Pfad:      $host_path"
            echo
            echo "💡 Für Kopier-Vorgänge verwenden Sie:"
            echo "rsync -r --no-perms --no-owner --no-group --no-times /quelle/ $container_path/"
            echo
            echo "📋 Für permanentes Mount fügen Sie folgende Zeile zu /etc/fstab hinzu:"
            echo "//$nas_ip/$share_name $host_path cifs username=$username,password=***,vers=$smb_version,uid=1000,gid=1000,file_mode=0777,dir_mode=0777,noperm,nobrl 0 0"
        else
            echo "❌ Fehler beim Neustart des Containers!"
        fi
    else
        echo "❌ Fehler beim Hinzufügen des Bind-Mounts!"
        umount "$host_path"
    fi
else
    echo "❌ Fehler beim Mounten der NAS-Freigabe!"
    echo "Mögliche Ursachen:"
    echo "- Falsche IP-Adresse oder Freigabename"
    echo "- Falsche Anmeldedaten"
    echo "- NAS nicht erreichbar"
    echo "- SMB-Version nicht unterstützt"
    rm -f "$creds_file"
    exit 1
fi

# Credentials-Datei sicherheitshalber nochmal löschen
rm -f "$creds_file"

echo
echo "✨ Fertig! Viel Spaß mit Ihrem NAS-Mount!"
