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
SESSION_ID="$(date +%Y%m%d_%H%M%S)_$(echo $RANDOM | md5sum | head -c 6)"

# Create history directories
mkdir -p "$HISTORY_DIR"
mkdir -p "$HISTORY_DIR/files"

# Create session directory for this download
SESSION_DIR="$HISTORY_DIR/files/$SESSION_ID"
mkdir -p "$SESSION_DIR"

# Get torrent info
echo "Getting torrent info..."
./scripts/torrent-info.sh "$TORRENT_URL" --json > "$SESSION_DIR/torrent_info.json"

# Generate file links
echo "Generating download links..."
RAW_BASE_URL="https://raw.githubusercontent.com/$REPO/$BRANCH"

# Create metadata file for this session
cat > "$SESSION_DIR/metadata.json" << EOF
{
    "session_id": "$SESSION_ID",
    "timestamp": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "torrent_url": "$TORRENT_URL",
    "download_path": "$DOWNLOAD_PATH",
    "files": []
}
EOF

# Process downloaded files
FIRST=true
find "$DOWNLOAD_PATH" -type f -not -name '.gitkeep' -not -name '*.aria2' -not -path "*/.split_files/*" -not -path "*/.manifests/*" -print0 | while IFS= read -r -d '' file; do
    
    filename=$(basename "$file")
    filepath="${file#./}"
    
    # Get file size
    filesize=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    human_size=$(numfmt --to=iec $filesize 2>/dev/null || echo "${filesize} bytes")
    
    # Get file hash
    filehash=$(sha256sum "$file" | cut -d' ' -f1)
    
    # Create raw download link
    ENCODED_PATH=$(echo "$filepath" | sed 's/ /%20/g' | sed 's/\[/%5B/g' | sed 's/\]/%5D/g')
    DOWNLOAD_URL="${RAW_BASE_URL}/${ENCODED_PATH}"
    
    # Check if file was split
    SAFE_NAME=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g')
    if [ -d "$DOWNLOAD_PATH/.split_files/${SAFE_NAME}_parts" ]; then
        FILE_STATUS="⚠️ Split"
        PART_COUNT=$(ls -1 "$DOWNLOAD_PATH/.split_files/${SAFE_NAME}_parts" 2>/dev/null | wc -l)
    else
        FILE_STATUS="✅ Complete"
        PART_COUNT="1"
    fi
    
    # Get file extension for icon
    EXT="${filename##*.}"
    case "$EXT" in
        mkv|mp4|avi|mov) ICON="🎬" ;;
        mp3|flac|wav|aac) ICON="🎵" ;;
        srt|sub|ass)     ICON="📝" ;;
        iso|img|dmg)     ICON="💿" ;;
        zip|rar|7z|tar)  ICON="📦" ;;
        exe|app|bin)     ICON="⚙️" ;;
        *)               ICON="📄" ;;
    esac
    
    echo "  $ICON $filename - $human_size - $FILE_STATUS"
    
    # Update metadata JSON
    TMP_FILE=$(mktemp)
    jq --arg name "$filename" \
       --arg path "$filepath" \
       --arg url "$DOWNLOAD_URL" \
       --arg size "$human_size" \
       --arg hash "$filehash" \
       --arg icon "$ICON" \
       --arg status "$FILE_STATUS" \
       --arg parts "$PART_COUNT" \
       '.files += [{"name": $name, "path": $path, "url": $url, "size": $size, "hash": $hash, "icon": $icon, "status": $status, "parts": $parts}]' \
       "$SESSION_DIR/metadata.json" > "$TMP_FILE"
    mv "$TMP_FILE" "$SESSION_DIR/metadata.json"
    
done

# Generate per-session markdown file
cat > "$SESSION_DIR/session.md" << EOF
# 📥 Download Session: $SESSION_ID

**Date:** $(date)
**Torrent:** \`${TORRENT_URL:0:100}...\`

## Files

| # | Icon | File | Size | Status | Download |
|---|------|------|------|--------|----------|
EOF

# Add file rows
find "$DOWNLOAD_PATH" -type f -not -name '.gitkeep' -not -name '*.aria2' -not -path "*/.split_files/*" -not -path "*/.manifests/*" -print0 | while IFS= read -r -d '' file; do
    
    filename=$(basename "$file")
    filepath="${file#./}"
    filesize=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    human_size=$(numfmt --to=iec $filesize 2>/dev/null || echo "${filesize} bytes")
    ENCODED_PATH=$(echo "$filepath" | sed 's/ /%20/g' | sed 's/\[/%5B/g' | sed 's/\]/%5D/g')
    DOWNLOAD_URL="${RAW_BASE_URL}/${ENCODED_PATH}"
    
    EXT="${filename##*.}"
    case "$EXT" in
        mkv|mp4|avi|mov) ICON="🎬" ;;
        mp3|flac|wav|aac) ICON="🎵" ;;
        srt|sub|ass)     ICON="📝" ;;
        iso|img|dmg)     ICON="💿" ;;
        zip|rar|7z|tar)  ICON="📦" ;;
        *)               ICON="📄" ;;
    esac
    
    SAFE_NAME=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g')
    if [ -d "$DOWNLOAD_PATH/.split_files/${SAFE_NAME}_parts" ]; then
        STATUS="⚠️ Split"
    else
        STATUS="✅"
    fi
    
    echo "| $((++i)) | $ICON | \`$filename\` | $human_size | $STATUS | [📥 Download]($DOWNLOAD_URL) |" >> "$SESSION_DIR/session.md"
    
done

echo "" >> "$SESSION_DIR/session.md"
echo "## Reassembly Instructions" >> "$SESSION_DIR/session.md"
echo "" >> "$SESSION_DIR/session.md"
echo "If files are marked as \"Split\", run the following to reassemble:" >> "$SESSION_DIR/session.md"
echo '```bash' >> "$SESSION_DIR/session.md"
echo "./scripts/merge_files.sh" >> "$SESSION_DIR/session.md"
echo '```' >> "$SESSION_DIR/session.md"

# Update main history file
if [ ! -f "$HISTORY_FILE" ]; then
    cat > "$HISTORY_FILE" << 'EOF'
# 📥 Download History

> **FOR EDUCATIONAL PURPOSES ONLY**

---

## Download Sessions

EOF
fi

# Add new session to history (at the top, after the header)
TEMP_HISTORY=$(mktemp)
head -8 "$HISTORY_FILE" > "$TEMP_HISTORY"

# Generate session summary line
FILE_COUNT=$(find "$DOWNLOAD_PATH" -type f -not -name '.gitkeep' -not -name '*.aria2' -not -path "*/.split_files/*" -not -path "*/.manifests/*" | wc -l)
TOTAL_SIZE=$(du -sh "$DOWNLOAD_PATH" --exclude=.split_files --exclude=.manifests 2>/dev/null | cut -f1)

cat >> "$TEMP_HISTORY" << EOF
### 📅 $(date +%Y-%m-%d) - Session \`$SESSION_ID\`

- **Time:** $(date +"%H:%M:%S")
- **Files:** $FILE_COUNT
- **Total Size:** $TOTAL_SIZE
- **Torrent:** \`${TORRENT_URL:0:100}...\`
- **Details:** [View Session](./files/$SESSION_ID/session.md)
- **Direct Downloads:**

EOF

# Add direct download links
find "$DOWNLOAD_PATH" -type f -not -name '.gitkeep' -not -name '*.aria2' -not -path "*/.split_files/*" -not -path "*/.manifests/*" | while IFS= read -r file; do
    filename=$(basename "$file")
    filepath="${file#./}"
    ENCODED_PATH=$(echo "$filepath" | sed 's/ /%20/g' | sed 's/\[/%5B/g' | sed 's/\]/%5D/g')
    
    EXT="${filename##*.}"
    case "$EXT" in
        mkv|mp4|avi|mov) ICON="🎬" ;;
        mp3|flac|wav|aac) ICON="🎵" ;;
        srt|sub|ass)     ICON="📝" ;;
        iso|img|dmg)     ICON="💿" ;;
        zip|rar|7z|tar)  ICON="📦" ;;
        *)               ICON="📄" ;;
    esac
    
    echo "  - $ICON [\`$filename\`](${RAW_BASE_URL}/${ENCODED_PATH}) - [📥 Direct Download](${RAW_BASE_URL}/${ENCODED_PATH})" >> "$TEMP_HISTORY"
done

echo "" >> "$TEMP_HISTORY"
echo "---" >> "$TEMP_HISTORY"
echo "" >> "$TEMP_HISTORY"

# Append rest of original file
tail -n +9 "$HISTORY_FILE" >> "$TEMP_HISTORY" 2>/dev/null || true
mv "$TEMP_HISTORY" "$HISTORY_FILE"

echo ""
echo -e "${GREEN}✓ Download history updated${NC}"
echo -e "${BLUE}Session: $SESSION_ID${NC}"
echo -e "${BLUE}History file: $HISTORY_FILE${NC}"
