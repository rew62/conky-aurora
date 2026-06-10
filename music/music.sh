#!/bin/bash
# Loads all Music Conky/Lua Scripts
# v1 01 2026-03-09 @rew62
# 
cd "$(dirname "$0")" || exit

#DEBUG
#start() {
#    setsid bash nowplaying/start.sh &
#    setsid bash eq/start.sh &
#    setsid bash lyrics/start-lyrics-conky.sh &
#}

start() {
    setsid bash nowplaying/start.sh > /dev/null 2>&1 &
    (cd eq && setsid conky -c eq.rc > /dev/null 2>&1 &)
    setsid bash lyrics/start-lyrics-conky.sh > /dev/null 2>&1 &
}

stop() {
    pkill -f "nowplaying.rc"
    pkill -f "eq.rc"
    # lyrics manages its own cleanup via TERM signal
    pkill -f "start-lyrics-conky.sh"
    pkill -f "active-player.sh"
    pkill -f "lyrics.conky"
}

case "$1" in
    start)   start ;;
    stop)    stop ;;
    restart) stop; sleep 2; start ;;
    *)       echo "Usage: $0 {start|stop|restart}" ; exit 1 ;;
esac

exit 0
