#!/bin/bash

DOWNLOAD_DIR="$1"
TIMESTAMP="$2"
TORRENT_URL="$3"
REPORT_DIR="history/${TIMESTAMP}"

mkdir -p "$REPORT_DIR"

# Copy download dir name for manifest
DOWNLOAD_DIR_NAME=$(basename "$DOWNLOAD_DIR")

# Generate file manifest with more metadata
cat > "${REPORT_DIR}/manifest.json" << EOF
{
  "timestamp": "${TIMESTAMP}",
  "torrent": "${TORRENT_URL}",
  "download_date": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")",
  "download_dir": "downloads/${DOWNLOAD_DIR_NAME}",
  "has_splits": false,
  "files": [
EOF

FIRST=true
HAS_SPLITS=false

# Find and process all files, sorting them properly
find "$DOWNLOAD_DIR" -type f ! -name "*.torrent" ! -name "*.aria2" -print0 | sort -z | while IFS= read -r -d '' file; do
    REL_PATH="${file#$DOWNLOAD_DIR/}"
    FILE_SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    FILE_HASH=$(sha256sum "$file" | cut -d' ' -f1)
    
    # Check if this is a split file
    if [[ "$REL_PATH" == *.7z.* ]]; then
        HAS_SPLITS=true
        SPLIT_PART="true"
    else
        SPLIT_PART="false"
    fi
    
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "${REPORT_DIR}/manifest.json"
    fi
    
    # Get file extension and base name
    EXTENSION="${REL_PATH##*.}"
    BASENAME="${REL_PATH%.*}"
    
    cat >> "${REPORT_DIR}/manifest.json" << EOF
    {
      "path": "${REL_PATH}",
      "basename": "${BASENAME}",
      "extension": "${EXTENSION}",
      "size": ${FILE_SIZE},
      "size_human": "$(numfmt --to=iec $FILE_SIZE 2>/dev/null || echo "${FILE_SIZE} bytes")",
      "sha256": "${FILE_HASH}",
      "is_split_part": ${SPLIT_PART}
    }
EOF
done

echo -e "\n  ]\n}" >> "${REPORT_DIR}/manifest.json"

# Update the has_splits flag
if [ "$HAS_SPLITS" = true ]; then
    # Use jq to update the JSON
    jq '.has_splits = true' "${REPORT_DIR}/manifest.json" > "${REPORT_DIR}/manifest.json.tmp"
    mv "${REPORT_DIR}/manifest.json.tmp" "${REPORT_DIR}/manifest.json"
fi

echo "Report generated at ${REPORT_DIR}/manifest.json"
