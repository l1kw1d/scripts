#!/bin/bash

# Script d’analyse SOC/MSP pour fichiers .eml — Version stable
set -euo pipefail

IPINFO_API_KEY="put_your_token"
VT_API_KEY="Put_your_key"
RBL_LIST=("zen.spamhaus.org" "bl.spamcop.net" "b.barracudacentral.org" "dnsbl.sorbs.net")
USER_AGENT="EmailSecAnalyzer/Stable"

TMPDIR=$(mktemp -d)
LOGFILE="email_analysis_$(date +%Y%m%d_%H%M%S).log"

cleanup() {
    rm -rf "$TMPDIR"
    echo "[*] Nettoyage terminé. Rapport : $LOGFILE"
}
trap cleanup EXIT

log() {
    echo -e "[$(date '+%Y-%m-%d %H:%M:%S')] $1" | tee -a "$LOGFILE"
}

check_requirements() {
    for cmd in curl jq whois grep awk sed file openssl ripmime host; do
        if ! command -v "$cmd" >/dev/null; then
            echo "Manque la commande : $cmd" >&2
            exit 1
        fi
    done
}

analyze_headers() {
    local file="$1"
    log "📬 Analyse des entêtes"
    grep -a -E '^(From:|Return-Path:|Received:|Message-ID:|DKIM-Signature:|Received-SPF:)' "$file" | tee -a "$LOGFILE"

    FROM=$(grep -a -i '^From:' "$file" | head -n1 | sed 's/^From:[ 	]*//I')
    RETURN=$(grep -a -i '^Return-Path:' "$file" | head -n1 | sed 's/^Return-Path:[ 	]*//I' | tr -d '<>')
    if [[ "$FROM" != *"$RETURN"* ]]; then
        log "⚠️  Spoofing potentiel détecté : FROM ≠ RETURN-PATH"
    fi
}

check_ip() {
    local ip="$1"
    log "🔎 IP: $ip"
    whois "$ip" | head -n 10 | sed 's/^/    WHOIS: /' | tee -a "$LOGFILE"

    log "    🔍 IPInfo:"
    curl -sS "https://ipinfo.io/$ip?token=$IPINFO_API_KEY" | jq -r 'to_entries[] | "    \(.key): \(.value)"' | tee -a "$LOGFILE"

    for rbl in "${RBL_LIST[@]}"; do
        rev_ip=$(echo "$ip" | awk -F. '{print $4"."$3"."$2"."$1}')
        if host "$rev_ip.$rbl" >/dev/null 2>&1; then
            log "    ⚠️  Listé sur $rbl"
        else
            log "    OK: non listé sur $rbl"
        fi
    done
}

analyze_ips() {
    local file="$1"
    log "🌐 Analyse des IPs dans 'Received:'"
    grep -a -i "^Received:" "$file" | grep -Eo '([0-9]{1,3}\.){3}[0-9]{1,3}' | sort -u | while read -r ip; do
        check_ip "$ip"
    done
}

analyze_emails() {
    local file="$1"
    log "📨 Extraction des adresses email"
    grep -a -E -o "[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,6}" "$file" | sort -u | while read -r email; do
        domain="${email#*@}"
        log "📧 $email — MX de $domain :"
        host -t mx "$domain" 2>&1 | sed 's/^/    /' | tee -a "$LOGFILE"
    done
}

extract_attachments() {
    local file="$1"
    log "📎 Extraction des pièces jointes"
    ripmime -i "$file" -d "$TMPDIR" --no-nameless >/dev/null 2>&1
    find "$TMPDIR" -type f ! -name '*.txt' ! -name '*.html' | while read -r att; do
        hash=$(openssl dgst -sha256 "$att" | awk '{print $2}')
        log "🗂 $(basename "$att") - SHA256: $hash"
        if [[ -n "$VT_API_KEY" ]]; then
            curl -sS -H "x-apikey: $VT_API_KEY" "https://www.virustotal.com/api/v3/files/$hash" |
                jq -r '.data.attributes.last_analysis_stats.malicious' | sed 's/^/    VT: Malicious score: /'
        fi
    done
}

extract_links() {
    local file="$1"
    log "🌐 Liens extraits du message"
    grep -a -o -E '(http|https)://[^"<>[:space:]]+' "$file" | sort -u | sed 's/^/🔗 /' | tee -a "$LOGFILE"
}

main() {
    check_requirements
    local file="$1"
    [ ! -f "$file" ] && { echo "Fichier introuvable: $file" >&2; exit 1; }

    analyze_headers "$file"
    analyze_ips "$file"
    analyze_emails "$file"
    extract_attachments "$file"
    extract_links "$file"

    log "✅ Analyse terminée"
}

main "$@"
