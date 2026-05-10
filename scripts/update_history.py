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
    
    entry = f"### 📅 {date_str}\n\n"
    entry += f"**Torrent/Magnet:** \n```\n{torrent_url}\n```\n\n"
    entry += "**Files:**\n\n"
    entry += "| File | Size | Download |\n"
    entry += "|------|------|----------|\n"
    
    for file in manifest['files']:
        file_path = file['path']
        size = file['size_human']
        
        # Create GitHub raw download link
        encoded_path = urllib.parse.quote(file_path)
        download_url = f"https://raw.githubusercontent.com/{repo}/{branch}/{download_dir}/{encoded_path}"
        
        # Determine if it's a split file
        is_split = '.7z.' in file_path
        file_icon = "📦" if is_split else "📄"
        
        entry += f"| {file_icon} `{file_path}` | {size} | [⬇️ Download]({download_url}) |\n"
    
    # Add reassembly instructions if there are split files
    has_splits = any('.7z.' in f['path'] for f in manifest['files'])
    if has_splits:
        entry += "\n> 💡 **Split Files Detected!** To reassemble:\n"
        entry += "> ```bash\n"
        entry += "> # Install 7zip if needed\n"
        entry += "> sudo apt-get install p7zip-full  # Linux\n"
        entry += "> brew install p7zip                # macOS\n"
        entry += "> \n"
        entry += "> # Download all .7z.001, .7z.002, etc. files, then:\n"
        entry += "> 7z x filename.7z.001\n"
        entry += "> ```\n"
    
    entry += "\n---\n\n"
    return entry

def generate_new_history_readme(entry):
    now = datetime.utcnow().strftime("%Y-%m-%d %H:%M:%S UTC")
    
    content = "# 📥 Torrent Download History\n\n"
    content += "Welcome to the download history! This page is automatically updated by GitHub Actions.\n\n"
    content += "## 📊 Quick Stats\n"
    content += "- Downloads are processed using **aria2**\n"
    content += "- Large files (>95MB) are automatically split using **7zip**\n"
    content += "- All files are stored in the `downloads/` directory\n\n"
    content += "## 📥 Download History\n\n"
    content += entry
    content += "## 📁 File Structure\n"
    content += "```\n"
    content += "downloads/\n"
    content += "├── YYYYMMDD_HHMMSS_torrentname/\n"
    content += "│   ├── file1.txt\n"
    content += "│   ├── largefile.7z.001\n"
    content += "│   ├── largefile.7z.002\n"
    content += "│   └── manifest.json\n"
    content += "```\n\n"
    content += "## 🔧 Reassembling Split Files\n"
    content += "Split files use 7zip's volume format. Download all parts and extract:\n"
    content += "```bash\n"
    content += "7z x filename.7z.001\n"
    content += "```\n\n"
    content += "---\n\n"
    content += f"*Last updated: {now}*\n"
    
    return content

def update_main_readme(repo, branch):
    """Add a link to history in the main README if it doesn't exist"""
    readme_path = "README.md"
    history_link = "\n\n[📜 View Download History](history/README.md)\n"
    
    if os.path.exists(readme_path):
        with open(readme_path, 'r') as f:
            content = f.read()
        
        if "View Download History" not in content:
            with open(readme_path, 'a') as f:
                f.write(history_link)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Update torrent download history')
    parser.add_argument('--timestamp', required=True)
    parser.add_argument('--torrent', required=True)
    parser.add_argument('--repo', required=True)
    parser.add_argument('--branch', default='main')
    
    args = parser.parse_args()
    update_history(args.timestamp, args.torrent, args.repo, args.branch)
