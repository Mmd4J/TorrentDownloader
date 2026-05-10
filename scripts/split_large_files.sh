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
MAX_SIZE_MB=${MAX_SIZE_MB:-95}
MAX_SIZE_BYTES=$((MAX_SIZE_MB * 1024 * 1024))
SPLIT_SIZE="${MAX_SIZE_MB}M"
TARGET_DIR="${1:-downloads}"

# Convert to absolute path
TARGET_DIR="$(cd "$TARGET_DIR" 2>/dev/null && pwd || echo "$PWD/$TARGET_DIR")"
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
    local filesize
    local filesize_mb
    
    # Get file size in a portable way
    if [[ "$OSTYPE" == "darwin"* ]]; then
        filesize=$(stat -f%z "$file" 2>/dev/null || echo 0)
    else
        filesize=$(stat -c%s "$file" 2>/dev/null || echo 0)
    fi
    
    if [ "$filesize" -eq 0 ]; then
        echo -e "  ${YELLOW}⚠${NC} $filename - Empty or inaccessible file, skipping"
        return 0
    fi
    
    filesize_mb=$((filesize / 1024 / 1024))
    
    # Skip if file is smaller than max size
    if [ "$filesize" -le "$MAX_SIZE_BYTES" ]; then
        echo -e "  ${GREEN}✓${NC} $filename (${filesize_mb}MB) - No split needed"
        SKIPPED_FILES=$((SKIPPED_FILES + 1))
        return 0
    fi
    
    echo -e "  ${YELLOW}⚠${NC} $filename (${filesize_mb}MB) - Splitting..."
    
    # Create a sanitized directory name (replace problematic characters)
    local safe_name=$(echo "$filename" | sed 's/[^a-zA-Z0-9._-]/_/g')
    local file_split_dir="${SPLIT_DIR}/${safe_name}_parts"
    mkdir -p "$file_split_dir"
    
    # Create manifest file with original file info
    local manifest_file="${MANIFEST_DIR}/${safe_name}.manifest.json"
    
    # Calculate original file hash
    local original_hash=$(sha256sum "$file" | cut -d' ' -f1)
    
    # Save current directory
    local original_dir="$PWD"
    
    # Change to the file's directory to avoid path issues with 7z
    cd "$(dirname "$file")"
    
    echo -e "    Working directory: ${BLUE}$PWD${NC}"
    echo -e "    Splitting file: ${BLUE}$filename${NC}"
    echo -e "    Output to: ${BLUE}${file_split_dir}${NC}"
    
    # Split the file using 7zip
    # -v${SPLIT_SIZE}: Split into volumes of SPLIT_SIZE
    # -mx0: No compression (faster for already compressed files)
    # -mmt=on: Multithreading
    # The archive name should be just the base name, as 7z will put it in the output dir
    local archive_name="${filename}.7z"
    local archive_path="${file_split_dir}/${archive_name}"
    
    # Create 7z archive with volumes in the split directory
    7z a -v${SPLIT_SIZE} -mx0 -mmt=on "${archive_path}" "$filename"
    
    # Check if split was successful
    if [ $? -ne 0 ]; then
        echo -e "    ${RED}✗ Failed to split file${NC}"
        cd "$original_dir"
        return 1
    fi
    
    # Go back to original directory
    cd "$original_dir"
    
    # Count number of parts created
    local part_count=$(ls -1 "${file_split_dir}/${archive_name}".* 2>/dev/null | wc -l)
    
    if [ "$part_count" -eq 0 ]; then
        echo -e "    ${RED}✗ No parts were created${NC}"
        return 1
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
        local part_name=$(basename "$part")
        local part_size
        
        if [[ "$OSTYPE" == "darwin"* ]]; then
            part_size=$(stat -f%z "$part" 2>/dev/null || echo 0)
        else
            part_size=$(stat -c%s "$part" 2>/dev/null || echo 0)
        fi
        
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
    "reassembly_instructions": "Place all parts in the same directory and run: 7z x ${archive_name}.001",
    "verification": "7z t ${archive_name}.001"
}
EOF
    
    # Verify the split was successful by checking if parts exist and manifest is valid
    if [ -f "${file_split_dir}/${archive_name}.001" ] && [ -s "$manifest_file" ]; then
        # Remove original large file after successful split
        rm -f "$file"
        echo -e "    ${GREEN}✓ Successfully split and removed original${NC}"
        echo -e "    ${BLUE}Manifest:${NC} $manifest_file"
        echo -e "    ${BLUE}Parts in:${NC} $file_split_dir"
        
        SPLIT_FILES=$((SPLIT_FILES + 1))
    else
        echo -e "    ${RED}✗ Split verification failed, keeping original file${NC}"
        return 1
    fi
}

# Find and process all files in target directory
echo -e "\n${BLUE}Scanning for large files...${NC}"
echo ""

# Use find without -print0 for better compatibility
find "$TARGET_DIR" -type f -not -path "*/.split_files/*" -not -path "*/.manifests/*" -not -name ".gitkeep" | while IFS= read -r file; do
    
    # Skip if file is in split_files or manifests directory
    if [[ "$file" == *"/.split_files/"* ]] || [[ "$file" == *"/.manifests/"* ]]; then
        continue
    fi
    
    TOTAL_FILES=$((TOTAL_FILES + 1))
    split_file "$file"
    
done

# Print summary
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
echo -e "Files split: ${YELLOW}$SPLIT_FILES${NC}"
echo -e "Files skipped (under ${MAX_SIZE_MB}MB): ${GREEN}$SKIPPED_FILES${NC}"

if [ $SPLIT_FILES -gt 0 ]; then
    echo -e "\n${YELLOW}⚠ Important:${NC}"
    echo -e "  Split files are stored in: ${BLUE}${SPLIT_DIR}${NC}"
    echo -e "  Manifests are stored in: ${BLUE}${MANIFEST_DIR}${NC}"
    echo -e "  Run ${GREEN}scripts/merge_files.sh${NC} to reassemble files locally"
fi

echo -e "\n${GREEN}Done!${NC}"
