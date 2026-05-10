#!/bin/bash

# Display torrent file information
# Usage: ./torrent-info.sh <magnet_link_or_torrent> [--json]

set -e

CYAN='\033[0;36m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

TORRENT_URL="$1"
OUTPUT_FORMAT="${2:---text}"

if [ -z "$TORRENT_URL" ]; then
    echo "Usage: $0 <magnet_link_or_torrent_file> [--json]"
    exit 1
fi

# Get torrent metadata
TEMP_DIR=$(mktemp -d)

if [[ "$TORRENT_URL" == magnet:* ]]; then
    aria2c \
        --dir="$TEMP_DIR" \
        --bt-metadata-only=true \
        --bt-save-metadata=true \
        --seed-time=0 \
        --quiet=true \
        "$TORRENT_URL" 2>/dev/null || true
    
    TORRENT_FILE=$(find "$TEMP_DIR" -name "*.torrent" | head -1)
elif [[ "$TORRENT_URL" == http* ]] && [[ "$TORRENT_URL" != *.torrent ]]; then
    wget -q -O "$TEMP_DIR/torrent.torrent" "$TORRENT_URL"
    TORRENT_FILE="$TEMP_DIR/torrent.torrent"
elif [[ -f "$TORRENT_URL" ]]; then
    TORRENT_FILE="$TORRENT_URL"
else
    echo "Error: Cannot fetch torrent metadata"
    rm -rf "$TEMP_DIR"
    exit 1
fi

if [ ! -f "$TORRENT_FILE" ]; then
    echo "Error: Failed to get torrent file"
    rm -rf "$TEMP_DIR"
    exit 1
fi

# Parse and output
if [ "$OUTPUT_FORMAT" = "--json" ]; then
    # JSON output
    echo "{"
    echo "  \"torrent_url\": \"$TORRENT_URL\","
    echo "  \"files\": ["
    
    FIRST=true
    while IFS='|' read -r index size name; do
        if [ -n "$index" ]; then
            HUMAN_SIZE=$(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes")
            [ "$FIRST" = false ] && echo ","
            echo -n "    {\"index\": $index, \"size\": $size, \"human_size\": \"$HUMAN_SIZE\", \"name\": \"$name\"}"
            FIRST=false
        fi
    done < <(aria2c --show-files "$TORRENT_FILE" 2>/dev/null | grep -E '^[0-9]+\|')
    
    echo ""
    echo "  ]"
    echo "}"
else
    # Human-readable output
    echo -e "\n${CYAN}=== Torrent Information ===${NC}"
    echo ""
    
    while IFS='|' read -r index size name; do
        if [ -n "$index" ]; then
            HUMAN_SIZE=$(numfmt --to=iec $size 2>/dev/null || echo "${size} bytes")
            echo -e "  ${CYAN}[$index]${NC} ${GREEN}$name${NC}"
            echo -e "       ${YELLOW}Size: $HUMAN_SIZE${NC}"
            
            # Show extension badge
            EXT="${name##*.}"
            case "$EXT" in
                mkv|mp4|avi|mov) echo -e "       🎬 Video" ;;
                mp3|flac|wav|aac) echo -e "       🎵 Audio" ;;
                srt|sub|ass)     echo -e "       📝 Subtitle" ;;
                iso|img|dmg)     echo -e "       💿 Disk Image" ;;
                zip|rar|7z|tar)  echo -e "       📦 Archive" ;;
                *)               echo -e "       📄 $EXT File" ;;
            esac
            echo ""
        fi
    done < <(aria2c --show-files "$TORRENT_FILE" 2>/dev/null | grep -E '^[0-9]+\|')
    
    TOTAL_SIZE=$(aria2c --show-files "$TORRENT_FILE" 2>/dev/null | grep -E '^[0-9]+\|' | awk -F'|' '{sum+=$2} END {print sum}')
    if [ -n "$TOTAL_SIZE" ]; then
        HUMAN_TOTAL=$(numfmt --to=iec $TOTAL_SIZE 2>/dev/null || echo "${TOTAL_SIZE} bytes")
        echo -e "${YELLOW}Total size: $HUMAN_TOTAL${NC}"
    fi
    
    echo ""
    echo -e "${YELLOW}Selection examples:${NC}"
    echo -e "  ${GREEN}1,2,3${NC}    - Download files 1, 2, and 3"
    echo -e "  ${GREEN}2-5${NC}      - Download files 2 through 5"
    echo -e "  ${GREEN}1,3-6,9${NC}  - Download files 1, 3-6, and 9"
fi

rm -rf "$TEMP_DIR"
