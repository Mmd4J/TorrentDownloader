#!/bin/bash

TIMESTAMP="$1"
TORRENT_URL="$2"
REPO="$3"
BRANCH="${4:-main}"

HISTORY_DIR="history"
MANIFEST_FILE="${HISTORY_DIR}/${TIMESTAMP}/manifest.json"
HISTORY_README="${HISTORY_DIR}/README.md"

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

# Escape special characters for markdown
escape_md() {
    echo "$1" | sed 's/`/\\`/g'
}

DATE_STR=$(format_timestamp "$TIMESTAMP")

# Read manifest
DOWNLOAD_DIR=$(jq -r '.download_dir' "$MANIFEST_FILE")

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

# Read files from manifest
jq -c '.files[]' "$MANIFEST_FILE" | while read -r file; do
    FILE_PATH=$(echo "$file" | jq -r '.path')
    FILE_SIZE=$(echo "$file" | jq -r '.size_human')
    
    # URL encode the file path
    ENCODED_PATH=$(python3 -c "import urllib.parse; print(urllib.parse.quote('${FILE_PATH}'))")
    
    # Create download URL
    DOWNLOAD_URL="https://raw.githubusercontent.com/${REPO}/${BRANCH}/${DOWNLOAD_DIR}/${ENCODED_PATH}"
    
    # Determine icon
    if [[ "$FILE_PATH" == *.7z.* ]]; then
        ICON="📦"
    else
        ICON="📄"
    fi
    
    ENTRY+="| ${ICON} \`${FILE_PATH}\` | ${FILE_SIZE} | [⬇️ Download](${DOWNLOAD_URL}) |\n"
done

# Check for split files
if jq -e '.files[] | select(.path | test("\\\\.7z\\\\."))' "$MANIFEST_FILE" > /dev/null 2>&1; then
    ENTRY+="
> 💡 **Split Files Detected!** To reassemble:
> \`\`\`bash
> # Install 7zip if needed
> sudo apt-get install p7zip-full  # Linux
> brew install p7zip                # macOS
> 
> # Download all .7z.001, .7z.002, etc. files, then:
> 7z x filename.7z.001
> \`\`\`
"
fi

ENTRY+="
---
"

# Update history README
if [ -f "$HISTORY_README" ]; then
    # Insert new entry after the Download History header
    sed -i "/^## 📥 Download History/a\\
\\
${ENTRY}" "$HISTORY_README"
else
    # Create new history README
    cat > "$HISTORY_README" << EOF
# 📥 Torrent Download History

Welcome to the download history! This page is automatically updated by GitHub Actions.

## 📊 Quick Stats
- Downloads are processed using **aria2**
- Large files (>95MB) are automatically split using **7zip**
- All files are stored in the \`downloads/\` directory

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

echo "History updated successfully!"
