#!/bin/bash
DOWNLOAD_DIR="$1"
TIMESTAMP="$2"
TORRENT_URL="$3"
REPORT_DIR="history/${TIMESTAMP}"
mkdir -p "$REPORT_DIR"

echo "{" > "${REPORT_DIR}/manifest.json"
echo "  \"timestamp\": \"${TIMESTAMP}\"," >> "${REPORT_DIR}/manifest.json"
echo "  \"torrent\": \"${TORRENT_URL}\"," >> "${REPORT_DIR}/manifest.json"
echo "  \"download_date\": \"$(date -u +"%Y-%m-%d %H:%M:%S UTC")\"," >> "${REPORT_DIR}/manifest.json"
echo "  \"download_dir\": \"downloads/$(basename "$DOWNLOAD_DIR")\"," >> "${REPORT_DIR}/manifest.json"
echo "  \"files\": [" >> "${REPORT_DIR}/manifest.json"

FIRST=true
find "$DOWNLOAD_DIR" -type f ! -name "*.torrent" ! -name "*.aria2" -print0 | sort -z | while IFS= read -r -d '' file; do
    REL_PATH="${file#$DOWNLOAD_DIR/}"
    FILE_SIZE=$(stat -c%s "$file" 2>/dev/null)
    FILE_HASH=$(sha256sum "$file" | cut -d' ' -f1)
    [ "$FIRST" = false ] && echo "," >> "${REPORT_DIR}/manifest.json"
    FIRST=false
    echo "    {\"path\": \"${REL_PATH}\", \"size\": ${FILE_SIZE}, \"size_human\": \"$(numfmt --to=iec $FILE_SIZE 2>/dev/null || echo "${FILE_SIZE} bytes")\", \"sha256\": \"${FILE_HASH}\"}" >> "${REPORT_DIR}/manifest.json"
done

echo "  ]" >> "${REPORT_DIR}/manifest.json"
echo "}" >> "${REPORT_DIR}/manifest.json"
echo "Report generated!"
