<div align="center">
# > ⚠️ **IMPORTANT DISCLAIMER: FOR EDUCATIONAL PURPOSES ONLY**  <

---
<div align="center">
   
**[📜 View Download History](history/README.md)**
<div align="left">

# ⚡ DownLord

A GitHub Actions-powered universal downloader that grabs files from torrents, magnets, direct URLs, YouTube, and media sites. Auto-splits large files, preserves folder structure, and maintains a beautiful download history.

## 🚀 Features

- **Torrent & Magnet Support** — Downloads via aria2 with multi-connection speed
- **YouTube Fast API** — No cookies needed, bypasses restrictions
- **Media Sites** — yt-dlp integration for TikTok, SoundCloud, Spotify, Vimeo, Twitch, Bandcamp, Mixcloud, Audiomack, Deezer, Tidal, Dailymotion, Bilibili and more
- **Direct URL Support** — Any download link works automatically
- **Auto-Split Large Files** — Files over 95MB split into 95MB parts with 7zip
- **Smart Dependency Install** — Only installs heavy tools (yt-dlp, ffmpeg) when needed
- **Resume Support** — Interrupted downloads pick up where they left off
- **Selective Downloads** — Choose specific files by index or pattern from torrents
- **Batch Commits** — Files pushed in 1GB batches to stay under GitHub limits
- **Tehran Timezone** — All timestamps in Iran time (IR)
- **Download History** — Beautiful markdown page with icons, sizes, and clickable links
- **Storage Stats** — Total repo usage and download count at a glance

## 📋 Modes

| Mode | Best For |
|------|----------|
| **Torrent - Flat Files** | All files in one folder, large files split individually |
| **Torrent - Preserve Structure** | Keep original torrent folder hierarchy |
| **Torrent - Zip Entire Folder** | Zip entire folder, split if >95MB (one archive to download) |
| **Show Info Only** | Preview torrent contents before committing to download |
| **Upload as Artifact** | ⚠️ 90-day temporary storage (see warning below) |

> ⚠️ **Artifact Warning:** GitHub Artifacts are hosted on domains that are **not whitelisted** in Iran and may be inaccessible. Artifacts also **cannot be resumed** if the download breaks — you must start over from the beginning. They also **expire after 90 days**. Use only as a last resort. Regular repo downloads are more reliable and support resume.

## 🎬 Video Quality Options

| Quality | Description |
|---------|-------------|
| **Best quality** | Highest available resolution |
| **1080p** | Full HD |
| **720p** | HD (recommended for <95MB files) |
| **480p** | Standard definition |
| **Audio only** | MP3 extraction |
| **Subtitles only** | Download subtitles without video |

## 🔧 How to Use

### Quick Start
1. Go to the **Actions** tab in your repository
2. Select **DownLord** workflow
3. Click **Run workflow**
4. Fill in the fields and click **Run workflow**

### Input Fields

| Field | Description | Example |
|-------|-------------|---------|
| `url` | Torrent, magnet, or direct URL | `magnet:?xt=urn:btih:...` or `https://youtube.com/watch?v=...` |
| `mode` | Download mode (see above) | `Torrent - Flat Files` |
| `video_quality` | Quality for media sites | `720p` |
| `fast_api` | Use fast API for YouTube (no cookies needed) | `true` (default) |
| `subtitles` | Embed English subtitles | `true` (default) |
| `auto_subs` | Allow auto-generated subtitles | `false` (default) |
| `playlist` | Download entire playlist | `false` (default) |
| `select_files` | Torrent: specific file indexes | `1,3,5` or leave empty for all |
| `file_pattern` | Torrent: file pattern | `*.mkv` or leave empty |

### YouTube Download
1. Set mode to any option (e.g., `Torrent - Flat Files`)
2. Paste YouTube URL
3. Leave `fast_api` ON (default) — works without cookies
4. Select quality: `Best quality`, `1080p`, `720p`, `480p`, or `Audio only`
5. Toggle `subtitles` for English captions

### Torrent Download
1. Set mode to `Torrent - Flat Files`, `Preserve Structure`, or `Zip Entire Folder`
2. Paste magnet link or .torrent URL
3. Optionally use `Show Info Only` first to see file listing
4. Use `select_files` to download specific files (e.g., `1,3,5`)

### Direct URL Download
1. Set mode to any torrent mode or `Upload as Artifact`
2. Paste the direct download link
3. The workflow auto-detects it's a direct file

## 📜 Viewing Downloads

After the workflow completes, open `history/README.md` for your download history:

- 📅 Each entry shows date in Tehran time
- 🎬 File type icons (video, audio, image, archive, etc.)
- 📦 Split archives grouped with tree structure
- 💡 Reassembly instructions for split parts
- 📋 `[Download All Links]` button for a text file with all URLs
- 💾 Storage stats at the top

## 🔧 Reassembling Split Files

1. Download all `.7z.001`, `.7z.002`, etc. parts
2. Install 7zip:
   - **Linux:** `sudo apt-get install p7zip-full`
   - **macOS:** `brew install p7zip`
   - **Windows:** [7-zip.org](https://7-zip.org)
3. Extract:
   ```bash
   7z x filename.7z.001
   
   
   📊 Supported Sites (via yt-dlp)
YouTube, TikTok, SoundCloud, Spotify, Bandcamp, Vimeo, Twitch, Dailymotion, Bilibili, Mixcloud, Audiomack, Deezer, Tidal — with cookies for best results.

# ⚠️ Limits

Limit	Value
---------------------------------------------------------
Individual file size	100 MB (files auto-split at 95MB)
---------------------------------------------------------
Push size	2 GB (handled by 1GB batch commits)
---------------------------------------------------------
Artifact retention	90 days (then auto-deleted)
---------------------------------------------------------
Workflow timeout	6 hours
---------------------------------------------------------

# 🛠️ How It Works
1.URL Detection — Auto-detects torrent, YouTube, media site, or direct URL

2.Smart Install — Only installs heavy tools (yt-dlp, ffmpeg) if media sites detected

3.Download — aria2 for torrents/direct, fast API for YouTube, yt-dlp for media sites

4.Split — Files >95MB get split with 7zip (multi-threaded)

5.Report — Generates manifest with file sizes and SHA256 hashes

6.History — Updates markdown page with clickable download links

7.Commit — Pushes files in 1GB batches with rate limit awareness






