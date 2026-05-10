#!/usr/bin/env python3

import json
import argparse
import os
from datetime import datetime
from pathlib import Path
import urllib.parse

def update_history(timestamp, torrent_url, repo, branch="main"):
    history_dir = "history"
    manifest_file = f"{history_dir}/{timestamp}/manifest.json"
    history_readme = f"{history_dir}/README.md"
    
    # Create history directory if it doesn't exist
    os.makedirs(history_dir, exist_ok=True)
    
    # Load manifest
    with open(manifest_file, 'r') as f:
        manifest = json.load(f)
    
    # Generate markdown entry
    markdown_entry = generate_markdown_entry(timestamp, torrent_url, repo, branch, manifest)
    
    # Update or create history README
    if os.path.exists(history_readme):
        with open(history_readme, 'r') as f:
            content = f.read()
        
        # Insert new entry after the header section
        insertion_marker = "## 📥 Download History"
        if insertion_marker in content:
            # Find the end of the header section
            parts = content.split(insertion_marker)
            if len(parts) > 1:
                # Add new entry after the header
                content = parts[0] + insertion_marker + "\n\n" + markdown_entry + parts[1]
        else:
            # If marker not found, append to end
            content += "\n\n" + markdown_entry
    else:
        content = generate_new_history_readme(markdown_entry)
    
    with open(history_readme, 'w') as f:
        f.write(content)
    
    # Also update the main README with a link to history
    update_main_readme(repo, branch)

def format_timestamp(timestamp):
    """Convert YYYYMMDD_HHMMSS to readable date string"""
    try:
        date_part = timestamp.split('_')[0]
        time_part = timestamp.split('_')[1]
        
        year = int(date_part[0:4])
        month = int(date_part[4:6])
        day = int(date_part[6:8])
        hour = int(time_part[0:2])
        minute = int(time_part[2:4])
        second = int(time_part[4:6])
        
        dt = datetime(year, month, day, hour, minute, second)
        return dt.strftime("%Y-%m-%d %H:%M:%S UTC")
    except:
        return timestamp

def generate_markdown_entry(timestamp, torrent_url, repo, branch, manifest):
    date_str = format_timestamp(timestamp)
    download_dir = manifest.get('download_dir', f'downloads/download_{timestamp}')
    
    # Get the download directory name from the manifest
    dir_name = Path(download_dir).name if 'download_dir' in manifest else f'download_{timestamp}'
    
    entry = f"""### 📅 {date_str}

**Torrent/Magnet:** 
