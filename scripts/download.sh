#!/bin/bash

# Torrent downloader with aria2 and automatic file splitting

set -e

RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Configuration
DOWNLOAD_PATH="${2:-downloads}"
MAX_CONNECTIONS="${3:-16}"
TORRENT_URL="$1"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Validate input
if [ -z "$TORRENT_URL" ]; then
    echo -e "${RED}Error: No torrent URL or magnet link provided${NC}"
    echo "Usage: $0 <torrent_url_or_magnet> [download_path] [max_connections]"
    exit 1
fi

# Check requirements
if ! command -v aria2c &> /dev/null; then
    echo -e "${RED}Error: aria2 is not installed${NC}"
    echo "Install with: sudo apt-get install aria2"
    exit 1
fi

if ! command -v 7z &> /dev/null; then
    echo -e "${RED}Error: 7zip is not installed${NC}"
    echo "Install with: sudo apt-get install p7zip-full"
    exit 1
fi

# Create download directory
mkdir -p "$DOWNLOAD_PATH"

echo -e "${GREEN}=== Aria2 Torrent Downloader ===${NC}"
echo -e "URL: ${YELLOW}${TORRENT_URL:0:100}...${NC}"
echo -e "Download Path: ${YELLOW}$DOWNLOAD_PATH${NC}"
echo -e "Max Connections: ${YELLOW}$MAX_CONNECTIONS${NC}"
echo "=================================="

# Step 1: Download with aria2
echo -e "\n${BLUE}[1/2] Downloading torrent...${NC}"

aria2c \
    --dir="$DOWNLOAD_PATH" \
    --max-connection-per-server="$MAX_CONNECTIONS" \
    --split="$MAX_CONNECTIONS" \
    --min-split-size=1M \
    --max-concurrent-downloads=5 \
    --continue=true \
    --max-overall-download-limit=0 \
    --seed-time=0 \
    --seed-ratio=0.0 \
    --bt-max-peers=100 \
    --enable-dht=true \
    --dht-listen-port=6881-6999 \
    --file-allocation=none \
    --console-log-level=notice \
    --summary-interval=30 \
    "$TORRENT_URL"

if [ $? -ne 0 ]; then
    echo -e "${RED}Download failed!${NC}"
    exit 1
fi

echo -e "\n${GREEN}Download completed!${NC}"

# Step 2: Split large files
echo -e "\n${BLUE}[2/2] Processing files (splitting if >95MB)...${NC}"

bash "$SCRIPT_DIR/split_large_files.sh" "$DOWNLOAD_PATH"

echo -e "\n${GREEN}=== Process Complete ===${NC}"
