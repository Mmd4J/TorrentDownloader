#!/usr/bin/env python3

import json
import argparse
import os
from datetime import datetime
from pathlib import Path

def update_history(timestamp, torrent_url, repo):
    history_file = "history.html"
    manifest_file = f"history/{timestamp}/manifest.json"
    
    # Load manifest
    with open(manifest_file, 'r') as f:
        manifest = json.load(f)
    
    # Create history entry HTML
    history_entry = generate_history_entry(timestamp, torrent_url, repo, manifest)
    
    # Update history.html
    if os.path.exists(history_file):
        with open(history_file, 'r') as f:
            content = f.read()
        
        # Insert new entry after the header
        insertion_point = content.find('<div class="history-list">')
        if insertion_point != -1:
            insertion_point = content.find('>', insertion_point) + 1
            content = content[:insertion_point] + history_entry + content[insertion_point:]
        else:
            content = generate_new_history_html(history_entry)
    else:
        content = generate_new_history_html(history_entry)
    
    with open(history_file, 'w') as f:
        f.write(content)

def format_timestamp(timestamp):
    """Convert YYYYMMDD_HHMMSS to readable date string"""
    try:
        # Parse the timestamp format: 20260510_204819
        date_part = timestamp.split('_')[0]  # 20260510
        time_part = timestamp.split('_')[1]  # 204819
        
        year = int(date_part[0:4])
        month = int(date_part[4:6])
        day = int(date_part[6:8])
        hour = int(time_part[0:2])
        minute = int(time_part[2:4])
        second = int(time_part[4:6])
        
        dt = datetime(year, month, day, hour, minute, second)
        return dt.strftime("%Y-%m-%d %H:%M:%S")
    except (IndexError, ValueError) as e:
        print(f"Warning: Could not parse timestamp '{timestamp}': {e}")
        return timestamp  # Return original if parsing fails

def generate_history_entry(timestamp, torrent_url, repo, manifest):
    date_str = format_timestamp(timestamp)
    
    files_html = ""
    for file in manifest['files']:
        file_path = file['path']
        # URL encode the file path for the download link
        encoded_path = file_path.replace(' ', '%20')
        download_url = f"https://raw.githubusercontent.com/{repo}/main/downloads/download_{timestamp}/{encoded_path}"
        
        # Check if it's a split file
        is_split = '.7z.' in file_path and any(file_path.endswith(f'.{str(i).zfill(3)}') for i in range(1, 1000))
        
        file_icon = "📦" if is_split else "📄"
        files_html += f"""
            <div class="file-item">
                <span class="file-name">{file_icon} {file_path}</span>
                <span class="file-size">({file['size_human']})</span>
                <a href="{download_url}" class="download-link" target="_blank">⬇️ Download</a>
                <span class="file-hash" title="SHA256: {file['sha256']}">🔒</span>
            </div>
        """
    
    return f"""
        <div class="history-entry">
            <div class="entry-header">
                <span class="date">📅 {date_str}</span>
                <span class="torrent-url">🔗 {torrent_url[:80]}{'...' if len(torrent_url) > 80 else ''}</span>
            </div>
            <div class="entry-files">
                {files_html}
            </div>
        </div>
    """

def generate_new_history_html(history_entry):
    return f"""<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Torrent Download History</title>
    <style>
        * {{
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }}
        
        body {{
            font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Oxygen, Ubuntu, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            padding: 20px;
        }}
        
        .container {{
            max-width: 1200px;
            margin: 0 auto;
            background: white;
            border-radius: 15px;
            box-shadow: 0 20px 60px rgba(0,0,0,0.3);
            overflow: hidden;
        }}
        
        .header {{
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 30px;
            text-align: center;
        }}
        
        .header h1 {{
            font-size: 2.5em;
            margin-bottom: 10px;
        }}
        
        .header p {{
            opacity: 0.9;
            font-size: 1.1em;
        }}
        
        .history-list {{
            padding: 20px;
        }}
        
        .history-entry {{
            background: #f8f9fa;
            border-radius: 10px;
            padding: 20px;
            margin-bottom: 20px;
            border-left: 4px solid #667eea;
            transition: transform 0.2s, box-shadow 0.2s;
        }}
        
        .history-entry:hover {{
            transform: translateX(5px);
            box-shadow: 0 5px 15px rgba(0,0,0,0.1);
        }}
        
        .entry-header {{
            display: flex;
            justify-content: space-between;
            align-items: center;
            padding-bottom: 15px;
            border-bottom: 1px solid #dee2e6;
            margin-bottom: 15px;
            flex-wrap: wrap;
            gap: 10px;
        }}
        
        .date {{
            font-weight: bold;
            color: #495057;
            white-space: nowrap;
        }}
        
        .torrent-url {{
            color: #6c757d;
            font-size: 0.9em;
            word-break: break-all;
        }}
        
        .file-item {{
            display: flex;
            align-items: center;
            padding: 10px 15px;
            background: white;
            border-radius: 5px;
            margin-bottom: 8px;
            gap: 15px;
            flex-wrap: wrap;
        }}
        
        .file-name {{
            flex: 1;
            font-family: 'Courier New', monospace;
            color: #212529;
            word-break: break-all;
            min-width: 200px;
        }}
        
        .file-size {{
            color: #6c757d;
            font-size: 0.9em;
            white-space: nowrap;
        }}
        
        .download-link {{
            display: inline-block;
            padding: 8px 20px;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            text-decoration: none;
            border-radius: 5px;
            transition: transform 0.2s, box-shadow 0.2s;
            white-space: nowrap;
        }}
        
        .download-link:hover {{
            transform: scale(1.05);
            box-shadow: 0 5px 15px rgba(102, 126, 234, 0.4);
            text-decoration: none;
            color: white;
        }}
        
        .file-hash {{
            cursor: help;
            font-size: 1.2em;
        }}
        
        .split-notice {{
            background: #fff3cd;
            border: 1px solid #ffc107;
            border-radius: 5px;
            padding: 10px;
            margin-top: 10px;
            font-size: 0.9em;
            color: #856404;
        }}
        
        @media (max-width: 768px) {{
            .file-item {{
                flex-direction: column;
                align-items: flex-start;
                gap: 10px;
            }}
            
            .entry-header {{
                flex-direction: column;
                align-items: flex-start;
            }}
            
            .download-link {{
                width: 100%;
                text-align: center;
            }}
        }}
    </style>
</head>
<body>
    <div class="container">
        <div class="header">
            <h1>📥 Torrent Download History</h1>
            <p>All downloads are processed via GitHub Actions with aria2</p>
        </div>
        <div class="history-list">
            {history_entry}
        </div>
    </div>
</body>
</html>"""

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Update torrent download history')
    parser.add_argument('--timestamp', required=True, help='Download timestamp (YYYYMMDD_HHMMSS)')
    parser.add_argument('--torrent', required=True, help='Torrent URL or magnet link')
    parser.add_argument('--repo', required=True, help='GitHub repository (owner/repo)')
    
    args = parser.parse_args()
    update_history(args.timestamp, args.torrent, args.repo)
