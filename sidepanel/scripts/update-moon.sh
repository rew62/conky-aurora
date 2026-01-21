#!/usr/bin/bash
# Script to get Moon Illumination from moongiant, calculate phase, and get Moon image from NASA.
# v2.9 2026-01-19 @rew62

OUTPUT_DIR="/dev/shm"
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"
CACHE_DIR="$(dirname "$SCRIPT_DIR")/.cache"
NOW=$(date "+%Y-%m-%d %H:%M:%S")
THRESHOLD_MINS=29 

# Ensure the .cache directory exists (Safety check)
mkdir -p "$CACHE_DIR"

# Check if file exists in /dev/shm and is recent
if [ -f "$OUTPUT_DIR/moon-data.txt" ]; then
    FILE_TIME=$(stat -c %Y "$OUTPUT_DIR/moon-data.txt")
    CURRENT_TIME=$(date +%s)
    AGE=$((CURRENT_TIME - FILE_TIME))
    THRESHOLD_SECS=$((THRESHOLD_MINS * 60))

    if [ "$AGE" -lt "$THRESHOLD_SECS" ]; then
	#echo "[$NOW] Image is $((AGE / 60)) minutes old. Theshold is $THRESHOLD_MINS minutes. Skipping download."
        exit 0
    fi
fi

# Check if the data exists in RAM. If not, try to restore from a backup
if [ ! -f "$OUTPUT_DIR/moon-data.txt" ] && [ -f "$CACHE_DIR/moon-data.bak" ]; then
    cp "$CACHE_DIR/moon-data.bak" "$OUTPUT_DIR/moon-data.txt"
    cp "$CACHE_DIR/moon.jpg.bak" "$OUTPUT_DIR/moon.jpg" 2>/dev/null
fi

# INITIALIZE: This stops the "No such file" error instantly
if [ ! -f "${OUTPUT_DIR}/moon-data.txt" ]; then
    echo "\${alignr}\${color4}Initializing..." > "${OUTPUT_DIR}/moon-data.txt"
fi

ERR_FILE="$OUTPUT_DIR/net_error"
UA="Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36"
ERR=0

# --- 1. Fetch Moon Phase Text ---
wget -q -T 10 -t 2 -O "${OUTPUT_DIR}/raw" --user-agent="$UA" "http://www.moongiant.com/phase/today"

if [ $? -eq 0 ] && [ -s "${OUTPUT_DIR}/raw" ]; then
    sed -i -e '/^ *$/d; s/^ *//g; /Illumination/!d; s/<br>/\n/g; s|<[^>]*>||g' "${OUTPUT_DIR}/raw"
    sed -i '2,3!d' "${OUTPUT_DIR}/raw"
    sed -i '1s/^/Phase: /' "${OUTPUT_DIR}/raw"


    REF_DATE="2024-12-30 22:27:00 UTC"
    REF_EPOCH=$(date -d "$REF_DATE" +%s)
    SYNODIC_SECONDS=2551443
    NOW_EPOCH=$(date +%s)
    SECONDS_SINCE_REF=$(( (NOW_EPOCH - REF_EPOCH) % SYNODIC_SECONDS ))
    
    # Calculate next Full Moon
    FULL_MOON_SECONDS=$(( SYNODIC_SECONDS / 2 ))
    SECONDS_TO_FULL=$(( (FULL_MOON_SECONDS - SECONDS_SINCE_REF + SYNODIC_SECONDS) % SYNODIC_SECONDS ))
    FULL_EPOCH=$((NOW_EPOCH + SECONDS_TO_FULL))
    
    # Calculate next New Moon
    SECONDS_TO_NEW=$(( (SYNODIC_SECONDS - SECONDS_SINCE_REF) % SYNODIC_SECONDS ))
    NEW_EPOCH=$((NOW_EPOCH + SECONDS_TO_NEW))
    
    # Convert to human-readable format
    NEXT_FULL=$(date -d "@$FULL_EPOCH" "+%b %d, %Y")
    NEXT_NEW=$(date -d "@$NEW_EPOCH" "+%b %d, %Y")
    
    # Append dates to raw file in chronological order
    if [ "$FULL_EPOCH" -lt "$NEW_EPOCH" ]; then
        echo "Next Full Moon: $NEXT_FULL" >> "${OUTPUT_DIR}/raw"
        echo "Next New Moon: $NEXT_NEW" >> "${OUTPUT_DIR}/raw"
    else
        echo "Next New Moon: $NEXT_NEW" >> "${OUTPUT_DIR}/raw"
        echo "Next Full Moon: $NEXT_FULL" >> "${OUTPUT_DIR}/raw"
    fi 
else
    ERR=1
fi

# --- 2. Fetch Moon Image ---
wget -q -T 10 -t 2 -O "${OUTPUT_DIR}/moon_icon_url_tmp" "https://moon.nasa.gov/moon-observation/daily-moon-guide/"

if [ $? -eq 0 ] && [ -s "${OUTPUT_DIR}/moon_icon_url_tmp" ]; then
    now_ico="$(LANG=en_us_88591 date +'%d %b %Y')"
    img_icon=$(grep -Eio "${now_ico}.{0,428}" "${OUTPUT_DIR}/moon_icon_url_tmp" | \
               sed "s/&quot;/ /g; s/, /\n/g" | \
               sed -e "2,13d; s/image_src ://g; s/^ *//g; s/\.jpg.*/.jpg/" | sed -n 2p)

    if [ -n "$img_icon" ]; then
        wget -q -T 15 -t 2 -O "${OUTPUT_DIR}/moon_new.jpg" "https://moon.nasa.gov/$img_icon"
        if [ -f "${OUTPUT_DIR}/moon_new.jpg" ] && [ $(stat -c%s "${OUTPUT_DIR}/moon_new.jpg") -gt 1024 ]; then
            mv "${OUTPUT_DIR}/moon_new.jpg" "${OUTPUT_DIR}/moon.jpg"
        else
            ERR=1
        fi
    else
        ERR=1
    fi
else
    ERR=1
fi

# --- 3. Status Logic ---
[ "$ERR" -eq 1 ] && touch "$ERR_FILE" || rm -f "$ERR_FILE"

# --- 4. Generate Conky Snippet ---
if [ -f "${OUTPUT_DIR}/raw" ]; then
    PHASE=$(sed -n '1p' "${OUTPUT_DIR}/raw" | sed 's/^[^:]*: //')
    ILLUM=$(sed -n '2p' "${OUTPUT_DIR}/raw" | sed 's/^[^:]*: //')
    LINE3=$(sed -n '3p' "${OUTPUT_DIR}/raw")
    LINE4=$(sed -n '4p' "${OUTPUT_DIR}/raw")
    
    F_HEAD="\${font Fira Code:size=10}"
    F_DATA="\${font Ubuntu Mono:size=10}"
    
    {
        echo "$F_HEAD\${color4}\${alignr}$PHASE - $ILLUM\${font}"
        echo "\${alignr}\${color1}$F_HEAD${LINE3%%:*}:\${font}"
        echo "\${voffset -5}\${alignr}\${color4}$F_DATA${LINE3#*: }\${font}"
        echo "\${alignr}\${color1}$F_HEAD${LINE4%%:*}:\${font}"
        echo "\${voffset -5}\${alignr}\${color4}$F_DATA${LINE4#*: }\${font}"
    } > "${OUTPUT_DIR}/moon-data.txt"
fi


# Save a backup to disk for the next reboot
cp "${OUTPUT_DIR}/moon-data.txt" "$CACHE_DIR/moon-data.bak"
cp "${OUTPUT_DIR}/moon.jpg" "$CACHE_DIR/moon.jpg.bak" 2>/dev/null


# Clean temporary processing files only
for tmp in "raw" "moon_icon_url_tmp"; do rm -f "${OUTPUT_DIR}/$tmp"; done
