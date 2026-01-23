![License](https://img.shields.io/github/license/rew62/conky-aurora)
![Stars](https://img.shields.io/github/stars/rew62/conky-aurora)
![Issues](https://img.shields.io/github/issues/rew62/conky-aurora)
![Last Commit](https://img.shields.io/github/last-commit/rew62/conky-aurora)

# Conky Scripts Collection

A set of Conky scripts built on Linux Mint v22.2 (Zara)

## Credits

- **allcombined.lua** - Created by mrpeachy
- **All other scripts** - Created by R Webb (@rew62)

## Scripts Overview

1. **calendar/calendar.rc** - Calendar with unicode formatted list from gcalcli agenda
2. **earth/fourmilab.sh** - Earth viewer script using fourmilab.ch
3. **sidepanel/sidepanel-1.rc** - Sidepanel with Sun and Moon
4. **sidepanel/sidepanel-2.rc** - Sidepanel with System, CPU, Memory, and Network information

### Additional Components

- **weather.lua** - Contains additional conky variables
- **master-loader.lua** - Handles Cairo drawing functions and acts as the main Lua hook for Conky

## About fourmilab.ch

The [fourmilab.ch](http://www.fourmilab.ch) site was developed by John Walker, founder of Autodesk, Inc. and co-author of AutoCAD. John passed away in 2024. The site offers various content including an Earth/Moon viewer with many selectable configuartion parameters. This script uses a view of the Earth from the Sun's perspective, however, you may customize this on the fourmilab site.

**Permission from Webmaster at fourmilab.ch:** Permission is granted without warranty, endorsement, or ongoing obligation on my part, and does not imply that I have reviewed, approved, or support the scripts themselves.

## Important Notes

### /dev/shm Usage

Verify that `/dev/shm` is available on your system. `/dev/shm` is a virtual filesystem (tmpfs) that resides in RAM; using it for temporary files improves performance and reduces wear on your SSD. Most modern Linux distributions including Arch, Debian, and derivatives like Ubuntu and Mint—mount `/dev/shm` by default."

To check if it is mounted, you can run: `df -h /dev/shm`

## Installation & Setup

### 1. Install Required Packages
```bash
# Install Conky
sudo apt install conky-all

# Install Lua
sudo apt install lua5.4 liblua5.4-dev

# Install Symbola Font
sudo apt install fonts-symbola

# Install gcalcli
sudo apt install gcalcli
```

Additionally fourmilab.sh utilizes the convert command from ImageMagick which is installed by default on Linix Mint. Install ImageMagick if convert is not available.


### 2. Install Custom Fonts

Install the fonts located in the `fonts` directory.

### 3. Get OpenWeatherMap API Key

1. Get an API key from [openweathermap.org](http://www.openweathermap.org)
   You will need:
      - Your API key
      - Your city ID
      - Your measurement units: `'metric'` (Celsius, m/s) or `'imperial'` (Fahrenheit, mph)


### 4. Run Configuration Script to create a .env file with your keys

The `.env` file requires these keys:
- `apikey` - Your API key from openweathermap.org
- `cityid` - Your city ID
- `cf` - Your weather measure units (metric or imperial)
- `lat` - Latitude (decimal format)
- `lon` - Longitude (decimal format)

See `.env-example` for the format reference.

### Running the configuration script
```bash
./config.sh
```

The script will:
1. Load existing values from `.env` if present
2. Prompt for each configuration value (press Enter to keep existing/default)
3. Attempt to Auto-detect your network interface
4. Ask for confirmation before writing
5. Update `.env`, weather.lua, and sidepanel files with values entered.

### 5. Set Up Cron Job to generate an Image of the Earth every 10 mintes.

1. Edit `earth/crontab` and replace <user> with your home directory name.

   **crontab entries:**
   ```cron
   reboot /home/<user>/.conky/rew62/earth/fourmilab-earth.sh > /dev/shm/cron_debug.log 2>&1
   */10 * * * * /home/<user>/.conky/rew62/earth/fourmilab-earth.sh > /dev/shm/cron_debug.log 2>&1
   ```

2. Install the crontab:
```bash
crontab < earth/crontab
```

- Verify installation:
      `crontab -l`

### 6. Set Up gcalcli
   1. Setup project for gcalcli at https://console.cloud.google.com
   2. Setup OAUTH and obtain tokens
   3. Run ```gcalcli list``` to initalize OAuth. Use the tokens you generate to authorize gcalcli.


## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

### Third-Party Components

- **allcombined.lua** - Created by mrpeachy

Please refer to individual script files for any additional licensing information related to third-party components.