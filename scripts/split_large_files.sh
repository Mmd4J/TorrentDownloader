#!/bin/bash
DOWNLOAD_DIR="$1"
SPLIT_SIZE_MB="${2:-95}"
SPLIT_SIZE=$((SPLIT_SIZE_MB * 1048576))

find "$DOWNLOAD_DIR" -type f ! -name "*.torrent" ! -name "*.aria2" ! -name "*.7z.*" -print0 | while IFS= read -r -d '' file; do
    FILE_SIZE=$(stat -c%s "$file" 2>/dev/null)
    if [ "$FILE_SIZE" -gt "$SPLIT_SIZE" ]; then
        echo "Splitting: $(basename "$file") ($(numfmt --to=iec $FILE_SIZE))"
        7z a -v${SPLIT_SIZE_MB}m -mx0 "${file}.7z" "$file"
        if [ $? -eq 0 ]; then
            rm "$file"
        fi
    fi
done
echo "File splitting complete!"
