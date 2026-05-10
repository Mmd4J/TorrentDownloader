#!/bin/bash

# Generate download summary
# Usage: ./generate-summary.sh <download_path> <duration> <torrent_url>

DOWNLOAD_PATH="${1:-downloads}"
DURATION="${2:-0}"
TORRENT_URL="${3:-Unknown}"

FILE_COUNT=$(find "$DOWNLOAD_PATH" -type f -not -name '.gitkeep' -not -name '*.aria2' -not -path "*/.split_files/*" -not -path "*/.manifests/*" | wc -l)
TOTAL_SIZE=$(du -sh "$DOWNLOAD_PATH" --exclude=.split_files --exclude=.manifests 2>/dev/null | cut -f1)
SPLIT_COUNT=$(find "$DOWNLOAD_PATH/.split_files" -type d -name "*_parts" 2>/dev/null | wc -l)

# Convert duration to readable format
HOURS=$((DURATION / 3600))
MINUTES=$(((DURATION % 3600) / 60))
SECONDS=$((DURATION % 60))

if [ $HOURS -gt 0 ]; then
    DURATION_TEXT="${HOURS}h ${MINUTES}m ${SECONDS}s"
elif [ $MINUTES -gt 0 ]; then
    DURATION_TEXT="${MINUTES}m ${SECONDS}s"
else
    DURATION_TEXT="${SECONDS}s"
fi

cat << EOF

========================================
📊 Download Summary
========================================
Date:        $(date)
Duration:    $DURATION_TEXT
Files:       $FILE_COUNT
Total Size:  $TOTAL_SIZE
Split Files: $SPLIT_COUNT
Torrent:     ${TORRENT_URL:0:100}...

Files downloaded:
EOF

find "$DOWNLOAD_PATH" -type f -not -name '.gitkeep' -not -name '*.aria2' -not -path "*/.split_files/*" -not -path "*/.manifests/*" -exec ls -lh {} \; | awk '{print "  " $5 "\t" $9}'

echo ""
echo "Download history updated: download_history.md"
echo "========================================"
