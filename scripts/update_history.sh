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

# Format timestamp
format_timestamp() {
    local ts="$1"
    local date_part="${ts%%_*}"
    local time_part="${ts##*_}"
    
    local year="${date_part:0:4}"
    local month="${date_part:4:2}"
    local day="${date_part:6:2}"
    local hour="${time_part:0:2}"
    local minute="${time_part:2:2}"
    local second="${time_part:4:2}"
    
    echo "${year}-${month}-${day} ${hour}:${minute}:${second} UTC"
}

DATE_STR=$(format_timestamp "$TIMESTAMP")

# Read download directory from manifest
DOWNLOAD_DIR=$(jq -r '.download_dir' "$MANIFEST_FILE")

# Generate markdown entry using a temporary file for clean formatting
TEMP_ENTRY=$(mktemp)

# Write entry header
cat >> "$TEMP_ENTRY" << EOF
### 📅 ${DATE_STR}

**Torrent/Magnet:** 
\`\`\`
${TORRENT_URL}
\`\`\`

**Files:**

| File | Size | Download |
|------|------|----------|
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

# Process normal files
for file_json in "${NORMAL_FILES[@]}"; do
    FILE_PATH=$(echo "$file_json" | jq -r '.path')
    FILE_SIZE=$(echo "$file_json" | jq -r '.size_human')
    ENCODED_PATH=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$FILE_PATH")
    DOWNLOAD_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${DOWNLOAD_DIR}/${ENCODED_PATH}"
    
    case "$FILE_PATH" in
        *.zip) ICON="🗜️" ;;
        *.rar) ICON="📚" ;;
        *.7z)  ICON="📦" ;;
        *)     ICON="📄" ;;
    esac
    
    echo "| ${ICON} [${FILE_PATH}](${DOWNLOAD_URL}) | ${FILE_SIZE} | [⬇️ Download](${DOWNLOAD_URL}) |" >> "$TEMP_ENTRY"
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
    
    # Add main split archive entry
    echo "| 📦 **${BASE_NAME}.7z** (Split Archive) | ${TOTAL_SIZE_HUMAN} total | *See parts below* |" >> "$TEMP_ENTRY"
    
    # Add each part
    PART_NUM=1
    for PART_PATH in "${PARTS[@]}"; do
        PART_SIZE=$(jq -r ".files[] | select(.path == \"$PART_PATH\") | .size_human" "$MANIFEST_FILE")
        ENCODED_PATH=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$PART_PATH")
        DOWNLOAD_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${DOWNLOAD_DIR}/${ENCODED_PATH}"
        
        if [ $PART_NUM -eq ${#PARTS[@]} ]; then
            PREFIX="└─"
        else
            PREFIX="├─"
        fi
        
        echo "|     ${PREFIX} [${PART_PATH}](${DOWNLOAD_URL}) | ${PART_SIZE} | [⬇️ Part ${PART_NUM}](${DOWNLOAD_URL}) |" >> "$TEMP_ENTRY"
        PART_NUM=$((PART_NUM + 1))
    done
done

# Add reassembly instructions if needed
if [ ${#SPLIT_GROUPS[@]} -gt 0 ]; then
    cat >> "$TEMP_ENTRY" << EOF

> 💡 **How to reassemble split files:**
> 1. Download all parts using the links above
> 2. Install 7zip: \`sudo apt-get install p7zip-full\` (Linux) or \`brew install p7zip\` (macOS)
> 3. Place all parts in the same folder
> 4. Extract: \`7z x filename.7z.001\`
EOF
fi

echo "" >> "$TEMP_ENTRY"
echo "---" >> "$TEMP_ENTRY"
echo "" >> "$TEMP_ENTRY"

# Read the generated entry
ENTRY=$(cat "$TEMP_ENTRY")
rm "$TEMP_ENTRY"

# Update or create history README
if [ -f "$HISTORY_README" ]; then
    echo "Updating existing history README..."
    
    # Use awk to insert new entry after the Download History header
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

## 📊 Quick Stats
- **Download Engine:** aria2
- **Split Size:** Files >95MB are split with 7zip
- **Storage:** All files in \`downloads/\` directory

## 📥 Download History

${ENTRY}
## 🔧 How to Use
1. Click on any filename to download it directly
2. For split files (`.7z.001`, `.7z.002`, etc.), download all parts
3. Install 7zip and extract: \`7z x filename.7z.001\`

---

*Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
fi

# Clean up and add link to main README
if [ -f "README.md" ]; then
    if ! grep -q "View Download History" "README.md"; then
        echo "" >> "README.md"
        echo "### 📜 [View Download History](history/README.md)" >> "README.md"
    fi
fi

echo "History updated successfully!"
