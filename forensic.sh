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
echo "=== Transmission Analysis (23 March - 5 April 2025) ===" >> "$OUTPUT_FILE"
TRANSMISSION_DIR="$HOME/.config/transmission"
if [ -d "$TRANSMISSION_DIR" ]; then
    echo "[+] Transmission configuration found." >> "$OUTPUT_FILE"
    echo "- Torrent Files (Filtered by Date):" >> "$OUTPUT_FILE"
    find "$TRANSMISSION_DIR/torrents/" -type f -newermt "2025-03-23" ! -newermt "2025-04-06" -exec ls -la {} \; >> "$OUTPUT_FILE" 2>/dev/null
else
    echo "[-] No Transmission configuration found." >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"

# qBittorrent Analysis
echo "=== qBittorrent Analysis (23 March - 5 April 2025) ===" >> "$OUTPUT_FILE"
QBITTORRENT_DIR="$HOME/.config/qBittorrent"
if [ -d "$QBITTORRENT_DIR" ]; then
    echo "[+] qBittorrent configuration found." >> "$OUTPUT_FILE"
    echo "- Files Downloaded (Filtered by Date):" >> "$OUTPUT_FILE"
    find "$QBITTORRENT_DIR/BT_backup/" -type f -newermt "2025-03-23" ! -newermt "2025-04-06" -exec grep -Eo '"path": "[^"]+"' {} \; >> "$OUTPUT_FILE" 2>/dev/null
else
    echo "[-] No qBittorrent configuration found." >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"

# System USB Analysis (Filtered by Date)
echo "=== USB Device Analysis (23 March - 5 April 2025) ===" >> "$OUTPUT_FILE"
journalctl --grep="usb" --since "2025-03-23" --until "2025-04-05" --no-pager --output=short-iso >> "$OUTPUT_FILE" 2>/dev/null

echo "" >> "$OUTPUT_FILE"

# Git Configuration Analysis (No Date Filtering)
echo "=== Git Configuration Analysis ===" >> "$OUTPUT_FILE"
GIT_CONFIG="$HOME/.gitconfig"
if [ -f "$GIT_CONFIG" ]; then
    echo "[+] Git configuration found." >> "$OUTPUT_FILE"
    cat "$GIT_CONFIG" >> "$OUTPUT_FILE"
else
    echo "[-] No Git configuration found." >> "$OUTPUT_FILE"
fi

echo "" >> "$OUTPUT_FILE"

# FileZilla Configuration Analysis (No Date Filtering)
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
