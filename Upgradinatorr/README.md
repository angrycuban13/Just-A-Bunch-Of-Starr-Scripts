# README

Upgradinatorr is a Powershell script to automate the manual searching of *N* items in your Radarr, Sonarr or Lidarr media library that are not tagged with a Upgradinatorr configured tag.

> [!NOTE]
> *N* is the number of items this script will search for, this has the added benefit that you don't hammer your indexers and get banned :)

## Usage

* [Linux](#linux)
* [Unraid](#unraid)
* [Windows](#windows)
* [Docker Compose](#docker-compose)
* [Dry Run](#dry-run)
* [Verbose](#verbose)

## Why should I use this script?

Let's say you recently started using TRaSH Guides. Now you are wondering if the releases Radarr, Sonarr or Lidarr have grabbed in the past are the highest scored releases per the Custom Format scoring you've selected and you have 1000+ media items. Manually searching and keeping track of what was searched is tedious and boring. This script helps with that!

## Requirements

* Powershell 7
  * To install Powershell 7, follow [this link](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.2).
* Radarr
  * Radarr &rarr; Settings &rarr; Profiles &rarr; Quality Profile &rarr; Upgrade Until Custom Format Score
    * `Upgrade Until Custom Format Score` set to at least `10000`
* Sonarr
  * Sonarr V3:
    * None
  * Sonarr V4:
    * Sonarr &rarr; Settings &rarr; Profiles &rarr; Quality Profile &rarr; Upgrade Until Custom Format Score
      * `Upgrade Until Custom Format Score` set to at least `10000`.

> [!TIP]
> Use [TRaSH Guides](https://trash-guides.info/).

## Script Parameters

`ApplicationList` - Specifies which app(s) to use.

`ConfigurationFile` - Specifies a path to the config file, defaults to `$PSScriptRoot\upgradinatorr.conf`.

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
| Count         | Number of Movies to be searched                                                                           | 10            | integer > 0                         |
| IgnoreTag     | Used for filtering movies - movies with this tag name will not be searched                                                            | ""            | alphanumeric string                 |
| Monitored     | Used for filtering movies - search monitored or unmonitored Movies                                                             | true          | boolean (true/false)                |
| MovieStatus   | Used for filtering movies - minimum `Movie Status` to search                                                                            | "released"    | <ul><li>`announced`</li><li>`in cinemas`</li><li>`released`</li></ul> |
| QualityProfileName | Used for filtering movies - only movies with this quality profile with be searched                                               | ""            | alphanumeric string                 |
| TagName     | Name of the tag that will be applied to the movies after they are searched                                  | ""            | alphanumeric string                 |
| Unattended  | Run the script in an infinite loop and search the library forever and  ever until the end of the Internet   | false         | boolean (true/false)                |
| Url         | Radarr URL starting with "http(s)://" including baseurl and  port if required                               | ""            | URL                                 |

### Sonarr Configuration Attributes

| Attribute    | Description                                                                                               | Default Value | Allowed Values                      |
| ------------ | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| ApiKey       | Sonarr API Key from Settings &rarr; General                                                                   | ""            | alphanumeric string                 |
| Count        | Number of Series to be searched                                                                           | 5             | integer > 0                         |
| IgnoreTag     | Used for filtering series - series with this tag name will not be searched                                                           | ""            | alphanumeric string                 |
| Monitored    | Used for filtering series - search monitored or unmonitored series                                                             | true          | boolean (true/false)                |
| QualityProfileName | Used for filtering series - only series with this quality profile with be searched                                              | ""            | alphanumeric string                 |
| SeriesStatus | Used for filtering series - minimum `Series Status` to search                                                                           | ""            | <ul><li>`continuing`</li><li>`upcoming`</li><li>`ended`</li></ul> |
| TagName      | Name of the Tag that will be applied to the Series after they are  searched.                              | ""            | alphanumeric string                 |
| Unattended   | Run the script in an infinite loop and search the library forever and  ever until the end of the Internet | false         | boolean (true/false)                |
| Url          | Sonarr URL starting with "http(s)://" including baseurl and  port if required                             | ""            | URL                                 |

### Lidarr Configuration Attributes

| Attribute    | Description                                                                                               | Default Value | Allowed Values                      |
| ------------ | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| ApiKey       | Lidarr API Key from Settings &rarr; General                                                                   | ""            | alphanumeric string                 |
| ArtistStatus | Used for filtering artists - minimum `Artist Status` to search                                                                           | ""            | <ul><li>`continuing`</li><li>`ended`</li></ul>               |
| Count        | Number of artists to be searched                                                                           | 5             | integer > 0                         |
| IgnoreTag     | Used for filtering artists - artists with this tag name will not be searched                                                           | ""            | alphanumeric string                 |
| Monitored    | Used for filtering artists - search monitored or unmonitored artists                                                             | true          | boolean (true/false)                |
| TagName      | Name of the Tag that will be applied to the Series after they are  searched.                              | ""            | alphanumeric string                 |
| Unattended   | Run the script in an infinite loop and search the library forever and  ever until the end of the Internet | false         | boolean (true/false)                |
| Url          | Sonarr URL starting with "http(s)://" including baseurl and  port if required                             | ""            | URL                                 |

## How To Use

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
    command: pwsh /scripts/Upgradinatorr/upgradinatorr.ps1 -ApplicationList radarr,sonarr
```

```bash
docker start powershell
```

### Linux

* Clone repo: `git clone "https://github.com/angrycuban13/Scripts.git" "/path/to/repo/clone/location/"`
  * Alternatively you can copy and paste the script contents by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr.ps1)
* Create config from the example: `cp /path/to/repo/clone/location/upgradinatorr-example.conf /path/to/repo/clone/location/upgradinatorr.conf`
  * Alternatively you can copy/paste the config file by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr-example.conf)
* Update the config file and enter the parameters in `upgradinatorr.conf`
* [Run script](#linux-usage-example)

### Unraid

> [!IMPORTANT]
> Requires Powershell 7 plugin via NerdTools (Unraid 6.11.5) and User Scripts plugin

* Install NerdTools from CA (if not installed)
* Install powershell-7.2.7 or newer from NerdTools Plugin Menu
* Install User Scripts plugin from CA
* Save the [Upgradinatorr](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr.ps1) script somewhere easy to maintain (Recommended on your appdata share) e.g., `/mnt/user/appdata/scripts`.
  * Save as `upgradinatorr.ps1`.
* Save the [config file](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr-example.conf) in the same directory as the Upgradinatorr script.
  * Save as `upgradinatorr.conf`.
* Update the config file and enter the parameters in `upgradinatorr.conf`

> [!NOTE]
> Upgradinatorr uses app name arguments. So whatever you have setup in the config is what argument you'll use in the script. For instance if you have Radarr and Radarr4K in your config, your arguments will be `-ApplicationList radarr,radarr4k` respectively

* Go to Plugins &rarr; Settings &rarr; User Scripts
* Click Add New Script.
  * Name it `Upgradinatorr`.
* Click the gear icon next to Upgradinatorr and Edit Script.
* Paste `pwsh /mnt/user/appdata/scripts/upgradinatorr.ps1 -ApplicationList radarr` into the script.
  * Adjust the app names as required for your setup (e.g., radarr, radarr4k, sonarr, sonarr4k, lidarr)
* After that, you can click `Run Script`, `Run in Background` or set up to run the script on a schedule by clicking `Schedule Disabled` and setting it to whatever you prefer.
  * If you'd like the script to run every 6 hours, select Custom, and the cron will be `0 */6 * * *` where you can replace the 6 with whatever interval you'd like.

### Windows

* Clone repo: `git clone "https://github.com/angrycuban13/Scripts.git" "/path/to/repo/clone/location/"`
  * Alternatively you can copy and paste the script contents by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr.ps1)
* Create config from the example: `cp /path/to/repo/clone/location/upgradinatorr-example.conf /path/to/repo/clone/location/upgradinatorr.conf`
  * Alternatively you can copy/paste the config file by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr-example.conf)
* Update the config file and enter the parameters in `upgradinatorr.conf`
* [Run script](#windows-usage-example)

### Linux Usage Example

#### One Time - Single App - Linux

```bash
pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -ApplicationList radarr
```

#### One Time - Multiple Apps - Linux

```bash
pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -ApplicationList radarr,sonarr,lidarr
```

#### Scheduled Crontab

```bash
0 */6* **  pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -ApplicationList radarr,sonarr
```

### Windows Usage Example

#### One Time - Single App - Windows

```powershell
pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -ApplicationList radarr
```

#### One Time - Multiple Apps - Windows

```powershell
pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -ApplicationList radarr,sonarr,lidarr
```

#### Scheduled Task

* Open `Task Scheduler`
* Create new task
* Under the `General` tab
  * Give your task a name, e.g "Upgradinatorr Script"
  * Set your security options appropiately (see warning below)
* Under the `Triggers` tab
  * Create a schedule of your choice
* Under the `Actions` tab
  * Action                  : `Start a program`
  * Program/script          : `pwsh.exe`
  * Add arguments (optional): `-File /path/to/upgradinatorr.ps1`

> [!WARNING]
> It is never recommended to run scripts as `SYSTEM`. We suggest you use a service account to run your schedule tasks.

### Dry Run

> [!TIP]
> Useful if you want to see what the script is going to do


```powershell
pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -ApplicationList radarr -WhatIf
```

### Verbose

> [!TIP]
> Useful for debugging

```powershell
pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -ApplicationList radarr -Verbose
```
