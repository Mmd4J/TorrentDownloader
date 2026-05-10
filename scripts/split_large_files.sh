#!/bin/bash

# Split large files (>95MB) into smaller parts using 7zip
# for GitHub repository storage

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
MAX_SIZE_MB=95
MAX_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
SPLIT_SIZE="95M"
TARGET_DIR="${1:-downloads}"
SPLIT_DIR="${TARGET_DIR}/.split_files"
MANIFEST_DIR="${TARGET_DIR}/.manifests"

# Check if 7zip is installed
if ! command -v 7z &> /dev/null; then
    echo -e "${RED}Error: 7zip (p7zip-full) is not installed${NC}"
    echo "Install with: sudo apt-get install p7zip-full"
    exit 1
fi

# Create directories
mkdir -p "$SPLIT_DIR"
mkdir -p "$MANIFEST_DIR"

echo -e "${BLUE}=== Large File Splitter ===${NC}"
echo -e "Max file size: ${YELLOW}${MAX_SIZE_MB}MB${NC}"
echo -e "Target directory: ${YELLOW}${TARGET_DIR}${NC}"
echo -e "Split storage: ${YELLOW}${SPLIT_DIR}${NC}"
echo "=================================="

# Counter for statistics
TOTAL_FILES=0
SPLIT_FILES=0
SKIPPED_FILES=0

# Function to split a single file
split_file() {
    local file="$1"
    local filename=$(basename "$file")
    local filename_noext="${filename%.*}"
    local extension="${filename##*.}"
    local filesize=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    local filesize_mb=$((filesize / 1024 / 1024))
    
    # Skip if file is smaller than max size
    if [ "$filesize" -le "$MAX_SIZE_BYTES" ]; then
        echo -e "  ${GREEN}✓${NC} $filename (${filesize_mb}MB) - No split needed"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        return 0
    fi
    
    echo -e "  ${YELLOW}⚠${NC} $filename (${filesize_mb}MB) - Splitting..."
    
    # Create a unique directory for this file's parts
    local file_split_dir="${SPLIT_DIR}/${filename_noext}_parts"
    mkdir -p "$file_split_dir"
    
    # Create manifest file with original file info
    local manifest_file="${MANIFEST_DIR}/${filename_noext}.manifest.json"
    
    # Calculate original file hash
    local original_hash=$(sha256sum "$file" | cut -d' ' -f1)
    
    # Split the file using 7zip
    # -v${SPLIT_SIZE}: Split into volumes of SPLIT_SIZE
    # -mx0: No compression (faster for already compressed files)
    # -mmt=on: Multithreading
    cd "$file_split_dir"
    
    7z a -v${SPLIT_SIZE} -mx0 -mmt=on -t7z "${filename}.7z" "$file"
    
    # Count number of parts created
    local part_count=$(ls -1 "${filename}.7z".* 2>/dev/null | wc -l)
    
    cd - > /dev/null
    
    # Create manifest JSON
    cat > "$manifest_file" << EOF
{
    "original_name": "$filename",
    "original_path": "${file#$TARGET_DIR/}",
    "original_size": $filesize,
    "original_size_mb": $filesize_mb,
    "original_hash": "$original_hash",
    "split_date": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
    "part_count": $part_count,
    "part_size_mb": $MAX_SIZE_MB,
    "compression": "7z",
    "compression_level": 0,
    "parts": [
EOF
    
    # Add parts to manifest
    local i=1
    for part in "$file_split_dir/${filename}.7z".*; do
        local part_name=$(basename "$part")
        local part_size=$(stat -c%s "$part" 2>/dev/null || stat -f%z "$part" 2>/dev/null)
        local part_hash=$(sha256sum "$part" | cut -d' ' -f1)
        
        if [ $i -lt $part_count ]; then
            echo "        {\"part\": $i, \"name\": \"$part_name\", \"size\": $part_size, \"hash\": \"$part_hash\"}," >> "$manifest_file"
        else
            echo "        {\"part\": $i, \"name\": \"$part_name\", \"size\": $part_size, \"hash\": \"$part_hash\"}" >> "$manifest_file"
        fi
        
        i=$((i + 1))
    done
    
    cat >> "$manifest_file" << EOF
    ],
    "reassembly_command": "7z x ${filename}.7z.001 && mv ${filename}.7z ${filename} && 7z x ${filename}",
    "verification_command": "cat ${filename}.7z.* > ${filename}.7z && 7z t ${filename}.7z"
}
EOF
    
    # Remove original large file after successful split
    rm -f "$file"
    
    echo -e "    ${GREEN}✓${NC} Split into ${part_count} parts"
    echo -e "    ${BLUE}Manifest:${NC} $manifest_file"
    echo -e "    ${BLUE}Parts in:${NC} $file_split_dir"
    
    SPLIT_FILES=$((SPLIT_FILES + 1))
}

# Find and process all files in target directory
echo -e "\n${BLUE}Scanning for large files...${NC}"
echo ""

while IFS= read -r -d '' file; do
    # Skip .gitkeep, .split_files directory, and .manifests directory
    if [[ "$file" == *".gitkeep"* ]] || \
       [[ "$file" == *".split_files"* ]] || \
       [[ "$file" == *".manifests"* ]]; then
        continue
    fi
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    split_file "$file"
    
done < <(find "$TARGET_DIR" -type f -not -path "*/.split_files/*" -not -path "*/.manifests/*" -print0)

# Print summary
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Total files processed: ${YELLOW}$TOTAL_FILES${NC}"
echo -e "Files split: ${YELLOW}$SPLIT_FILES${NC}"
echo -e "Files skipped (under ${MAX_SIZE_MB}MB): ${GREEN}$SKIPPED_FILES${NC}"

if [ $SPLIT_FILES -gt 0 ]; then
    echo -e "\n${YELLOW}⚠ Important: Run 'scripts/merge_files.sh' to reassemble split files locally${NC}"
fi

echo -e "\n${GREEN}Done!${NC}"
