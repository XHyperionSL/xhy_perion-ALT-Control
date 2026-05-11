"""
Hyperion Music Bot Server — Python Backend
Plays YouTube audio through your PC speakers.
Bots in-game send HTTP requests to this server.

SETUP:
  1. Run install_dependencies.bat FIRST (one time only)
  2. Edit the CONFIG section below with your own values
  3. Run start_server.bat to launch
  4. Configure the Lua client with the same API_KEY and server URL

Credits: @xhy_perion
Discord: https://discord.gg/kfxRmYzp3t
"""

import os
import yt_dlp
import pygame
import threading
import time
import shutil
import re
from datetime import datetime
from collections import deque

from flask import Flask, request, jsonify
from flask_cors import CORS

# ╔═══════════════════════════════════════════════════════════╗
# ║                    CONFIGURATION                          ║
# ║          CHANGE THESE VALUES TO MATCH YOUR SETUP          ║
# ╚═══════════════════════════════════════════════════════════╝

# SERVER — The IP and port the server listens on
HOST = "0.0.0.0"
PORT = 5000
DEBUG = False

# SECURITY — Must match the apiKey in your Lua script
API_KEY = "YOUR_API_KEY_HERE"

# MAIN ACCOUNT — Your Roblox username (must match Lua config)
MAIN_ACCOUNT = "YOUR_ROBLOX_USERNAME"

# RATE LIMITING
RATE_LIMIT_SECONDS = 10
GLOBAL_COOLDOWN = 3

# MUSIC
MAX_QUEUE_SIZE = 50
MAX_SONG_DURATION = 600
AUDIO_QUALITY = "128"
MAX_CONCURRENT_DOWNLOADS = 2
DUPLICATE_COOLDOWN = 30

# STORAGE
STORAGE_DIR = "storage"
CACHE_DIR = os.path.join(STORAGE_DIR, "cache")

# AUTO-CLEANUP
CLEANUP_HOURS = 24

# ═══════════════════════════════════════════════════════════
#  END OF CONFIGURATION — Do not edit below this line
# ═══════════════════════════════════════════════════════════

def log(level, message, **kwargs):
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    extra = " ".join([f"{k}={v}" for k, v in kwargs.items()])
    print(f"[{timestamp}] [{level}] {message} {extra}")

app = Flask(__name__)
CORS(app)

try:
    pygame.mixer.pre_init(frequency=44100, size=-16, channels=2, buffer=4096)
    pygame.mixer.init()
    log("INFO", "Mixer initialized", freq=44100, buffer=4096)
except Exception as e:
    print(f"[ERROR] Failed to initialize pygame mixer: {e}")
    exit(1)

os.makedirs(CACHE_DIR, exist_ok=True)

queue_lock = threading.RLock()
music_queue = deque()

current_song = None
is_paused = False
volume = 0.7

user_stats = {}
play_history = deque(maxlen=20)

authorized_users = set()
blacklisted_users = set()

last_request_time = {}

download_semaphore = threading.Semaphore(MAX_CONCURRENT_DOWNLOADS)

shutdown_flag = False

playback_start_time = 0.0
playback_start_pos = 0.0
playback_paused_at = 0.0
sync_lock = threading.Lock()


def verify_api_key():
    key = request.headers.get("X-API-Key")
    if not key or key != API_KEY:
        return False
    return True

def check_rate_limit(username, limit_seconds):
    now = time.time()
    if username in last_request_time:
        elapsed = now - last_request_time[username]
        if elapsed < limit_seconds:
            return False, int(limit_seconds - elapsed)
    last_request_time[username] = now
    return True, 0

def get_user_stats(username):
    if username not in user_stats:
        user_stats[username] = {
            "plays": 0,
            "skips": 0,
            "last_play": 0
        }
    return user_stats[username]

def update_user_stats(username, action):
    stats = get_user_stats(username)
    if action == "play":
        stats["plays"] += 1
        stats["last_play"] = time.time()
    elif action == "skip":
        stats["skips"] += 1

def is_duplicate(title, video_id):
    with queue_lock:
        if current_song and video_id == current_song.get("video_id"):
            return True, "already_playing"
        for song in music_queue:
            if video_id == song.get("video_id"):
                return True, "in_queue"
    return False, None

def download_music(query, username):
    with download_semaphore:
        user_folder = os.path.join(STORAGE_DIR, username)
        os.makedirs(user_folder, exist_ok=True)

        ydl_opts = {
            "format": "bestaudio/best",
            "outtmpl": f"{CACHE_DIR}/%(id)s.%(ext)s",
            "noplaylist": True,
            "quiet": not DEBUG,
            "no_warnings": True,
            "socket_timeout": 30,
            "postprocessors": [{
                "key": "FFmpegExtractAudio",
                "preferredcodec": "mp3",
                "preferredquality": AUDIO_QUALITY,
            }],
        }

        try:
            with yt_dlp.YoutubeDL(ydl_opts) as ydl:
                info = ydl.extract_info(f"ytsearch1:{query}", download=False)

                if not info or "entries" not in info or not info["entries"]:
                    log("WARN", "No results found", query=query)
                    return None, None, None, "not_found"

                video = info["entries"][0]
                video_id = video["id"]
                video_title = video["title"]
                duration = video.get("duration", 0)

                if duration > MAX_SONG_DURATION:
                    log("WARN", "Song too long", title=video_title, duration=duration)
                    return None, None, None, "too_long"

                dup, dup_reason = is_duplicate(video_title, video_id)
                if dup:
                    log("INFO", "Duplicate detected", title=video_title, reason=dup_reason)
                    return None, None, None, dup_reason

                cache_path = os.path.join(CACHE_DIR, f"{video_id}.mp3")

                if not os.path.exists(cache_path):
                    log("INFO", "Downloading", title=video_title, video_id=video_id)
                    ydl.download([f"https://www.youtube.com/watch?v={video_id}"])

                    for _ in range(30):
                        if os.path.exists(cache_path):
                            break
                        time.sleep(1)
                    else:
                        raise TimeoutError("Conversion timeout")
                else:
                    log("INFO", "Using cache", title=video_title, video_id=video_id)

                clean_title = re.sub(r'[^\w\s.-]', '', video_title)[:100]
                timestamp = int(time.time())
                dest_path = os.path.join(user_folder, f"{clean_title}_{timestamp}.mp3")

                shutil.copy2(cache_path, dest_path)

                log("INFO", "Download complete", title=video_title, path=dest_path)
                return video_title, video_id, dest_path, duration

        except yt_dlp.utils.DownloadError as e:
            log("ERROR", "Download failed", query=query, error=str(e))
            return None, None, None, "download_error"
        except Exception as e:
            log("ERROR", "Unexpected error", query=query, error=str(e))
            return None, None, None, "error"

def music_worker():
    global current_song, is_paused, shutdown_flag
    global playback_start_time, playback_start_pos, playback_paused_at

    log("INFO", "Music worker started")

    while not shutdown_flag:
        try:
            song = None

            with queue_lock:
                if not pygame.mixer.music.get_busy() and not is_paused and music_queue:
                    song = music_queue.popleft()

            if song:
                current_song = song
                file_path = song["path"]

                try:
                    pygame.mixer.music.load(file_path)
                    pygame.mixer.music.set_volume(volume)
                    pygame.mixer.music.play()

                    with sync_lock:
                        playback_start_time = time.time()
                        playback_start_pos = 0.0
                        playback_paused_at = 0.0

                    log("INFO", "Now playing", title=song["title"], user=song["username"])

                    sync_check_counter = 0
                    while (pygame.mixer.music.get_busy() or is_paused) and not shutdown_flag:
                        time.sleep(0.5)
                        sync_check_counter += 1

                        if sync_check_counter % 10 == 0 and not is_paused and pygame.mixer.music.get_busy():
                            try:
                                with sync_lock:
                                    expected_pos = (time.time() - playback_start_time) + playback_start_pos
                                actual_pos = pygame.mixer.music.get_pos() / 1000.0

                                if actual_pos > 0:
                                    drift = abs(expected_pos - actual_pos)
                                    if drift > 0.5:
                                        log("WARN", "Audio drift detected, re-syncing",
                                            expected=f"{expected_pos:.2f}s",
                                            actual=f"{actual_pos:.2f}s",
                                            drift=f"{drift:.2f}s")
                                        pygame.mixer.music.play(start=expected_pos)
                                        with sync_lock:
                                            playback_start_time = time.time()
                                            playback_start_pos = expected_pos
                                        log("INFO", "Re-synced to", position=f"{expected_pos:.2f}s")
                            except Exception:
                                pass

                    if not shutdown_flag:
                        play_history.append(song)
                        update_user_stats(song["username"], "play")

                        with sync_lock:
                            playback_start_time = 0.0
                            playback_start_pos = 0.0

                        try:
                            pygame.mixer.music.unload()
                            if os.path.exists(file_path):
                                os.remove(file_path)
                                log("INFO", "File cleaned", path=file_path)
                        except Exception as e:
                            log("WARN", "Cleanup failed", path=file_path, error=str(e))

                        log("INFO", "Song finished", title=song["title"])

                except Exception as e:
                    log("ERROR", "Playback error", title=song["title"], error=str(e))

                finally:
                    current_song = None

            else:
                time.sleep(1)

        except Exception as e:
            log("ERROR", "Worker error", error=str(e))
            time.sleep(5)

    log("INFO", "Music worker stopped")

worker_thread = threading.Thread(target=music_worker, daemon=True)
worker_thread.start()

def cleanup_old_files():
    while not shutdown_flag:
        try:
            time.sleep(3600)
            cutoff = time.time() - (CLEANUP_HOURS * 3600)
            cleaned = 0
            for root, dirs, files in os.walk(STORAGE_DIR):
                for file in files:
                    if file.endswith(".mp3"):
                        filepath = os.path.join(root, file)
                        if os.path.getmtime(filepath) < cutoff:
                            os.remove(filepath)
                            cleaned += 1
            if cleaned > 0:
                log("INFO", "Cleanup complete", files_removed=cleaned)
        except Exception as e:
            log("ERROR", "Cleanup failed", error=str(e))

cleanup_thread = threading.Thread(target=cleanup_old_files, daemon=True)
cleanup_thread.start()

# ═══════════════════════════════════════════════════════════
#  API ROUTES
# ═══════════════════════════════════════════════════════════

@app.before_request
def before_request():
    if request.path != "/" and not verify_api_key():
        return jsonify({"error": "Invalid or missing API key"}), 401

@app.route("/")
def root():
    return jsonify({
        "status": "online",
        "version": "2.1",
        "queue_size": len(music_queue),
        "playing": current_song is not None
    })

@app.route("/play")
def api_play():
    query = request.args.get("query", "").strip()
    username = request.args.get("user", "unknown").strip()

    if username.lower() in blacklisted_users:
        return jsonify({"error": "You are blacklisted"}), 403

    if len(query) < 2:
        return jsonify({"error": "Query too short (min 2 characters)"}), 400

    if len(query) > 500:
        return jsonify({"error": "Query too long (max 500 characters)"}), 400

    allowed, wait_time = check_rate_limit(username, RATE_LIMIT_SECONDS)
    if not allowed:
        return jsonify({
            "error": f"Rate limit exceeded. Wait {wait_time} seconds",
            "wait_seconds": wait_time
        }), 429

    with queue_lock:
        if len(music_queue) >= MAX_QUEUE_SIZE:
            return jsonify({"error": f"Queue is full ({MAX_QUEUE_SIZE} songs max)"}), 400

    download_result = {"done": False, "title": None, "error": None, "position": 0}

    def background_download():
        title, video_id, path, error = download_music(query, username)

        if error == "already_playing":
            download_result["error"] = "already_playing"
            download_result["done"] = True
            log("INFO", "Blocked: already playing", query=query, user=username)
            return

        if error == "in_queue":
            download_result["error"] = "in_queue"
            download_result["done"] = True
            log("INFO", "Blocked: already in queue", query=query, user=username)
            return

        if title and path:
            with queue_lock:
                position = len(music_queue) + 1
                music_queue.append({
                    "title": title,
                    "video_id": video_id,
                    "path": path,
                    "username": username,
                    "added_at": time.time()
                })
                download_result["position"] = position
                download_result["title"] = title
            log("INFO", "Added to queue", title=title, position=position, user=username)
        else:
            download_result["error"] = error or "unknown"
            log("ERROR", "Failed to add", query=query, user=username, error=error)

        download_result["done"] = True

    dl_thread = threading.Thread(target=background_download, daemon=True)
    dl_thread.start()

    dl_thread.join(timeout=3.0)

    if download_result["done"]:
        if download_result["error"] == "already_playing":
            return jsonify({"error": "That song is already playing!", "reason": "already_playing"}), 400
        elif download_result["error"] == "in_queue":
            return jsonify({"error": "That song is already in the queue!", "reason": "in_queue"}), 400
        elif download_result["error"]:
            error_messages = {
                "not_found": "No results found for that search",
                "too_long": f"Song exceeds {MAX_SONG_DURATION // 60} minute limit",
                "download_error": "Failed to download song",
            }
            msg = error_messages.get(download_result["error"], "Something went wrong")
            return jsonify({"error": msg, "reason": download_result["error"]}), 400
        else:
            with queue_lock:
                position = len(music_queue) + (1 if current_song else 0)
            return jsonify({
                "status": "queued",
                "title": download_result["title"],
                "query": query,
                "queue_position": position,
                "message": "Song added to queue"
            })
    else:
        with queue_lock:
            position = len(music_queue) + (1 if current_song else 0) + 1

        return jsonify({
            "status": "queued",
            "query": query,
            "queue_position": position,
            "message": "Song is being downloaded"
        })

@app.route("/control")
def api_control():
    global is_paused, current_song, volume
    global playback_start_time, playback_start_pos, playback_paused_at

    action = request.args.get("action", "").lower()
    username = request.args.get("user", "unknown").strip()

    if username.lower() != MAIN_ACCOUNT.lower() and username.lower() not in authorized_users:
        return jsonify({"error": "Not authorized", "authorized": False}), 403

    if action == "pause":
        if not is_paused:
            with sync_lock:
                playback_paused_at = (time.time() - playback_start_time) + playback_start_pos
            pygame.mixer.music.pause()
            is_paused = True
            log("INFO", "Paused", user=username, position=f"{playback_paused_at:.2f}s")
        return jsonify({"status": "paused", "authorized": True})

    elif action == "resume" or action == "unpause":
        if is_paused:
            pygame.mixer.music.unpause()
            with sync_lock:
                playback_start_time = time.time()
                playback_start_pos = playback_paused_at
            is_paused = False
            log("INFO", "Resumed", user=username, position=f"{playback_paused_at:.2f}s")
        return jsonify({"status": "resumed", "authorized": True})

    elif action == "skip":
        if current_song:
            skipped_username = current_song.get("username", "unknown")
            update_user_stats(skipped_username, "skip")
            pygame.mixer.music.stop()
            with sync_lock:
                playback_start_time = 0.0
                playback_start_pos = 0.0
            log("INFO", "Skipped", title=current_song["title"], by=username)
        return jsonify({"status": "skipped", "authorized": True})

    elif action == "stop":
        pygame.mixer.music.stop()
        is_paused = False
        with sync_lock:
            playback_start_time = 0.0
            playback_start_pos = 0.0
        with queue_lock:
            music_queue.clear()
        current_song = None
        log("INFO", "Stopped and cleared queue", by=username)
        return jsonify({"status": "stopped", "authorized": True})

    elif action == "volume":
        try:
            vol = float(request.args.get("value", volume))
            volume = max(0.0, min(1.0, vol))
            pygame.mixer.music.set_volume(volume)
            log("INFO", "Volume changed", volume=volume, by=username)
            return jsonify({"status": "ok", "volume": volume, "authorized": True})
        except ValueError:
            return jsonify({"error": "Invalid volume value (0.0-1.0)"}), 400

    else:
        return jsonify({"error": "Invalid action"}), 400

@app.route("/admin/authorize")
def api_authorize():
    username = request.args.get("user", "").strip()
    if not username:
        return jsonify({"error": "Username required"}), 400
    authorized_users.add(username.lower())
    log("INFO", "User authorized", username=username)
    return jsonify({
        "status": "authorized",
        "username": username,
        "authorized_users": list(authorized_users)
    })

@app.route("/admin/revoke")
def api_revoke():
    username = request.args.get("user", "").strip()
    if not username:
        return jsonify({"error": "Username required"}), 400
    authorized_users.discard(username.lower())
    log("INFO", "User revoked", username=username)
    return jsonify({
        "status": "revoked",
        "username": username,
        "authorized_users": list(authorized_users)
    })

@app.route("/admin/blacklist")
def api_blacklist():
    username = request.args.get("user", "").strip()
    if not username:
        return jsonify({"error": "Username required"}), 400
    blacklisted_users.add(username.lower())
    log("INFO", "User blacklisted", username=username)
    return jsonify({
        "status": "blacklisted",
        "username": username,
        "blacklisted_users": list(blacklisted_users)
    })

@app.route("/admin/unblacklist")
def api_unblacklist():
    username = request.args.get("user", "").strip()
    if not username:
        return jsonify({"error": "Username required"}), 400
    blacklisted_users.discard(username.lower())
    log("INFO", "User unblacklisted", username=username)
    return jsonify({
        "status": "unblacklisted",
        "username": username,
        "blacklisted_users": list(blacklisted_users)
    })

@app.route("/admin/check")
def api_check_auth():
    username = request.args.get("user", "").strip()
    if not username:
        return jsonify({"error": "Username required"}), 400
    is_main = username.lower() == MAIN_ACCOUNT.lower()
    is_authorized = username.lower() in authorized_users
    return jsonify({
        "username": username,
        "is_main_account": is_main,
        "is_authorized": is_authorized or is_main,
        "is_blacklisted": username.lower() in blacklisted_users
    })

@app.route("/admin/list")
def api_list_authorized():
    return jsonify({
        "main_account": MAIN_ACCOUNT,
        "authorized_users": list(authorized_users),
        "blacklisted_users": list(blacklisted_users),
        "total_authorized": len(authorized_users) + 1
    })

@app.route("/status")
def api_status():
    with queue_lock:
        queue_list = [
            {
                "title": song["title"],
                "username": song["username"],
                "position": i + 1
            }
            for i, song in enumerate(music_queue)
        ]

    return jsonify({
        "current_song": {
            "title": current_song["title"],
            "username": current_song["username"],
            "video_id": current_song.get("video_id")
        } if current_song else None,
        "is_playing": pygame.mixer.music.get_busy(),
        "is_paused": is_paused,
        "volume": volume,
        "playback_position": round((time.time() - playback_start_time) + playback_start_pos, 2) if current_song and playback_start_time > 0 else 0,
        "queue": queue_list[:10],
        "queue_size": len(music_queue)
    })

@app.route("/nowplaying")
def api_nowplaying():
    if not current_song:
        return jsonify({"playing": False, "title": None})

    with sync_lock:
        if is_paused:
            pos = playback_paused_at
        elif playback_start_time > 0:
            pos = (time.time() - playback_start_time) + playback_start_pos
        else:
            pos = 0

    return jsonify({
        "playing": True,
        "title": current_song["title"],
        "username": current_song["username"],
        "video_id": current_song.get("video_id"),
        "position": round(pos, 2),
        "volume": volume,
        "is_paused": is_paused,
        "queue_size": len(music_queue)
    })

@app.route("/queue")
def api_queue():
    with queue_lock:
        queue_list = [
            {
                "title": song["title"],
                "username": song["username"],
                "video_id": song.get("video_id"),
                "position": i + 1
            }
            for i, song in enumerate(music_queue)
        ]

    return jsonify({
        "queue": queue_list,
        "total": len(queue_list)
    })

@app.route("/stats")
def api_stats():
    username = request.args.get("user", "").strip()
    if not username:
        return jsonify(user_stats)
    stats = get_user_stats(username)
    return jsonify({
        "username": username,
        "songs_played": stats["plays"],
        "songs_skipped": stats["skips"],
        "last_play": stats["last_play"]
    })

@app.route("/history")
def api_history():
    return jsonify({
        "history": [
            {
                "title": song["title"],
                "username": song["username"],
                "video_id": song.get("video_id")
            }
            for song in list(play_history)
        ]
    })

@app.errorhandler(404)
def not_found(e):
    return jsonify({"error": "Endpoint not found"}), 404

@app.route("/sync")
def api_sync():
    if not current_song or not pygame.mixer.music.get_busy():
        return jsonify({
            "synced": False,
            "position": 0,
            "title": None
        })

    with sync_lock:
        if is_paused:
            pos = playback_paused_at
        elif playback_start_time > 0:
            pos = (time.time() - playback_start_time) + playback_start_pos
        else:
            pos = 0

    return jsonify({
        "synced": True,
        "position": round(pos, 3),
        "title": current_song["title"] if current_song else None,
        "volume": volume,
        "is_paused": is_paused,
        "server_time": time.time()
    })

@app.errorhandler(500)
def internal_error(e):
    log("ERROR", "Internal server error", error=str(e))
    return jsonify({"error": "Internal server error"}), 500

if __name__ == "__main__":
    log("INFO", "Starting Hyperion Music Bot Server v2.1")
    log("INFO", "Server config", host=HOST, port=PORT, debug=DEBUG)

    try:
        app.run(
            host=HOST,
            port=PORT,
            debug=DEBUG,
            threaded=True,
            use_reloader=False
        )
    except KeyboardInterrupt:
        log("INFO", "Shutting down...")
        shutdown_flag = True
        pygame.mixer.music.stop()
        log("INFO", "Server stopped")
