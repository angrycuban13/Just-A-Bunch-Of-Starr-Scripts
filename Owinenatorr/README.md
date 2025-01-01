# Owinenatorr

Owinenatorr is a Powershell script that kicks off rename operations programatically in Radarr and Sonarr after changing the naming scheme for movies or series.

## Usage

* [Linux](#linux)
* [Unraid](#unraid)
* [Windows](#windows)
* [Docker Compose](#docker-compose)

### Dry Run

> [!TIP]
> Useful if you want to see what the script is going to do

```powershell
pwsh /path/to/repo/clone/location/Owinenatorr/owinenatorr.ps1 -ApplicationList radarr -WhatIf
```

### Verbose Output

> [!TIP]
> Useful for debugging

```powershell
pwsh /path/to/repo/clone/location/Owinenatorr/owinenatorr.ps1 -ApplicationList radarr -Verbose
```

## Why should I use this script?

You should use this script if you want to slowly and programatically rename your media items instead of renaming them all at once.

## Requirements

* Powershell 7
  * To install Powershell 7, follow [this link](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.2).
* Radarr
  * Radarr &rarr; Settings &rarr; Media Management
    * [x] Rename Movies
* Sonarr:
  * Sonarr &rarr; Settings &rarr; Media Management
    * [x] Rename Episodes

> [!TIP]
> Use [TRaSH Guides - Radarr Naming Scheme](https://trash-guides.info/Radarr/Radarr-recommended-naming-scheme/)
>
> Use [TraSH Guides - Sonarr Naming Scheme](https://trash-guides.info/Sonarr/Sonarr-recommended-naming-scheme/)

## Script Parameters

`ApplicationList` - Specifies which app(s) to use.

`ConfigurationFile` - Specifies a path to the config file, defaults to `$PSScriptRoot\owinenatorr.conf`.

## Config File Attributes

> [!WARNING]
> Do not use any quotation marks within the config file


### Radarr Configuration Attributes

| Attribute     | Description                                                                                               | Default Value | Allowed Values                      |
| -----------   | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| ApiKey        | Radarr API Key from Settings &rarr; General                                                                   | ""            | alphanumeric string                 |
| Count         | Number of movies to be renamed                                                                           | 10            | integer > 0                         |
| IgnoreTag     | Used for filtering media items - movies with this tag will be ignored                                                            | ""            | alphanumeric string                 |
| Monitored     | Used for filtering media items<ul><li>empty: Any movies can be selected</li><li>false: Only unmonitored movies will be selected</li><li>true: Only monitored movies will be selected</li>                                                              | ""          | boolean (true/false)                |
| MovieStatus   | Used for filtering media items - movies with this status will be selected                                                                            | "released"    | <ul><li>`announced`</li><li>`in cinemas`</li><li>`released`</li></ul> |
| QualityProfileName | Used for filtering media items - movies with this quality profile will be selected                                               | ""            | alphanumeric string                 |
| TagName     | Used for filtering media items - name of the tag that will be applied to the movies that were checked                                  | ""            | alphanumeric string                 |
| Url         | Radarr URL starting with "http(s)://" including baseurl and  port if required                               | ""            | URL                                 |

### Sonarr Configuration Attributes

| Attribute    | Description                                                                                               | Default Value | Allowed Values                      |
| ------------ | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| ApiKey       | Sonarr API Key from Settings &rarr; General                                                                   | ""            | alphanumeric string                 |
| Count        | Number of series to be renamed                                                                           | 5             | integer > 0                         |
| IgnoreTag     | Used for filtering media items - series with this tag will be ignored                                                           | ""            | alphanumeric string                 |
| Monitored    |  Used for filtering media items<ul><li>empty: Any series can be selected</li><li>false: Only unmonitored series will be selected</li><li>true: Only monitored series will be selected</li>                                                               | true          | boolean (true/false)                |
| QualityProfileName | Only series with this quality profile with be searched                                              | ""            | alphanumeric string                 |
| SeriesStatus | Used for filtering media items - series with this status will be selected                                                                          | ""            | <ul><li>`continuing`</li><li>`upcoming`</li><li>`ended`</li></ul> |
| TagName      | Used for filtering media items - name of the tag that will be applied to the movies that were checked                             | ""            | alphanumeric string                 |
| Url          | Sonarr URL starting with "http(s)://" including baseurl and  port if required                             | ""            | URL                                 |

## How To Use

### Linux

* Clone repo: `git clone "https://github.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts" "/path/to/repo/clone/location/"`
  * Alternatively you can copy and paste the script contents by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/refs/heads/main/Owinenatorr/owinenatorr.ps1)
* Create config from the example: `cp /path/to/repo/clone/location/owinenatorr-example.conf /path/to/repo/clone/location/owinenatorr.conf`
  * Alternatively you can copy/paste the config file by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Owinenatorr/owinenatorr-example.conf)
* Update the config file and enter the parameters in `owinenatorr.conf`
* [Run script](#linux-usage-example)

### Windows

* Clone repo: `git clone "https://github.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts" "/path/to/repo/clone/location/"`
  * Alternatively you can copy and paste the script contents by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/refs/heads/main/Owinenatorr/owinenatorr.ps1)
* Create config from the example: `cp /path/to/repo/clone/location/owinenatorr-example.conf /path/to/repo/clone/location/owinenatorr.conf`
  * Alternatively you can copy/paste the config file by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Owinenatorr/owinenatorr-example.conf)
* Update the config file and enter the parameters in `owinenatorr.conf`
* [Run script](#windows-usage-example)

### Unraid

> [!IMPORTANT]
> Requires Powershell 7 plugin via NerdTools (Unraid 6.11.5) and User Scripts plugin

* Install NerdTools from CA (if not installed)
* Install powershell-7.2.7 or newer from NerdTools Plugin Menu
* Install User Scripts plugin from CA
* Save the [Owinenatorr](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/refs/heads/main/Owinenatorr/owinenatorr.ps1) script somewhere easy to maintain (Recommended on your appdata share) e.g., `/mnt/user/appdata/scripts`.
  * Save as `owinenatorr.ps1`.
* Save the [config file](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Owinenatorr/owinenatorr-example.conf) in the same directory as the Owinenatorr script.
  * Save as `owinenatorr.conf`.
* Update the config file and enter the parameters in `owinenatorr.conf`

> [!NOTE]
> Owinenatorr uses app name arguments. So whatever you have setup in the config is what argument you'll use in the script. For instance if you have Radarr and Radarr4K in your config, your arguments will be `-ApplicationList radarr,radarr4k` respectively.

* Go to Plugins &rarr; Settings &rarr; User Scripts
* Click Add New Script.
  * Name it `Owinenatorr`.
* Click the gear icon next to `Owinenatorr` and Edit Script.
* Paste `pwsh /mnt/user/appdata/scripts/owinenatorr.ps1 -ApplicationList radarr` into the script.
  * Adjust the app names as required for your setup (e.g., radarr, radarr4k, sonarr, sonarr4k)
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
    command: pwsh /scripts/Owinenatorr/owinenatorr.ps1 -ApplicationList radarr,sonarr
```

```bash
docker start powershell
```

### Linux Usage Example

#### One Time - Single App - Linux

```bash
pwsh /path/to/repo/clone/location/Owinenatorr/owinenatorr.ps1 -ApplicationList radarr
```

#### One Time - Multiple Apps - Linux

```bash
pwsh /path/to/repo/clone/location/Owinenatorr/owinenatorr.ps1 -ApplicationList radarr,sonarr
```

#### Scheduled Crontab

```bash
0 */6* **  pwsh /path/to/repo/clone/location/Owinenatorr/owinenatorr.ps1 -ApplicationList radarr,sonarr
```

### Windows Usage Example

#### One Time - Single App - Windows

```powershell
pwsh /path/to/repo/clone/location/Owinenatorr/owinenatorr.ps1 -ApplicationList radarr
```

#### One Time - Multiple Apps - Windows

```powershell
pwsh /path/to/repo/clone/location/Owinenatorr/owinenatorr.ps1 -ApplicationList radarr,sonarr
```

#### Scheduled Task

* Open `Task Scheduler`
* Create new task
* Under the `General` tab
  * Give your task a name, e.g "Owinenatorr Script"
  * Set your security options appropiately (see warning below)
* Under the `Triggers` tab
  * Create a schedule of your choice
* Under the `Actions` tab
  * Action                  : `Start a program`
  * Program/script          : `pwsh.exe`
  * Add arguments (optional): `-File /path/to/owinenatorr.ps1`

> [!WARNING]
> It is never recommended to run scripts as `SYSTEM`. We suggest you use a service account to run your schedule tasks.
