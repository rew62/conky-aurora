![License](https://img.shields.io/github/license/rew62/conky-aurora)
![Stars](https://img.shields.io/github/stars/rew62/conky-aurora)
![Issues](https://img.shields.io/github/issues/rew62/conky-aurora)
![Last Commit](https://img.shields.io/github/last-commit/rew62/conky-aurora)

# Aurora 2.0 - A Conky Scripts Collection

![Screenshot](Screenshot.png)

A set of Conky scripts built on Linux Mint v22.2 (Zara), and v22.3 (Zena)

## Credits

- **allcombined.lua** - created by mrpeachy
- **background.lua, loadall.lua, lua3-bars.lua, and image.lua** - created by @wim66.
- **All other scripts** - created by @rew62

▶️  **TL;DR - Run the configuation script!**

## Scripts Overview

1. **calendar/calendar.rc** - Calendar with unicode formatted list from gcalcli agenda
2. **earth/fourmilab.sh** - Earth viewer script using fourmilab.ch
3. **sidepanel/sidepanel-1.rc** - Sidepanel with Sun and Moon
4. **sidepanel/sidepanel-2.rc** - Sidepanel with System, CPU, Memory, and Network information
5. **calendar2/sidepanel-calendar.rc** - Stand Alone Calendar with 'normal' window allowing for 'Alt + mouse' moves. Note: To make move persistent, edit .rc file.
6. **earth/earth.rc** - Stand Alone Earth viewer from the perspective of the Sun.
7. **moon/moon.rc** - Stand Alone moon viewer with tilt based on Lat/Lon.
8. **music/music.sh** - Shell script that starts now playing, eq, and lyrics scripts in the sub directories.
9.  **music/nowplaying** - Scripts that read playerctl for current song info, and also display system volume.
10. **music/lyrics** - Lyrics scripts
11. **music/eq** - Cava Audio Visualizer scripts.
12. **system/system.rc** - Stand Alone system monitor.
13. **network/network.rc** - Stand Alone network monitor script.

## About fourmilab.ch

The [fourmilab.ch](http://www.fourmilab.ch) site was developed by John Walker, founder of Autodesk, Inc. and co-author of AutoCAD. John passed away in 2024. The site offers various content including an Earth/Moon viewer with many selectable configuartion parameters. This script uses a view of the Earth from the Sun's perspective, however, you may customize this on the fourmilab site.

**Permission from Webmaster at fourmilab.ch:** Permission is granted without warranty, endorsement, or ongoing obligation on my part, and does not imply that I have reviewed, approved, or support the scripts themselves.

## Important Notes

### /dev/shm Usage

Verify that `/dev/shm` is available on your system. `/dev/shm` is a virtual filesystem (tmpfs) that resides in RAM; using it for temporary files improves performance and reduces wear on your SSD. Most modern Linux distributions including Arch, Debian, and derivatives like Ubuntu and Mint—mount `/dev/shm` by default.

To check if it is mounted, you can run: `df -h /dev/shm`

## Installation & Setup

### 1. Install Required Packages
```bash
# Install Conky
sudo apt install conky-all

# Install Lua
sudo apt install lua5.4 liblua5.4-dev

# Install Fonts
sudo apt install fonts-symbola
sudo apt install fonts-firacode

# Install gcalcli
sudo apt install gcalcli

# Install gawk
sudo apt install gawk
```

Additionally fourmilab.sh utilizes the convert command from ImageMagick which is installed by default on Linix Mint. Install ImageMagick if convert is not available.


### 2. Install Fonts

Install the fonts located in the `fonts` directory.

### 3. Get OpenWeatherMap API Key

1. Get an API key from [openweathermap.org](http://www.openweathermap.org)
   You will need:
      - Your API key
      - Your city ID
      - Your measurement units: `'metric'` (Celsius, m/s) or `'imperial'` (Fahrenheit, mph)


### 4. 🔑 ▶️ Run `config.sh` The configuration script will walk you through everthing you need including creating .env file with your keys, checking for fonts, and checking lyrics script dependencies.

```bash
./config.sh
```
The configuration script will walk you through everthing you need including creating .env file with your keys, checking for fonts, and checking lyrics script dependencies.

### 5. Set up cron job to generate an Image of the Earth every 10 mintes.

1. Check `earth/crontab` to verifiy the correct directory path to the fourmilab-earth.sh shell script.
   ```
   cat earth/crontab
   ```
2. Install the crontab:
   ```bash
   crontab < earth/crontab
   ```
3. Verify installation:
      `crontab -l`

### 6. Set Up gcalcli (optional)
   1. Setup project for gcalcli at https://console.cloud.google.com
   2. Setup OAUTH and obtain tokens
   3. Run ```gcalcli list``` to initalize OAuth. Use the tokens you generate to authorize gcalcli.


### 7. Run the scripts:
```
conky -c sidepanel/sidepanel-1.rc
conky -c sidepanel/sidepanel-2.rc
```
or stand alone conky's, Example...
```
conky -c earth/earth.rc
conky -c system/system.rc
```
and all 3 music scripts can be started via:
```
music/music.sh start
music/music.sh stop
```

Change `-- background = false` to `-- background = true,` in the .rc files to fork the conky's to the background or install conky manager to mange your scripts.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-Party Components

- **allcombined.lua** - created by mrpeachy
- **background.lua, loadall.lua, lua3-bars.lua, and image.lua** - created by wim66.