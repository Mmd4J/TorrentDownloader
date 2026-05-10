# 📥 Torrent Download History

Welcome to the download history! This page is automatically updated by GitHub Actions.

## 📊 Quick Stats
- Downloads are processed using **aria2**
- Large files (>95MB) are automatically split using **7zip**
- All files are stored in the `downloads/` directory

## 📥 Download History

### 📅 2026-05-10 21:19:35 UTC

**Torrent/Magnet:** 
```
magnet:?xt=urn:btih:fd92a7dc34ca77c60167d555402b955e77588f9d&dn=The%20Los%20Angeles%20BB%20Murder%20Cases%20by%20Nisioisin.zip&tr=http%3a%2f%2fnyaa.tracker.wf%3a7777%2fannounce&tr=udp%3a%2f%2fopen.stealth.si%3a80%2fannounce&tr=udp%3a%2f%2ftracker.opentrackr.org%3a1337%2fannounce&tr=udp%3a%2f%2fexodus.desync.com%3a6969%2fannounce&tr=udp%3a%2f%2ftracker.torrent.eu.org%3a451%2fannounce
```

**Files:**

| File | Size | Download |
|------|------|----------|

---


## 📁 File Structure
```
downloads/
├── YYYYMMDD_HHMMSS_torrentname/
│   ├── file1.txt
│   ├── largefile.7z.001
│   ├── largefile.7z.002
│   └── manifest.json
```

## 🔧 Reassembling Split Files
Split files use 7zip's volume format. Download all parts and extract:
```bash
7z x filename.7z.001
```

---

*Last updated: 2026-05-10 21:19:47 UTC*
