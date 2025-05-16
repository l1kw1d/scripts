find ~ -name ".bash_history*" -type f | while read -r file; do 
    grep -E 's3|mount|gdrive' "$file" | while read -r line; do 
        stat --format="%y %n" "$file" | awk -v start="2025-03-23" -v end="2025-04-05" '
        { 
            if ($1 >= start && $1 <= end) 
                print "[" $1 "] " file ": " line 
        }'
    done
done
