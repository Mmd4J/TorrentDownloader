#!/bin/bash

DOWNLOAD_DIR="$1"
TIMESTAMP="$2"
TORRENT_URL="$3"
REPORT_DIR="history/${TIMESTAMP}"

mkdir -p "$REPORT_DIR"

# Generate file manifest
echo "Generating file manifest..."
cat > "${REPORT_DIR}/manifest.json" << EOF
{
  "timestamp": "${TIMESTAMP}",
  "torrent": "${TORRENT_URL}",
  "download_date": "$(date -u +"%Y-%m-%d %H:%M:%S UTC")",
  "files": [
EOF

FIRST=true
find "$DOWNLOAD_DIR" -type f ! -name "*.torrent" -print0 | while IFS= read -r -d '' file; do
    REL_PATH="${file#$DOWNLOAD_DIR/}"
    FILE_SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    FILE_HASH=$(sha256sum "$file" | cut -d' ' -f1)
    
    if [ "$FIRST" = true ]; then
        FIRST=false
    else
        echo "," >> "${REPORT_DIR}/manifest.json"
    fi
    
    cat >> "${REPORT_DIR}/manifest.json" << EOF
    {
      "path": "${REL_PATH}",
      "size": ${FILE_SIZE},
      "size_human": "$(numfmt --to=iec $FILE_SIZE)",
      "sha256": "${FILE_HASH}"
    }
EOF
done

echo -e "\n  ]\n}" >> "${REPORT_DIR}/manifest.json"

echo "Report generated!"
