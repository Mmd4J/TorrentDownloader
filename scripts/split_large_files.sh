#!/bin/bash

# Split large files (>95MB) into smaller parts using 7zip
# for GitHub repository storage

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

MAX_SIZE_MB=${MAX_SIZE_MB:-95}
MAX_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
SPLIT_SIZE="${MAX_SIZE_MB}M"
TARGET_DIR="${1:-downloads}"

# Get absolute paths
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd)"
SPLIT_DIR="${TARGET_DIR}/.split_files"
MANIFEST_DIR="${TARGET_DIR}/.manifests"

# Check requirements
if ! command -v 7z &> /dev/null; then
    echo -e "${RED}Error: 7zip (p7zip-full) is not installed${NC}"
    echo "Install with: sudo apt-get install p7zip-full"
    exit 1
fi

# Create directories
mkdir -p "$SPLIT_DIR" "$MANIFEST_DIR"

echo -e "${BLUE}=== Large File Splitter ===${NC}"
echo -e "Max file size: ${YELLOW}${MAX_SIZE_MB}MB${NC}"
echo -e "Target directory: ${YELLOW}${TARGET_DIR}${NC}"
echo -e "Split storage: ${YELLOW}${SPLIT_DIR}${NC}"
echo "=================================="

SPLIT_FILES=0
SKIPPED_FILES=0

# Process each file
find "$TARGET_DIR" -type f -not -path "*/.split_files/*" -not -path "*/.manifests/*" -not -name ".gitkeep" -print0 | while IFS= read -r -d '' file; do
    
    filename=$(basename "$file")
    filedir=$(dirname "$file")
    
    # Get file size
    filesize=$(stat -c%s "$file" 2>/dev/null || stat -f%z "$file" 2>/dev/null)
    
    if [ -z "$filesize" ] || [ "$filesize" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠${NC} Could not get size for: $filename"
        continue
    fi
    
    filesize_mb=$((filesize / 1024 / 1024))
    
    # Skip if file is smaller than max size
    if [ "$filesize" -le "$MAX_SIZE_BYTES" ]; then
        echo -e "  ${GREEN}✓${NC} $filename (${filesize_mb}MB) - No split needed"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        continue
    fi
    
    echo -e "  ${YELLOW}⚠${NC} $filename (${filesize_mb}MB) - Splitting..."
    
    # Create a sanitized directory name
    safe_name=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g')
    file_split_dir="${SPLIT_DIR}/${safe_name}_parts"
    
    # Remove existing split directory if it exists (to avoid update errors)
    if [ -d "$file_split_dir" ]; then
        echo -e "    Cleaning up previous split attempt..."
        rm -rf "$file_split_dir"
    fi
    
    mkdir -p "$file_split_dir"
    
    # Create manifest file
    manifest_file="${MANIFEST_DIR}/${safe_name}.manifest.json"
    
    # Calculate original file hash
    original_hash=$(sha256sum "$file" | cut -d' ' -f1)
    
    # Save current directory
    original_dir="$PWD"
    
    # Change to the file's directory
    cd "$filedir"
    
    echo -e "    Working directory: ${BLUE}$PWD${NC}"
    echo -e "    Splitting: ${BLUE}$filename${NC}"
    echo -e "    Output to: ${BLUE}${file_split_dir}${NC}"
    
    # Create fresh 7z archive with volumes
    # -mx0: No compression (faster for already compressed files)
    # -v: Split into volumes
    archive_name="${filename}.7z"
    archive_path="${file_split_dir}/${archive_name}"
    
    # Use a temporary working directory to avoid conflicts
    WORK_DIR=$(mktemp -d)
    
    # Copy file to temp directory to avoid any locking issues
    cp "$filename" "$WORK_DIR/"
    
    cd "$WORK_DIR"
    
    # Create the split archive from temp directory
    7z a -v${SPLIT_SIZE} -mx0 -mmt=on "$archive_path" "$filename" || {
        echo -e "    ${RED}✗ Failed to create archive${NC}"
        cd "$original_dir"
        rm -rf "$WORK_DIR"
        continue
    }
    
    # Go back
    cd "$original_dir"
    
    # Clean up temp directory
    rm -rf "$WORK_DIR"
    
    # Count parts created
    part_count=$(ls -1 "${file_split_dir}/${archive_name}".* 2>/dev/null | wc -l)
    
    if [ "$part_count" -eq 0 ]; then
        echo -e "    ${RED}✗ No parts were created${NC}"
        continue
    fi
    
    echo -e "    Created ${part_count} parts"
    
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
    "archive_name": "$archive_name",
    "parts": [
EOF
    
    # Add parts to manifest
    local i=1
    for part in "${file_split_dir}/${archive_name}".*; do
        part_name=$(basename "$part")
        part_size=$(stat -c%s "$part" 2>/dev/null || stat -f%z "$part" 2>/dev/null)
        part_hash=$(sha256sum "$part" | cut -d' ' -f1)
        
        if [ $i -lt $part_count ]; then
            echo "        {\"part\": $i, \"name\": \"$part_name\", \"size\": $part_size, \"hash\": \"$part_hash\"}," >> "$manifest_file"
        else
            echo "        {\"part\": $i, \"name\": \"$part_name\", \"size\": $part_size, \"hash\": \"$part_hash\"}" >> "$manifest_file"
        fi
        
        i=$((i + 1))
    done
    
    cat >> "$manifest_file" << EOF
    ],
    "reassembly_instructions": "Place all parts in the same directory and run: 7z x ${archive_name}.001",
    "verification": "7z t ${archive_name}.001"
}
EOF
    
    # Verify split was successful
    if [ -f "${file_split_dir}/${archive_name}.001" ] && [ -s "$manifest_file" ]; then
        # Remove original large file after successful split
        rm -f "$file"
        echo -e "    ${GREEN}✓ Successfully split into ${part_count} parts${NC}"
        echo -e "    ${BLUE}Manifest:${NC} $manifest_file"
        echo -e "    ${BLUE}Parts:${NC} $file_split_dir"
        SPLIT_FILES=$((SPLIT_FILES + 1))
    else
        echo -e "    ${RED}✗ Split verification failed${NC}"
    fi
    
done

echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Files split: ${YELLOW}$SPLIT_FILES${NC}"
echo -e "Files skipped: ${GREEN}$SKIPPED_FILES${NC}"

if [ $SPLIT_FILES -gt 0 ]; then
    echo -e "\n${YELLOW}⚠ Important:${NC}"
    echo -e "  Split files: ${BLUE}${SPLIT_DIR}${NC}"
    echo -e "  Manifests: ${BLUE}${MANIFEST_DIR}${NC}"
    echo -e "  Run ${GREEN}scripts/merge_files.sh${NC} to reassemble locally"
fi

echo -e "\n${GREEN}Done!${NC}"
