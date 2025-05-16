#!/bin/bash

# Forensic Torrent Checker
# Description: This script collects forensic evidence of torrents downloaded using Transmission, qBittorrent, USB devices, Git configuration, and FileZilla.
# Author: Jo Provost
# Date: $(date)

OUTPUT_FILE="forensic_report_$(date +%Y%m%d_%H%M%S).txt"
echo "Forensic Torrent Checker Report" > "$OUTPUT_FILE"
echo "Date: $(date)" >> "$OUTPUT_FILE"
echo "" >> "$OUTPUT_FILE"

# Transmission Analysis
echo "=== Transmission Analysis ===" >> "$OUTPUT_FILE"
TRANSMISSION_DIR="$HOME/.config/transmission"
if [ -d "$TRANSMISSION_DIR" ]; then
    echo "[+] Transmission configuration found." >> "$OUTPUT_FILE"
    echo "- Torrent Files:" >> "$OUTPUT_FILE"
    ls -la "$TRANSMISSION_DIR/torrents/" >> "$OUTPUT_FILE" 2>/dev/null
    echo "- Resume Files:" >> "$OUTPUT_FILE"
    grep -Eo '"name": "[^"]+"' "$TRANSMISSION_DIR/resume/"*.resume >> "$OUTPUT_FILE" 2>/dev/null
    echo "- Download Directory:" >> "$OUTPUT_FILE"
    grep -Eo '"downloadDir": "[^"]+"' "$TRANSMISSION_DIR/settings.json" >> "$OUTPUT_FILE" 2>/dev/null
else
    echo "[-] No Transmission configuration found." >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"

# qBittorrent Analysis
echo "=== qBittorrent Analysis ===" >> "$OUTPUT_FILE"
QBITTORRENT_DIR="$HOME/.config/qBittorrent"
if [ -d "$QBITTORRENT_DIR" ]; then
    echo "[+] qBittorrent configuration found." >> "$OUTPUT_FILE"
    echo "- Torrent Files:" >> "$OUTPUT_FILE"
    ls -la "$QBITTORRENT_DIR/BT_backup/" >> "$OUTPUT_FILE" 2>/dev/null
    echo "- Files Downloaded:" >> "$OUTPUT_FILE"
    grep -Eo '"path": "[^"]+"' "$QBITTORRENT_DIR/BT_backup/"*.fastresume >> "$OUTPUT_FILE" 2>/dev/null
else
    echo "[-] No qBittorrent configuration found." >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"

# System USB Analysis (dmesg)
echo "=== USB Device Analysis ===" >> "$OUTPUT_FILE"
dmesg --ctime | grep -i 'usb' >> "$OUTPUT_FILE"
journalctl --grep="usb" --no-pager --output=short-iso >> "$OUTPUT_FILE" 2>/dev/null

echo "" >> "$OUTPUT_FILE"

# Git Configuration Analysis
echo "=== Git Configuration Analysis ===" >> "$OUTPUT_FILE"
GIT_CONFIG="$HOME/.gitconfig"
if [ -f "$GIT_CONFIG" ]; then
    echo "[+] Git configuration found." >> "$OUTPUT_FILE"
    cat "$GIT_CONFIG" >> "$OUTPUT_FILE"
else
    echo "[-] No Git configuration found." >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"

# FileZilla Configuration Analysis
echo "=== FileZilla Configuration Analysis ===" >> "$OUTPUT_FILE"
FILEZILLA_DIR="$HOME/.config/filezilla"
if [ -d "$FILEZILLA_DIR" ]; then
    echo "[+] FileZilla configuration found." >> "$OUTPUT_FILE"
    ls -la "$FILEZILLA_DIR" >> "$OUTPUT_FILE"
    cat "$FILEZILLA_DIR/recentservers.xml" >> "$OUTPUT_FILE" 2>/dev/null
else
    echo "[-] No FileZilla configuration found." >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"
echo "Forensic analysis complete. Report saved as $OUTPUT_FILE"
