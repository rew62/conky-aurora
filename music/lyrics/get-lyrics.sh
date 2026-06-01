#!/bin/bash
# get-lyrics.sh — fetches synced lyrics from local cache, NetEase, or LRCLIB.
# All temp files live in /dev/shm to avoid disk I/O.
# v1 01 2026-03-09 @rew62

BASEDIR="$(cd "$(dirname "$0")" && pwd)"
TMP="/dev/shm/conky-lyrics"
mkdir -p "$TMP"

txtfile="$TMP/lyrics.txt"
outfile="$TMP/lyrics.out"
chkfile="$TMP/lyrics.chk"
jqfile="$TMP/lyrics.jq"
inst_helper="$BASEDIR/instrumental_lrclib.sh"

LOCAL_LYRICS_DIR="$HOME/lyrics"

# wget timeout (seconds) — prevents the startup hang when network is slow/unavailable
WGET_TIMEOUT=8
WGET_TRIES=1

sendmsg() {
    printf '\n${color 888888}Get-lyrics: ${color FF0000} %s' "$1" > "$outfile"
    printf 'Get-lyrics: %s\n' "$1" >&2
}

arg1="$1"
[ -z "$arg1" ] && exit 0
save_lyrics="$2"   # "--save" for local files, empty for streams

artist="${arg1%%|*}"; rest="${arg1#*|}"; title="${rest%%|*}"; album="${rest#*|}"

current="$artist|$title|$album"
last_checked=""
[ -f "$chkfile" ] && last_checked=$(cat "$chkfile")

if [ "$current" != "$last_checked" ]; then
    echo "$current" > "$chkfile"
fi

###################################################################
# Helper: save to local cache
###################################################################
save_to_cache() {
    [ "$save_lyrics" = "--save" ] || return
    [ -d "$LOCAL_LYRICS_DIR" ] || return
    local cache_file="$LOCAL_LYRICS_DIR/${artist} - ${title}.lrc"
    cp "$txtfile" "$cache_file" 2>/dev/null
}

###################################################################
# 1. Local cache
###################################################################
search_local() {
    [ -d "$LOCAL_LYRICS_DIR" ] || return 1

    local local_file="$LOCAL_LYRICS_DIR/${artist} - ${title}.lrc"
    if [ -f "$local_file" ]; then
        cp "$local_file" "$txtfile"
        sendmsg "Lyrics from local cache"
        return 0
    fi

    local found_file
    # Case-insensitive glob via find — try artist+title, then title alone
    found_file=$(find "$LOCAL_LYRICS_DIR" -type f -name "*.lrc" \
        -iname "*${artist}*${title}*" 2>/dev/null | head -n1)
    if [ -z "$found_file" ]; then
        found_file=$(find "$LOCAL_LYRICS_DIR" -type f -name "*.lrc" \
            -iname "*${title}*" 2>/dev/null | head -n1)
    fi

    if [ -n "$found_file" ]; then
        cp "$found_file" "$txtfile"
        sendmsg "Local cache (fuzzy: $(basename "$found_file"))"
        return 0
    fi

    return 1
}

###################################################################
# 2. NetEase
###################################################################
fetch_netease() {
    local query
    query=$(printf '%s %s' "$artist" "$title" | sed 's/ /%20/g')
    local search_url="https://music.163.com/api/cloudsearch/pc?type=1&limit=1&s=${query}"

    wget -q --timeout="$WGET_TIMEOUT" --tries="$WGET_TRIES" -O "$jqfile" "$search_url" || return 1

    local song_id
    song_id=$(jq -r '.result.songs[0].id // empty' "$jqfile") || return 1
    [ -z "$song_id" ] && return 1

    local lyric_url="https://music.163.com/api/song/lyric?id=${song_id}&lv=1&tv=0"
    wget -q --timeout="$WGET_TIMEOUT" --tries="$WGET_TRIES" -O "$jqfile" "$lyric_url" || return 1

    local lyrics
    lyrics=$(jq -r '.lrc.lyric // empty' "$jqfile")
    [ -z "$lyrics" ] && return 1

    printf 'Artist: %s\nTitle : %s\nAlbum : %s\n\n' "$artist" "$title" "$album" > "$txtfile"
    printf '%s\n' "$lyrics" >> "$txtfile"
    sendmsg "Lyrics via NetEase"
    save_to_cache
    return 0
}

###################################################################
# 3. LRCLIB
###################################################################
fetch_lrclib() {
    local urlartist urltitle urlalbum
    urlartist=$(sed 's/[][{}() _~,]/+/g' <<<"$artist")
    urltitle=$(sed 's/[][{}() _~,]/+/g' <<<"$title")
    urlalbum=$(sed 's/[][{}() _~,]/+/g' <<<"$album")

    local url="https://lrclib.net/api/get?artist_name=${urlartist}&track_name=${urltitle}&album_name=${urlalbum}"

    wget -q --timeout="$WGET_TIMEOUT" --tries="$WGET_TRIES" -O "$jqfile" "$url" || return 1

    local lyrics
    lyrics=$(jq -r '.syncedLyrics // empty' "$jqfile")

    if [ -n "$lyrics" ]; then
        printf 'Artist: %s\nTitle : %s\nAlbum : %s\n\n' "$artist" "$title" "$album" > "$txtfile"
        printf '%s\n' "$lyrics" >> "$txtfile"
        sendmsg "Lyrics via LRCLIB"
        save_to_cache
        return 0
    fi

    # Check instrumental via helper
    if [ -x "$inst_helper" ] && "$inst_helper" "$jqfile"; then
        printf 'Artist: %s\nTitle : %s\nAlbum : %s\n\n' "$artist" "$title" "$album" > "$txtfile"
        printf '[00:00.00]Instrumental\n' >> "$txtfile"
        sendmsg "Instrumental (LRCLIB)"
        return 0
    fi

    return 1
}

###################################################################
# MAIN
###################################################################
search_local || fetch_netease || fetch_lrclib || sendmsg "No lyrics found"
