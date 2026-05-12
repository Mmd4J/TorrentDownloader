<div align="center">
# > ⚠️ **IMPORTANT DISCLAIMER: FOR EDUCATIONAL PURPOSES ONLY**  <

---
<div align="center">
   
**[📜 View Download History](history/README.md)**
<div align="left">

# 📥 Torrent Downloader

A GitHub Actions-powered downloader that supports torrents, magnets, and direct URLs with automatic file splitting and download history.

## 🚀 Features

- **Torrent & Magnet Support** - Download via aria2 with multi-connection speed
- **Direct URL Support** - Any direct download link works automatically
- **Auto-Split Large Files** - Files over 95MB are split into 95MB parts with 7zip
- **Download History** - Clickable file links with icons, sizes, and reassembly instructions
- **Resume Support** - Interrupted downloads resume where they left off
- **Selective Downloads** - Choose specific files by index or pattern
- **Batch Commits** - Files pushed in 500MB batches to avoid GitHub limits
- **Tehran Timezone** - All timestamps in Iran time

## 📋 Modes

| Mode | Description |
|------|-------------|
| **Torrent - Flat Files** | All files in one folder, large files split individually |
| **Torrent - Preserve Structure** | Keeps original torrent folder hierarchy |
| **Torrent - Zip Entire Folder** | Zips entire folder, splits the zip if >95MB |
| **Torrent - Show Info Only** | Preview torrent contents without downloading |
| **Upload as Artifact** | Upload as GitHub Artifact (90-day retention, no splitting) |

## 🔧 How to Use

1. Go to the **Actions** tab
2. Select **Torrent Downloader**
3. Click **Run workflow**
4. Fill in the fields:

| Field | Description | Example |
|-------|-------------|---------|
| `url` | Torrent, magnet, or direct URL | `magnet:?xt=urn:btih:...` or `https://example.com/file.zip` |
| `mode` | Download mode (see above) | `Torrent - Flat Files` |
| `max_connections` | Parallel connections | `16` (default) |
| `select_files` | Specific file indexes to download | `1,3,5` or leave empty for all |
| `file_pattern` | File pattern to match | `*.mkv` or leave empty |
| `output_filename` | Custom filename for direct downloads | `movie.mp4` (optional) |

5. Click **Run workflow**

## 📜 Viewing Downloads

After the workflow completes:
- Open `history/README.md` for formatted download history
- Each entry shows files with clickable download links
- Split files are grouped with reassembly instructions
- Click `[📋 Download All Links]` for a text file with all URLs

## 🔧 Reassembling Split Files

1. Download all `.7z.001`, `.7z.002`, etc. parts
2. Install 7zip:
   - **Linux:** `sudo apt-get install p7zip-full`
   - **macOS:** `brew install p7zip`
   - **Windows:** Download from [7-zip.org](https://7-zip.org)
3. Extract:
   ```bash
   7z x filename.7z.001
   
##🗑️ Cleanup
Use the Cleanup Downloads & History workflow to free space:

Clean Everything - Remove all downloads and history

Clean Downloads Only - Remove downloaded files

Clean History Only - Clear history entries

Keep Last 3/5 Downloads - Remove older downloads

##⚠️ Limits
Limit	Value
-----------------------------------------------------
Individual file size	100 MB (files split at 95MB)
-----------------------------------------------------
Push size	2 GB (handled by 500MB batch commits)
-----------------------------------------------------
Artifact retention	90 days (10GB MAX)
-----------------------------------------------------
-----------------------------------------------------
Workflow timeout	6 hours
