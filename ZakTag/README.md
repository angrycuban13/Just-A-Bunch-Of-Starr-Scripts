# ZakTag

ZakTag is a Powershell script that automatically tags movies in Radarr with their release group. The script retrieves all movies from Radarr, creates missing tags for each release group, and tags movies with their corresponding release group tag. If the movie has the wrong tag, the script will remove it and apply the correct tag.

## Usage

* [Linux](#linux)
* [Unraid](#unraid)
* [Windows](#windows)
* [Docker Compose](#docker-compose)
* [Dry Run](#dry-run)
* [Verbose](#verbose)

## Why should I use this script?

You should use this script if you want to keep track of how many movies from *X* release group are in your library.

* Powershell 7
  * To install Powershell 7, follow [this link](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.2).

## How To Use

### General

> [!IMPORTANT]
> Please fill in the variables in line 691-692:

* `$radarrApiKey` - Your Radarr API Key
* `$radarrUrl` - Your Radarr URL

### Linux

* Clone repo: `git clone "https://github.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts" "/path/to/repo/clone/location/"`
  * Alternatively you can copy and paste the script contents by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/refs/heads/main/ZakTag/ZakTag.ps1)
* [Run script](#linux-usage-example)

### Windows

* Clone repo: `git clone "https://github.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts" "/path/to/repo/clone/location/"`
  * Alternatively you can copy and paste the script contents by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/refs/heads/main/ZakTag/ZakTag.ps1)
* [Run script](#windows-usage-example)

### Unraid

> [!IMPORTANT]
> Requires Powershell 7 plugin via NerdTools (Unraid 6.11.5) and User Scripts plugin

* Install NerdTools from CA (if not installed)
* Install powershell-7.2.7 or newer from NerdTools Plugin Menu
* Install User Scripts plugin from CA
* Save the [ZakTag](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/refs/heads/main/ZakTag/ZakTag.ps1) script somewhere easy to maintain (Recommended on your appdata share) e.g., `/mnt/user/appdata/scripts`.
  * Save as `ZakTag.ps1`.
* Go to Plugins &rarr; Settings &rarr; User Scripts
* Click Add New Script.
  * Name it `ZakTag`.
* Click the gear icon next to `ZakTag` and Edit Script.
* Paste `pwsh /mnt/user/appdata/scripts/ZakTag.ps1` into the script.
* After that, you can click `Run Script`, `Run in Background` or set up to run the script on a schedule by clicking `Schedule Disabled` and setting it to whatever you prefer.
  * If you'd like the script to run every 6 hours, select Custom, and the cron will be `0 */6 * * *` where you can replace the 6 with whatever interval you'd like.

### Docker Compose

> [!WARNING]
> This Docker Compose example will **only run once**. If you want to run it on a schedule you will need to cron it

```yml
# powershell - https://hub.docker.com/_/microsoft-powershell
  powershell:
    container_name: powershell
    image: mcr.microsoft.com/powershell:latest
    restart: "no"
    # optional
    logging:
      driver: json-file
      options:
        max-file: 10
        max-size: 200k
    # optional
    environment:
      - PUID=1000
      - PGID=1000
    volumes:
      - /path/to/appdata/powershell:/scripts
    command: pwsh /scripts/Owinenatorr/ZakTag.ps1
```

```bash
docker start powershell
```

### Linux Usage Example

#### One Time - Single App - Linux

```bash
pwsh /path/to/repo/clone/location/ZakTag/ZakTag.ps1
```

#### One Time - Multiple Apps - Linux

```bash
pwsh /path/to/repo/clone/location/Owinenatorr/ZakTag.ps1
```

#### Scheduled Crontab

```bash
0 */6* **  pwsh /path/to/repo/clone/location/ZakTag/ZakTag.ps1
```

### Windows Usage Example

#### One Time - Single App - Windows

```powershell
pwsh /path/to/repo/clone/location/ZakTag/ZakTag.ps1
```

#### One Time - Multiple Apps - Windows

```powershell
pwsh /path/to/repo/clone/location/ZakTag/ZakTag.ps1
```

#### Scheduled Task

* Open `Task Scheduler`
* Create new task
* Under the `General` tab
  * Give your task a name, e.g "ZakTag Script"
  * Set your security options appropiately (see warning below)
* Under the `Triggers` tab
  * Create a schedule of your choice
* Under the `Actions` tab
  * Action                  : `Start a program`
  * Program/script          : `pwsh.exe`
  * Add arguments (optional): `-File /path/to/ZakTag.ps1`

> [!WARNING]
> It is never recommended to run scripts as `SYSTEM`. We suggest you use a service account to run your schedule tasks.

### Dry Run

> [!TIP]
> Useful if you want to see what the script is going to do

```powershell
pwsh /path/to/repo/clone/location/ZakTag/ZakTag.ps1 -WhatIf
```

### Verbose

> [!TIP]
> Useful for debugging

```powershell
pwsh /path/to/repo/clone/location/ZakTag/ZakTag.ps1 -Verbose
```
