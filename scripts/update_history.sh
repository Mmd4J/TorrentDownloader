#!/bin/bash

TIMESTAMP="$1"
TORRENT_URL="$2"
REPO="$3"
BRANCH="${4:-main}"

HISTORY_DIR="history"
MANIFEST_FILE="${HISTORY_DIR}/${TIMESTAMP}/manifest.json"
HISTORY_README="${HISTORY_DIR}/README.md"

# Check if manifest exists
if [ ! -f "$MANIFEST_FILE" ]; then
    echo "Error: Manifest file not found at $MANIFEST_FILE"
    exit 1
fi

# Get Tehran time
TEHRAN_TIME=$(TZ='Asia/Tehran' date -d "${TIMESTAMP:0:8} ${TIMESTAMP:9:2}:${TIMESTAMP:11:2}:${TIMESTAMP:13:2}" +'%Y-%m-%d %H:%M' 2>/dev/null || TZ='Asia/Tehran' date +'%Y-%m-%d %H:%M')

# Read download directory from manifest
DOWNLOAD_DIR=$(jq -r '.download_dir' "$MANIFEST_FILE")

# Generate markdown entry using a temporary file
TEMP_ENTRY=$(mktemp)

# Write entry header
cat >> "$TEMP_ENTRY" << EOF
### 📅 ${TEHRAN_TIME} (Tehran)

**Torrent/Magnet:** 
\`\`\`
${TORRENT_URL}
\`\`\`

**Files:**
EOF

# Group split files
declare -A SPLIT_GROUPS
declare -a NORMAL_FILES

while IFS= read -r file_json; do
    FILE_PATH=$(echo "$file_json" | jq -r '.path')
    
    if [[ "$FILE_PATH" =~ \.7z\.([0-9]{3})$ ]]; then
        BASE_NAME="${FILE_PATH%.7z.*}"
        if [ -z "${SPLIT_GROUPS[$BASE_NAME]}" ]; then
            SPLIT_GROUPS["$BASE_NAME"]="$FILE_PATH"
        else
            SPLIT_GROUPS["$BASE_NAME"]="${SPLIT_GROUPS[$BASE_NAME]}|$FILE_PATH"
        fi
    else
        NORMAL_FILES+=("$file_json")
    fi
done < <(jq -c '.files[]' "$MANIFEST_FILE")

# Process normal files - embed links in filenames only
for file_json in "${NORMAL_FILES[@]}"; do
    FILE_PATH=$(echo "$file_json" | jq -r '.path')
    FILE_SIZE=$(echo "$file_json" | jq -r '.size_human')
    
    # URL encode the file path properly (handles spaces and special chars)
    ENCODED_PATH=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$FILE_PATH")
    DOWNLOAD_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${DOWNLOAD_DIR}/${ENCODED_PATH}"
    
    case "$FILE_PATH" in
        *.zip) ICON="🗜️" ;;
        *.rar) ICON="📚" ;;
        *.7z)  ICON="📦" ;;
        *.mkv|*.mp4|*.avi|*.mov) ICON="🎬" ;;
        *.mp3|*.flac|*.ogg|*.m4a) ICON="🎵" ;;
        *.jpg|*.jpeg|*.png|*.gif|*.webp) ICON="🖼️" ;;
        *.pdf) ICON="📕" ;;
        *)     ICON="📄" ;;
    esac
    
    # Only filename column with embedded link
    echo "- ${ICON} [**${FILE_PATH}**](${DOWNLOAD_URL}) - ${FILE_SIZE}" >> "$TEMP_ENTRY"
done

# Process split files
for BASE_NAME in "${!SPLIT_GROUPS[@]}"; do
    IFS='|' read -ra PARTS <<< "${SPLIT_GROUPS[$BASE_NAME]}"
    
    # Sort parts
    IFS=$'\n' PARTS=($(sort <<<"${PARTS[*]}"))
    unset IFS
    
    # Calculate total size
    TOTAL_SIZE=0
    for PART_PATH in "${PARTS[@]}"; do
        PART_SIZE=$(jq -r ".files[] | select(.path == \"$PART_PATH\") | .size" "$MANIFEST_FILE")
        TOTAL_SIZE=$((TOTAL_SIZE + PART_SIZE))
    done
    TOTAL_SIZE_HUMAN=$(numfmt --to=iec $TOTAL_SIZE 2>/dev/null || echo "${TOTAL_SIZE} bytes")
    
    echo "" >> "$TEMP_ENTRY"
    echo "- 📦 **${BASE_NAME}.7z** (Split Archive - ${TOTAL_SIZE_HUMAN} total)" >> "$TEMP_ENTRY"
    
    # Add each part with embedded link
    PART_NUM=1
    TOTAL_PARTS=${#PARTS[@]}
    for PART_PATH in "${PARTS[@]}"; do
        PART_SIZE=$(jq -r ".files[] | select(.path == \"$PART_PATH\") | .size_human" "$MANIFEST_FILE")
        ENCODED_PATH=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$PART_PATH")
        DOWNLOAD_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${DOWNLOAD_DIR}/${ENCODED_PATH}"
        
        if [ $PART_NUM -eq $TOTAL_PARTS ]; then
            PREFIX="  └─"
        else
            PREFIX="  ├─"
        fi
        
        echo "${PREFIX} 📎 [**${PART_PATH}**](${DOWNLOAD_URL}) - ${PART_SIZE}" >> "$TEMP_ENTRY"
        PART_NUM=$((PART_NUM + 1))
    done
    
    # Add reassembly tip
    FIRST_PART="${PARTS[0]}"
    ENCODED_FIRST=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$FIRST_PART")
    FIRST_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${DOWNLOAD_DIR}/${ENCODED_FIRST}"
    echo "  💡 *Download all parts, then:* \`7z x ${FIRST_PART}\`" >> "$TEMP_ENTRY"
done

echo "" >> "$TEMP_ENTRY"
echo "---" >> "$TEMP_ENTRY"
echo "" >> "$TEMP_ENTRY"

# Read the generated entry
ENTRY=$(cat "$TEMP_ENTRY")
rm "$TEMP_ENTRY"

# Update or create history README
if [ -f "$HISTORY_README" ]; then
    echo "Updating existing history README..."
    
    awk -v entry="$ENTRY" '
        /^## 📥 Download History/ {
            print $0
            print ""
            print entry
            next
        }
        { print }
    ' "$HISTORY_README" > "${HISTORY_README}.tmp"
    
    mv "${HISTORY_README}.tmp" "$HISTORY_README"
else
    echo "Creating new history README..."
    cat > "$HISTORY_README" << EOF
# 📥 Torrent Download History

Download history automatically updated by GitHub Actions using aria2.
**All times are in Tehran timezone (IR).**

## 📊 Quick Stats
- **Download Engine:** aria2
- **Split Size:** Files >95MB auto-split with 7zip
- **Storage:** All files in \`downloads/\` directory
- **Click on any filename** to download directly

## 📥 Download History

${ENTRY}
## 🔧 How to Use
1. **Click on any filename** above to download it directly
2. For split files (\`.7z.001\`, \`.7z.002\`, etc.), download ALL parts
3. Install 7zip: \`sudo apt-get install p7zip-full\` (Linux) or \`brew install p7zip\` (macOS)
4. Extract: \`7z x filename.7z.001\`

---

*Last updated: $(TZ='Asia/Tehran' date +'%Y-%m-%d %H:%M IR')*
EOF
fi

echo "History updated successfully!"
