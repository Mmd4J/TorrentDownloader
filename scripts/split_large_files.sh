#!/bin/bash

DOWNLOAD_DIR="$1"
SPLIT_SIZE_MB="${2:-95}"

# Convert MB to bytes (using 1MB = 1,048,576 bytes)
SPLIT_SIZE=$((SPLIT_SIZE_MB * 1048576))

echo "Checking for files larger than ${SPLIT_SIZE_MB}MB in ${DOWNLOAD_DIR}..."

find "$DOWNLOAD_DIR" -type f ! -name "*.torrent" ! -name "*.7z.*" -print0 | while IFS= read -r -d '' file; do
    FILE_SIZE=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    
    if [ "$FILE_SIZE" -gt "$SPLIT_SIZE" ]; then
        echo "Splitting: $(basename "$file") ($(numfmt --to=iec $FILE_SIZE))"
        
        # Create split archive directory
        SPLIT_DIR="${file}.parts"
        mkdir -p "$SPLIT_DIR"
        
        # Use 7zip to split the file
        7z a -v${SPLIT_SIZE_MB}m -mx0 "${SPLIT_DIR}/$(basename "$file").7z" "$file"
        
        # Remove original file after successful split
        if [ $? -eq 0 ]; then
            echo "Split successful, removing original file"
            rm "$file"
        else
            echo "Error splitting file, keeping original"
        fi
    fi
done

echo "File splitting complete!"
