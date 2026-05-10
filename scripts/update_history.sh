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

echo "Debug: Download directory = $DOWNLOAD_DIR"
echo "Debug: Repo = $REPO"
echo "Debug: Branch = $BRANCH"

# Generate markdown entry
ENTRY="### 📅 ${DATE_STR}

**Torrent/Magnet:** 
\`\`\`
${TORRENT_URL}
\`\`\`

**Files:**

| File | Size | Download |
|------|------|----------|
"

# Group split files together
declare -A SPLIT_GROUPS
NORMAL_FILES=()

# First pass: identify split files and group them
while IFS= read -r file_json; do
    FILE_PATH=$(echo "$file_json" | jq -r '.path')
    
    if [[ "$FILE_PATH" =~ \.7z\.([0-9]{3})$ ]]; then
        # This is a split file part
        BASE_NAME="${FILE_PATH%.7z.*}"
        SPLIT_GROUPS["$BASE_NAME"]+="$FILE_PATH"$'\n'
    elif [[ "$FILE_PATH" == *.7z.* ]]; then
        # Might be other split format
        BASE_NAME="${FILE_PATH%.7z.*}"
        SPLIT_GROUPS["$BASE_NAME"]+="$FILE_PATH"$'\n'
    else
        NORMAL_FILES+=("$file_json")
    fi
done < <(jq -c '.files[]' "$MANIFEST_FILE")

# Process normal files first
for file_json in "${NORMAL_FILES[@]}"; do
    FILE_PATH=$(echo "$file_json" | jq -r '.path')
    FILE_SIZE=$(echo "$file_json" | jq -r '.size_human')
    
    # URL encode the file path properly
    ENCODED_PATH=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$FILE_PATH")
    
    # Create the full download URL
    DOWNLOAD_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${DOWNLOAD_DIR}/${ENCODED_PATH}"
    
    # Determine icon based on file type
    if [[ "$FILE_PATH" == *.zip ]]; then
        ICON="🗜️"
    elif [[ "$FILE_PATH" == *.rar ]]; then
        ICON="📚"
    elif [[ "$FILE_PATH" == *.7z ]]; then
        ICON="📦"
    else
        ICON="📄"
    fi
    
    # Embed link in filename
    LINKED_NAME="[${FILE_PATH}](${DOWNLOAD_URL})"
    
    ENTRY="${ENTRY}| ${ICON} ${LINKED_NAME} | ${FILE_SIZE} | [⬇️ Direct Download](${DOWNLOAD_URL}) |"$'\n'
done

# Process split files
for BASE_NAME in "${!SPLIT_GROUPS[@]}"; do
    # Get all parts for this split group
    IFS=$'\n' read -r -d '' -a PARTS <<< "${SPLIT_GROUPS[$BASE_NAME]}"
    
    # Sort parts numerically
    IFS=$'\n' PARTS=($(sort <<<"${PARTS[*]}"))
    unset IFS
    
    # Calculate total size
    TOTAL_SIZE=0
    for PART_PATH in "${PARTS[@]}"; do
        PART_JSON=$(jq -c ".files[] | select(.path == \"$PART_PATH\")" "$MANIFEST_FILE")
        PART_SIZE=$(echo "$PART_JSON" | jq -r '.size')
        TOTAL_SIZE=$((TOTAL_SIZE + PART_SIZE))
    done
    
    # Convert total size to human readable
    TOTAL_SIZE_HUMAN=$(numfmt --to=iec $TOTAL_SIZE 2>/dev/null || echo "${TOTAL_SIZE} bytes")
    
    # Add split file header
    ENTRY="${ENTRY}| **📦 ${BASE_NAME}.7z (Split Archive)** | *${TOTAL_SIZE_HUMAN} total* | **See parts below** |"$'\n'
    
    # Add each part with individual download link
    PART_NUM=1
    for PART_PATH in "${PARTS[@]}"; do
        PART_JSON=$(jq -c ".files[] | select(.path == \"$PART_PATH\")" "$MANIFEST_FILE")
        PART_SIZE=$(echo "$PART_JSON" | jq -r '.size_human')
        
        # URL encode the file path
        ENCODED_PATH=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$FILE_PATH")
        
        # Create download URL
        DOWNLOAD_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${DOWNLOAD_DIR}/${ENCODED_PATH}"
        
        # Embed link in filename
        LINKED_NAME="[${PART_PATH}](${DOWNLOAD_URL})"
        
        ENTRY="${ENTRY}| 　├─ 📎 Part ${PART_NUM}: ${LINKED_NAME} | ${PART_SIZE} | [⬇️ Download Part ${PART_NUM}](${DOWNLOAD_URL}) |"$'\n'
        
        PART_NUM=$((PART_NUM + 1))
    done
done

# Add reassembly instructions for split files
if [ ${#SPLIT_GROUPS[@]} -gt 0 ]; then
    ENTRY="${ENTRY}"$'\n'
    ENTRY="${ENTRY}**📦 Split Files Reassembly:**"$'\n'$'\n'
    
    for BASE_NAME in "${!SPLIT_GROUPS[@]}"; do
        # Get the first part filename
        FIRST_PART_FILE=$(echo "${SPLIT_GROUPS[$BASE_NAME]}" | head -n1)
        
        # URL encode for download link
        ENCODED_FIRST_PART=$(python3 -c "import urllib.parse, sys; print(urllib.parse.quote(sys.argv[1], safe=''))" "$FIRST_PART_FILE")
        FIRST_PART_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${DOWNLOAD_DIR}/${ENCODED_FIRST_PART}"
        
        ENTRY="${ENTRY}To extract \`${BASE_NAME}\`:"$'\n'
        ENTRY="${ENTRY}1. Download all parts above"$'\n'
        ENTRY="${ENTRY}2. Install 7zip: \`sudo apt-get install p7zip-full\` (Linux) or \`brew install p7zip\` (macOS)"$'\n'
        ENTRY="${ENTRY}3. [Download Part 001](${FIRST_PART_URL}) and all other parts to the same directory"$'\n'
        ENTRY="${ENTRY}4. Run: \`7z x ${FIRST_PART_FILE}\`"$'\n'$'\n'
    done
fi

ENTRY="${ENTRY}"$'\n'"---"$'\n'$'\n'

# Update or create history README
if [ -f "$HISTORY_README" ]; then
    echo "Updating existing history README..."
    TEMP_FILE=$(mktemp)
    
    UPDATED=false
    while IFS= read -r line; do
        echo "$line" >> "$TEMP_FILE"
        if [[ "$line" == "## 📥 Download History" ]] && [ "$UPDATED" = false ]; then
            echo "" >> "$TEMP_FILE"
            echo -n "$ENTRY" >> "$TEMP_FILE"
            UPDATED=true
        fi
    done < "$HISTORY_README"
    
    if [ "$UPDATED" = false ]; then
        echo "" >> "$TEMP_FILE"
        echo -n "$ENTRY" >> "$TEMP_FILE"
    fi
    
    mv "$TEMP_FILE" "$HISTORY_README"
else
    echo "Creating new history README..."
    cat > "$HISTORY_README" << EOF
# 📥 Torrent Download History

Welcome to the download history! This page is automatically updated by GitHub Actions.

## 📊 Quick Stats
- Downloads are processed using **aria2**
- Large files (>95MB) are automatically split using **7zip**
- All files are stored in the \`downloads/\` directory
- Click on any filename to download directly

## 📥 Download History

${ENTRY}
## 📁 File Structure
\`\`\`
downloads/
├── YYYYMMDD_HHMMSS_torrentname/
│   ├── file1.txt
│   ├── largefile.7z.001
│   ├── largefile.7z.002
│   └── manifest.json
\`\`\`

## 🔧 Reassembling Split Files
Split files use 7zip's volume format. Download all parts and extract:
\`\`\`bash
7z x filename.7z.001
\`\`\`

---

*Last updated: $(date -u +"%Y-%m-%d %H:%M:%S UTC")*
EOF
fi

# Update main README with link to history
if [ -f "README.md" ]; then
    if ! grep -q "View Download History" "README.md"; then
        echo "" >> "README.md"
        echo "[📜 View Download History](history/README.md)" >> "README.md"
    fi
fi

echo "History updated successfully!"
echo "Download links should be accessible at:"
echo "https://github.com/${REPO}/blob/${BRANCH}/history/README.md"
