#!/bin/bash
TIMESTAMP="$1"
TORRENT_URL="$2"
REPO="$3"
BRANCH="${4:-main}"

MANIFEST_FILE="history/${TIMESTAMP}/manifest.json"
HISTORY_README="history/README.md"

if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: Manifest not found at $MANIFEST_FILE"
    exit 1
fi

TEHRAN_TIME=$(TZ='Asia/Tehran' date +'%Y-%m-%d %H:%M')
DOWNLOAD_DIR=$(jq -r '.download_dir' "$MANIFEST_FILE")

# Start building entry
ENTRY="### 📅 ${TEHRAN_TIME} (Tehran)"$'\n\n'
ENTRY+="**Torrent/Magnet:**"$'\n'
ENTRY+='```'$'\n'"${TORRENT_URL}"$'\n''```'$'\n\n'
ENTRY+="**Files:**"$'\n\n'

# Process files
while IFS= read -r file_json; do
    FILE_PATH=$(echo "$file_json" | jq -r '.path')
    FILE_SIZE=$(echo "$file_json" | jq -r '.size_human')
    ENCODED_PATH=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$FILE_PATH")
    DOWNLOAD_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${DOWNLOAD_DIR}/${ENCODED_PATH}"
    
    if [[ "$FILE_PATH" =~ \.7z\.([0-9]{3})$ ]]; then
        # Split file part
        BASE_NAME="${FILE_PATH%.7z.*}"
        PART_NUM="${BASH_REMATCH[1]}"
        echo "${BASE_NAME}|${FILE_PATH}|${FILE_SIZE}|${DOWNLOAD_URL}" >> /tmp/split_files.txt
    else
        # Normal file
        case "$FILE_PATH" in
            *.zip) ICON="🗜️" ;;
            *.mkv|*.mp4|*.avi|*.mov) ICON="🎬" ;;
            *.mp3|*.flac|*.ogg|*.m4a) ICON="🎵" ;;
            *.jpg|*.png|*.gif|*.webp) ICON="🖼️" ;;
            *.pdf) ICON="📕" ;;
            *) ICON="📄" ;;
        esac
        ENTRY+="- ${ICON} [**${FILE_PATH}**](${DOWNLOAD_URL}) - ${FILE_SIZE}"$'\n'
    fi
done < <(jq -c '.files[]' "$MANIFEST_FILE")

# Process split file groups
if [ -f /tmp/split_files.txt ]; then
    # Get unique base names
    cut -d'|' -f1 /tmp/split_files.txt | sort -u | while read -r BASE_NAME; do
        TOTAL_SIZE=0
        PARTS=()
        while IFS='|' read -r base path size url; do
            if [ "$base" = "$BASE_NAME" ]; then
                PARTS+=("$path|$size|$url")
                SIZE_NUM=$(echo "$size" | sed 's/[^0-9.]//g')
                TOTAL_SIZE=$((TOTAL_SIZE + SIZE_NUM))
            fi
        done < /tmp/split_files.txt
        
        TOTAL_SIZE_HUMAN=$(numfmt --to=iec $TOTAL_SIZE 2>/dev/null || echo "${TOTAL_SIZE} bytes")
        ENTRY+=$'\n'"- 📦 **${BASE_NAME}.7z** (Split Archive - ${TOTAL_SIZE_HUMAN} total)"$'\n'
        
        PART_NUM=1
        TOTAL_PARTS=${#PARTS[@]}
        for part_info in "${PARTS[@]}"; do
            IFS='|' read -r path size url <<< "$part_info"
            if [ $PART_NUM -eq $TOTAL_PARTS ]; then
                PREFIX="  └─"
            else
                PREFIX="  ├─"
            fi
            ENTRY+="${PREFIX} 📎 [**${path}**](${url}) - ${size}"$'\n'
            PART_NUM=$((PART_NUM + 1))
        done
        ENTRY+="  💡 *Download all parts, then:* \`7z x ${PARTS[0]%%|*}\`"$'\n'
    done
    rm /tmp/split_files.txt
fi

ENTRY+=$'\n'"---"$'\n\n'

# Update history README
if [ -f "$HISTORY_README" ]; then
    python3 -c "
content = open('$HISTORY_README').read()
entry = '''$ENTRY'''
if '## 📥 Download History' in content:
    parts = content.split('## 📥 Download History', 1)
    new_content = parts[0] + '## 📥 Download History\n\n' + entry + parts[1]
else:
    new_content = content + '\n' + entry
open('$HISTORY_README', 'w').write(new_content)
"
else
    cat > "$HISTORY_README" << ENDMARKER
# 📥 Torrent Download History

All times in **Tehran timezone (IR)**.

## 📥 Download History

${ENTRY}
ENDMARKER
fi

echo "History updated!"
