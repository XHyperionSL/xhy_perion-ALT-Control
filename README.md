<div align="center">

# 🎵 Hyperion Music Bot

**Play YouTube music in Roblox through an in-game bot.**

The server runs on your PC, downloads and plays audio locally.<br>
Bots in-game send HTTP requests to control playback — everyone in the server hears it through your mic.

[![Discord](https://img.shields.io/badge/Discord-Join%20Server-5865F2?style=for-the-badge&logo=discord&logoColor=white)](https://discord.gg/kfxRmYzp3t)

**Designed by [@xhy_perion](https://github.com/xhy_perion)**

</div>

---

## 📦 What's Included

```
MusicBot/
├── server.py                 # Python backend (YouTube download + playback)
├── install_dependencies.bat  # One-click dependency installer
├── start_server.bat          # Server launcher
├── storage/                  # Auto-created audio cache
│   └── cache/
└── README.md
```

> **Note:** The Lua client is integrated into `NewAltControl.lua` — the music commands section handles all in-game interaction.

---

## 🚀 Quick Start

### Step 1 — Install Dependencies

> Double-click `install_dependencies.bat` — it auto-requests admin privileges.

The installer automatically handles:

| Dependency | Purpose |
|:-----------|:--------|
| Python 3.x | Runs the server |
| FFmpeg | Audio conversion |
| yt-dlp | YouTube downloading |
| Flask | HTTP API server |
| Flask-CORS | Cross-origin support |
| pygame | Audio playback engine |

### Step 2 — Configure the Server

Open `server.py` and edit the config at the top:

```python
API_KEY      = "YOUR_API_KEY_HERE"         # Make up a strong key (any string)
MAIN_ACCOUNT = "YOUR_ROBLOX_USERNAME"      # Your Roblox username
```

### Step 3 — Configure the Lua Client

In `NewAltControl.lua`, update the Settings table:

```lua
musicServerURL  = "http://YOUR_PC_IP:5000";   -- Your PC's local IP address
musicApiKey     = "YOUR_API_KEY_HERE";         -- Must match server.py
mainAccount     = "YOUR_ROBLOX_USERNAME";      -- Must match server.py
musicBotAccount = "YOUR_BOT_USERNAME";         -- Which alt bot talks to the server
```

<details>
<summary>💡 How to find your PC's local IP</summary>

1. Open **Command Prompt**
2. Type `ipconfig`
3. Look for `IPv4 Address` under your active network adapter
4. It usually looks like `192.168.x.x`

</details>

### Step 4 — Launch

1. Double-click **`start_server.bat`**
2. Load `NewAltControl.lua` on your bot accounts in-game
3. The designated music bot will announce **`🎵 Music Bot Ready 🎵`**

---

## 🎹 Commands

### Everyone

| Command | Description |
|:--------|:------------|
| `/play <song>` | Search and play a song from YouTube |
| `/np` | Show what's currently playing |
| `/queue` | View the song queue |
| `/status` | Full playback status |
| `/stats [user]` | View play statistics |
| `/history` | Recently played songs |
| `/cmds` | Show all music commands |

### Authorized Users

| Command | Description |
|:--------|:------------|
| `/pause` | Pause playback |
| `/resume` | Resume playback |
| `/skip` | Skip current song |
| `/stop` | Stop and clear queue |
| `/volume <0-100>` | Set volume level |

### Admin Only (Main Account)

| Command | Description |
|:--------|:------------|
| `/auth <user>` | Authorize a user for playback controls |
| `/unauth <user>` | Revoke authorization |
| `/blacklist <user>` | Block a user from the music bot |
| `/unblacklist <user>` | Remove a user from the blacklist |

---

## ⚙️ How It Works

```
┌──────────────────┐                    ┌──────────────────┐
│                  │     HTTP Request   │                  │
│   Roblox Bot     │ ─────────────────► │   Python Server  │
│   (Lua Client)   │                    │   (server.py)    │
│                  │ ◄───────────────── │                  │
│   Reads chat     │   JSON Response    │   Downloads from │
│   Sends replies  │                    │   YouTube, plays │
│                  │                    │   through your   │
└──────────────────┘                    │   PC speakers    │
                                        └──────────────────┘
```

1. A player types `/play <song>` in Roblox chat
2. The designated bot catches the command via chat listener
3. The bot sends an HTTP request to your local Python server
4. The server searches YouTube, downloads the audio, and plays it through your speakers
5. The bot announces the song title in game chat

---

## 🔒 Security

| Feature | Description |
|:--------|:------------|
| **API Key** | All requests require a matching `X-API-Key` header |
| **Authorization** | Only the main account and `/auth`'d users can control playback |
| **Blacklist** | Block specific users from using the music bot |
| **Rate Limiting** | Built-in per-user cooldowns prevent command spam |

---

## ❓ Troubleshooting

| Problem | Solution |
|:--------|:---------|
| Bot doesn't respond | Verify `musicBotAccount` matches the bot's exact Roblox username |
| `Connection refused` | Make sure `start_server.bat` is running on your PC |
| Wrong IP | Run `ipconfig` in CMD and use the correct `IPv4 Address` |
| Songs don't play | Verify FFmpeg is installed — run `ffmpeg -version` in CMD |
| `Invalid API key` | Ensure `API_KEY` matches exactly between `server.py` and Lua config |
| `Not authorized` | Main account must run `/auth <username>` to grant controls |

---

<div align="center">

## 📝 License

This project is for **personal and educational use**.<br>
Do not redistribute without credit.

**Made with ❤️ by [@xhy_perion](https://discord.gg/kfxRmYzp3t)**

</div>
