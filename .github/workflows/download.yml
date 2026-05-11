#!/bin/bash

# Update download history with clickable links
# Usage: ./update-history.sh <torrent_url> <download_path> <repo> <branch>

set -e

GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

TORRENT_URL="$1"
DOWNLOAD_PATH="${2:-downloads}"
REPO="${3:-owner/repo}"
BRANCH="${4:-main}"
HISTORY_DIR="download_history"
HISTORY_FILE="download_history.md"
SESSION_ID="$(TZ='Asia/Tehran' date +%Y%m%d_%H%M%S)_$(echo $RANDOM | md5sum | head -c 6)"

# Create history directories
mkdir -p "$HISTORY_DIR"
mkdir -p "$HISTORY_DIR/files/$SESSION_ID"

# Generate raw base URL
RAW_BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"

# Get file count and total size
FILE_COUNT=$(find "$DOWNLOAD_PATH" -type f -not -name '.gitkeep' -not -name '*.aria2' -not -path "*/.split_files/*" -not -path "*/.manifests/*" | wc -l)
TOTAL_SIZE=$(du -sh "$DOWNLOAD_PATH" --exclude=.split_files --exclude=.manifests 2>/dev/null | cut -f1)

echo -e "${BLUE}Updating download history...${NC}"

# URL encode function
url_encode() {
    local string="$1"
    local encoded=""
    local pos
    local c
    local o
    
    for ((pos=0; pos<${#string}; pos++)); do
        c="${string:$pos:1}"
        case "$c" in
            [-_.~a-zA-Z0-9/]) encoded+="$c" ;;
            *) printf -v o '%%%02x' "'$c"
               encoded+="$o" ;;
        esac
    done
    echo "$encoded"
}

# Create session markdown
cat > "$HISTORY_DIR/files/$SESSION_ID/session.md" << EOF
# 📥 Download Session: $SESSION_ID

**Date:** $(TZ='Asia/Tehran' date '+%Y-%m-%d %H:%M:%S %Z')
**Torrent:** \`${TORRENT_URL:0:100}...\`

## Files

| # | Icon | File | Size |
|---|------|------|------|
EOF

# Add file rows
i=0
find "$DOWNLOAD_PATH" -type f -not -name '.gitkeep' -not -name '*.aria2' -not -path "*/.split_files/*" -not -path "*/.manifests/*" | sort | while IFS= read -r file; do
    
    i=$((i + 1))
    filename=$(basename "$file")
    filepath="${file#./}"
    filesize=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    human_size=$(numfmt --to=iec $filesize 2>/dev/null || echo "${filesize} bytes")
    
    # URL encode the full path including spaces
    ENCODED_PATH=$(url_encode "$filepath")
    DOWNLOAD_URL="${RAW_BASE_URL}/${ENCODED_PATH}"
    
    # Get icon based on extension
    EXT="${filename##*.}"
    case "${EXT,,}" in
        mkv|mp4|avi|mov|webm)   ICON="🎬" ;;
        mp3|flac|wav|aac|ogg)   ICON="🎵" ;;
        srt|sub|ass)            ICON="📝" ;;
        iso|img|dmg)            ICON="💿" ;;
        zip|rar|7z|tar|gz)      ICON="📦" ;;
        exe|app|bin|sh)         ICON="⚙️" ;;
        pdf|epub|mobi)          ICON="📚" ;;
        jpg|png|gif|webp)       ICON="🖼️" ;;
        *)                      ICON="📄" ;;
    esac
    
    echo "| $i | $ICON | [\`$filename\`]($DOWNLOAD_URL) | $human_size |" >> "$HISTORY_DIR/files/$SESSION_ID/session.md"
done

echo "" >> "$HISTORY_DIR/files/$SESSION_ID/session.md"
echo "## Reassembly Instructions" >> "$HISTORY_DIR/files/$SESSION_ID/session.md"
echo "" >> "$HISTORY_DIR/files/$SESSION_ID/session.md"
echo "If files were split, reassemble them with:" >> "$HISTORY_DIR/files/$SESSION_ID/session.md"
echo '```bash' >> "$HISTORY_DIR/files/$SESSION_ID/session.md"
echo "./scripts/merge_files.sh \"$DOWNLOAD_PATH/.split_files\" \"$DOWNLOAD_PATH\"" >> "$HISTORY_DIR/files/$SESSION_ID/session.md"
echo '```' >> "$HISTORY_DIR/files/$SESSION_ID/session.md"

# Initialize history file if it doesn't exist
if [ ! -f "$HISTORY_FILE" ]; then
    cat > "$HISTORY_FILE" << 'EOF'
# 📥 Download History

> **FOR EDUCATIONAL PURPOSES ONLY**

---

## Download Sessions

EOF
fi

# Add new session to main history file (after header)
TEMP_HISTORY=$(mktemp)
head -8 "$HISTORY_FILE" > "$TEMP_HISTORY"

cat >> "$TEMP_HISTORY" << EOF
### 📅 $(TZ='Asia/Tehran' date +%Y-%m-%d) - \`$SESSION_ID\`

| | |
|---|---|
| **Time** | $(TZ='Asia/Tehran' date +"%H:%M:%S %Z") |
| **Files** | $FILE_COUNT |
| **Total Size** | $TOTAL_SIZE |
| **Details** | [View Session](./files/$SESSION_ID/session.md) |

**Files:**
EOF

# Add direct download links (filename embedded with link)
find "$DOWNLOAD_PATH" -type f -not -name '.gitkeep' -not -name '*.aria2' -not -path "*/.split_files/*" -not -path "*/.manifests/*" | sort | while IFS= read -r file; do
    
    filename=$(basename "$file")
    filepath="${file#./}"
    ENCODED_PATH=$(url_encode "$filepath")
    
    EXT="${filename##*.}"
    case "${EXT,,}" in
        mkv|mp4|avi|mov|webm)   ICON="🎬" ;;
        mp3|flac|wav|aac|ogg)   ICON="🎵" ;;
        srt|sub|ass)            ICON="📝" ;;
        iso|img|dmg)            ICON="💿" ;;
        zip|rar|7z|tar|gz)      ICON="📦" ;;
        pdf|epub|mobi)          ICON="📚" ;;
        jpg|png|gif|webp)       ICON="🖼️" ;;
        *)                      ICON="📄" ;;
    esac
    
    echo "- $ICON [\`$filename\`](${RAW_BASE_URL}/${ENCODED_PATH})" >> "$TEMP_HISTORY"
done

echo "" >> "$TEMP_HISTORY"
echo "---" >> "$TEMP_HISTORY"
echo "" >> "$TEMP_HISTORY"

# Append old sessions
tail -n +9 "$HISTORY_FILE" >> "$TEMP_HISTORY" 2>/dev/null || true
mv "$TEMP_HISTORY" "$HISTORY_FILE"

echo -e "${GREEN}✓ Download history updated${NC}"
echo -e "  Session: ${BLUE}$SESSION_ID${NC}"
echo -e "  History: ${BLUE}$HISTORY_FILE${NC}"
