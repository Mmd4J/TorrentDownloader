#!/bin/bash

# Torrent downloader with aria2
# Usage: ./download.sh <torrent_url> [download_path] [max_connections]

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

DOWNLOAD_PATH="${2:-downloads}"
MAX_CONNECTIONS="${3:-16}"
TORRENT_URL="$1"

# Validate input
if [ -z "$TORRENT_URL" ]; then
    echo -e "${RED}Error: No torrent URL or magnet link provided${NC}"
    echo "Usage: $0 <torrent_url> [download_path] [max_connections]"
    exit 1
fi

# Check requirements
if ! command -v aria2c &> /dev/null; then
    echo -e "${RED}Error: aria2 is not installed${NC}"
    echo "Install with: sudo apt-get install aria2"
    exit 1
fi

# Create download directory
mkdir -p "$DOWNLOAD_PATH"

# Clean up any orphaned aria2 control files and incomplete downloads
echo -e "${BLUE}Checking for incomplete downloads...${NC}"

# Find and handle problem files
find "$DOWNLOAD_PATH" -type f -not -name '.gitkeep' -not -path "*/.split_files/*" -not -path "*/.manifests/*" | while read file; do
    filename=$(basename "$file")
    dir=$(dirname "$file")
    aria2_file="${file}.aria2"
    
    # Check if file exists without its aria2 control file
    if [ ! -f "$aria2_file" ]; then
        # Check if there's a corresponding .aria2 file anywhere
        if ! find "$DOWNLOAD_PATH" -name "${filename}.aria2" | grep -q .; then
            echo -e "  ${YELLOW}Found incomplete file (no control file): ${filename}${NC}"
            echo -e "  ${YELLOW}Removing to allow clean download...${NC}"
            rm -f "$file"
        fi
    fi
done

# Also clean up orphaned .aria2 files without their main file
find "$DOWNLOAD_PATH" -name "*.aria2" | while read aria2_file; do
    main_file="${aria2_file%.aria2}"
    if [ ! -f "$main_file" ]; then
        echo -e "  ${YELLOW}Removing orphaned control file: $(basename "$aria2_file")${NC}"
        rm -f "$aria2_file"
    fi
done

echo -e "${GREEN}✓ Cleanup complete${NC}"

echo -e "${GREEN}=== Aria2 Torrent Downloader ===${NC}"
echo -e "URL: ${YELLOW}${TORRENT_URL:0:100}...${NC}"
echo -e "Download Path: ${YELLOW}$DOWNLOAD_PATH${NC}"
echo -e "Max Connections: ${YELLOW}$MAX_CONNECTIONS${NC}"
echo "=================================="

# Download with aria2
# Added --allow-overwrite=true and --auto-file-renaming=false for robustness
aria2c \
    --dir="$DOWNLOAD_PATH" \
    --max-connection-per-server="$MAX_CONNECTIONS" \
    --split="$MAX_CONNECTIONS" \
    --min-split-size=1M \
    --continue=true \
    --allow-overwrite=true \
    --auto-file-renaming=false \
    --seed-time=0 \
    --seed-ratio=0.0 \
    --bt-max-peers=100 \
    --enable-dht=true \
    --dht-listen-port=6881-6999 \
    --file-allocation=none \
    --console-log-level=notice \
    --summary-interval=10 \
    "$TORRENT_URL"

EXIT_CODE=$?

if [ $EXIT_CODE -eq 0 ]; then
    echo -e "\n${GREEN}=== Download Completed Successfully ===${NC}"
    
    # Display downloaded files
    echo -e "\n${YELLOW}Downloaded files:${NC}"
    find "$DOWNLOAD_PATH" -type f -not -name '.gitkeep' -not -name '*.aria2' -exec ls -lh {} \; | awk '{print "  " $5 "\t" $9}'
    
    # Calculate total size
    TOTAL_SIZE=$(du -sh "$DOWNLOAD_PATH" --exclude=.split_files --exclude=.manifests 2>/dev/null | cut -f1)
    echo -e "\n${YELLOW}Total download size: ${GREEN}$TOTAL_SIZE${NC}"
else
    echo -e "\n${RED}=== Download Failed (Exit code: $EXIT_CODE) ===${NC}"
    echo -e "${YELLOW}Tip: If the error is about existing files, try running again to resume.${NC}"
    exit $EXIT_CODE
fi
