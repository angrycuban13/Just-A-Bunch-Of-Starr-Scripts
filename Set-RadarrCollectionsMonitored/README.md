# Set Radarr Collections Monitored

Set-RadarrCollectionsMonitored is a Powershell script that will automatically monitor any new collections for you in Radarr.

## Usage

* [Linux](#linux)
* [Unraid](#unraid)
* [Windows](#windows)
* [Docker Compose](#docker-compose)
* [Dry Run](#dry-run)
* [Verbose](#verbose)

## Why should I use this script?

You should use this script if you want to automatically monitor collections as they are added to Radarr based on the movies you add.

## Requirements

* Powershell 7
  * To install Powershell 7, follow [this link](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.2).

## Script Parameters

`ApplicationList` - Specifies which app(s) to use.

`ConfigurationFile` - Specifies a path to the config file, defaults to `$PSScriptRoot\config.conf`.

## Config File Attributes

> [!WARNING]
> Do not use any quotation marks within the config file

### Notification Configuration Attributes

| Attribute   | Description                                                                                               | Default Value | Allowed Values                      |
| ----------- | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| DiscordWebhook | Discord webhook to send notifications                                                                  | ""            |alphanumeric string                  |
| NotifiarrPassthroughWebhook | Notifiarr Passthrough integration webhook to send notifications                                                                  | ""            |alphanumeric string                  |
| NotifiarrPassthroughDiscordChannelId | Channel ID where Notifiarr Passthrough will send notifications to                                                                  | ""            |alphanumeric string                  |

### Radarr Configuration Attributes

| Attribute     | Description                                                                                               | Default Value | Allowed Values                      |
| -----------   | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| ApiKey        | Radarr API Key from Settings &rarr; General                                                                   | ""            | alphanumeric string                 |
| CollectionsToIgnore         | A comma separated list of collection names ending in "Collection"                                                                           | ""            | alphanumeric                         |
| Url         | Radarr URL starting with "http(s)://" including baseurl and  port if required                               | ""            | URL                                 |

## How To Use

### Linux

* Clone repo: `git clone "https://github.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts" "/path/to/repo/clone/location/"`
  * Alternatively you can copy and paste the script contents by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/refs/heads/main/Set-RadarrCollectionsMonitored/Set-RadarrCollectionsMonitored.ps1)
* Create config from the example: `cp /path/to/repo/clone/location/config-example.conf /path/to/repo/clone/location/config.conf`
  * Alternatively you can copy/paste the config file by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Set-RadarrCollectionsMonitored/config-example.conf)
* Update the config file and enter the parameters in `config.conf`
* [Run script](#linux-usage-example)

### Windows

* Clone repo: `git clone "https://github.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts" "/path/to/repo/clone/location/"`
  * Alternatively you can copy and paste the script contents by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/refs/heads/main/Set-RadarrCollectionsMonitored/Set-RadarrCollectionsMonitored.ps1)
* Create config from the example: `cp /path/to/repo/clone/location/owinenatorr-example.conf /path/to/repo/clone/location/owinenatorr.conf`
  * Alternatively you can copy/paste the config file by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Set-RadarrCollectionsMonitored/config-example.conf)
* Update the config file and enter the parameters in `config.conf`
* [Run script](#windows-usage-example)

### Unraid

> [!IMPORTANT]
> Requires Powershell 7 plugin via NerdTools (Unraid 6.11.5) and User Scripts plugin

* Install NerdTools from CA (if not installed)
* Install powershell-7.2.7 or newer from NerdTools Plugin Menu
* Install User Scripts plugin from CA
* Save the [Set-RadarrCollectionsMonitored](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/refs/heads/main/Set-RadarrCollectionsMonitored/Set-RadarrCollectionsMonitored.ps1) script somewhere easy to maintain (Recommended on your appdata share) e.g., `/mnt/user/appdata/scripts`.
  * Save as `Set-RadarrCollectionsMonitored.ps1`.
* Save the [config file](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Set-RadarrCollectionsMonitored/config-example.conf) in the same directory as the Owinenatorr script.
  * Save as `config.conf`.
* Update the config file and enter the parameters in `config.conf`

> [!NOTE]
> Set-RadarrCollectionsMonitored uses app name arguments. So whatever you have setup in the config is what argument you'll use in the script. For instance if you have Radarr and Radarr4K in your config, your arguments will be `-ApplicationList radarr,radarr4k` respectively.

* Go to Plugins &rarr; Settings &rarr; User Scripts
* Click Add New Script.
  * Name it `Set-RadarrCollectionsMonitored`.
* Click the gear icon next to `Set-RadarrCollectionsMonitored` and Edit Script.
* Paste `pwsh /mnt/user/appdata/scripts/Set-RadarrCollectionsMonitored.ps1 -ApplicationList radarr` into the script.
  * Adjust the app names as required for your setup (e.g., radarr, radarr4k)
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
    command: pwsh /scripts/Set-RadarrCollectionsMonitored/Set-RadarrCollectionsMonitored.ps1 -ApplicationList radarr
```

```bash
docker start powershell
```

### Linux Usage Example

#### One Time - Single App - Linux

```bash
pwsh /path/to/repo/clone/location/Set-RadarrCollectionsMonitored/Set-RadarrCollectionsMonitored.ps1 -ApplicationList radarr
```

#### One Time - Multiple Apps - Linux

```bash
pwsh /path/to/repo/clone/location/Set-RadarrCollectionsMonitored/Set-RadarrCollectionsMonitored.ps1 -ApplicationList radarr,radarr4k
```

#### Scheduled Crontab

```bash
0 */6* * *  pwsh /path/to/repo/clone/location/Set-RadarrCollectionsMonitored/Set-RadarrCollectionsMonitored.ps1 -ApplicationList radarr,radarr4k
```

### Windows Usage Example

#### One Time - Single App - Windows

```powershell
pwsh /path/to/repo/clone/location/Owinenatorr/Set-RadarrCollectionsMonitored.ps1 -ApplicationList radarr
```

#### One Time - Multiple Apps - Windows

```powershell
pwsh /path/to/repo/clone/location/Owinenatorr/Set-RadarrCollectionsMonitored.ps1 -ApplicationList radarr,radarr4k
```

#### Scheduled Task

* Open `Task Scheduler`
* Create new task
* Under the `General` tab
  * Give your task a name, e.g "Set-RadarrCollectionsMonitored Script"
  * Set your security options appropiately (see warning below)
* Under the `Triggers` tab
  * Create a schedule of your choice
* Under the `Actions` tab
  * Action                  : `Start a program`
  * Program/script          : `pwsh.exe`
  * Add arguments (optional): `-File /path/to/Set-RadarrCollectionsMonitored.ps1`

> [!WARNING]
> It is never recommended to run scripts as `SYSTEM`. We suggest you use a service account to run your schedule tasks.

### Dry Run

> [!TIP]
> Useful if you want to see what the script is going to do

```powershell
pwsh /path/to/repo/clone/location/Set-RadarrCollectionsMonitored/Set-RadarrCollectionsMonitored.ps1 -ApplicationList radarr -WhatIf
```

### Verbose

> [!TIP]
> Useful for debugging

```powershell
pwsh /path/to/repo/clone/location/Set-RadarrCollectionsMonitored/Set-RadarrCollectionsMonitored.ps1 -ApplicationList radarr -Verbose
```
