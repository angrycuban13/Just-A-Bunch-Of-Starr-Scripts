# README

Upgradinatorr is a Powershell script to automate the manual searching of *N* items in your Radarr/Sonarr media library that are not tagged with a Upgradinatorr configured tag.

> **Note**
>
> *N* is the number of items this script will search for, this has the added benefit that you don't hammer your indexers and get banned :)

## Requirements

* Powershell 7: To install Powershell 7, follow [this link](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.2)
* Radarr
  * Radarr => Settings => Profiles => Quality Profile => Upgrade Until Custom Format Score
    * `Upgrade Until Custom Format Score` set to at least `10000`
* Sonarr
  * Sonarr V3:
    * None
  * Sonarr V4:
    * Sonarr => Settings => Profiles => Quality Profile => Upgrade Until Custom Format Score
      * `Upgrade Until Custom Format Score` set to at least `10000`
* *Optional*: Using [TRaSH Guides](https://trash-guides.info/)

## Why should I use this script?

* Let's say you recently started using TRaSH Guides. Now you are wondering if the releases Radarr has grabbed in the past are the highest scored releases per the Custom Format scoring and you have 1000+ movies. Manually searching and keeping track of what was searched is tedious and boring. This script helps with that!

## Script Arguments

`-radarr` - Run script for any configured Radarr instances

`-sonarr` - Run script for any configured Sonarr instances

## Config File Attributes

> **Warning**
>
> Do not use any quotation marks within the config file

### General Configuration Attributes

| Attribute   | Description                                                                                               | Default Value | Allowed Values                      |
| ----------- | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| discordWebhook | Discord webhook to send notifications when no movies movies or series are left to search.              | ""            |alphanumeric string                  |

### Radarr Configuration Attributes

| Attribute   | Description                                                                                               | Default Value | Allowed Values                      |
| ----------- | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| apiKey      | Radarr API Key from Settings => General                                                                   | ""            | alphanumeric string                 |
| count       | Number of Movies to be searched                                                                           | 10            | integer > 0                         |
| monitored   | Search Monitored Movies or Unmonitored Movies                                                             | true          | boolean (true/false)                |
| movieStatus | Minimum Movie Status to search                                                                            | `released`    | `announced` `in cinemas` `released` |
| tagName     | Name of the Tag that will be applied to the movies after they are  searched.                              | ""            | alphanumeric string                 |
| unattended  | Run the script in an infinite loop and search the library forever and  ever until the end of the Internet | false         | boolean (true/false)                |
| url         | Radarr URL starting with "http(s)://" including baseurl and  port if required                             | ""            | URL                                 |

### Sonarr Configuration Attributes

| Attribute    | Description                                                                                               | Default Value | Allowed Values                      |
| ------------ | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| apiKey       | Sonarr API Key from Settings => General                                                                   | ""            | alphanumeric string                 |
| count        | Number of Series to be searched                                                                           | 5             | integer > 0                         |
| monitored    | Search Monitored Series or Unmonitored Series                                                             | true          | boolean (true/false)                |
| seriesStatus | Minimum Series Status to search                                                                           | ""            | `continuing`   `upcoming`   `ended` |
| tagName      | Name of the Tag that will be applied to the Series after they are  searched.                              | ""            | alphanumeric string                 |
| unattended   | Run the script in an infinite loop and search the library forever and  ever until the end of the Internet | false         | boolean (true/false)                |
| url          | Sonarr URL starting with "http(s)://" including baseurl and  port if required                             | ""            | URL                                 |

### Lidarr Configuration Attributes

| Attribute    | Description                                                                                               | Default Value | Allowed Values                      |
| ------------ | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| apiKey       | Lidarr API Key from Settings => General                                                                   | ""            | alphanumeric string                 |
| count        | Number of Series to be searched                                                                           | 5             | integer > 0                         |
| monitored    | Search Monitored Series or Unmonitored Series                                                             | true          | boolean (true/false)                |
| seriesStatus | Minimum Series Status to search                                                                           | ""            | `continuing`   `upcoming`   `ended` |
| tagName      | Name of the Tag that will be applied to the Series after they are  searched.                              | ""            | alphanumeric string                 |
| unattended   | Run the script in an infinite loop and search the library forever and  ever until the end of the Internet | false         | boolean (true/false)                |
| url          | Sonarr URL starting with "http(s)://" including baseurl and  port if required                             | ""            | URL                                 |

## How To Use

### Linux

* Clone repo: `git clone "https://github.com/angrycuban13/Scripts.git" "/path/to/repo/clone/location/"`
  * Alternatively you can copy and paste the script contents by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr.ps1)
* Create config from the example: `cp /path/to/repo/clone/location/upgradinatorr-example.conf /path/to/repo/clone/location/upgradinatorr.conf`
  * Alternatively you can copy/paste the config file by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr-example.conf)
* Update the config file and enter the parameters in `upgradinatorr.conf`
* Run script - [Linux](#Linux-Usage-Example)

### Windows

* Clone repo: `git clone "https://github.com/angrycuban13/Scripts.git" "/path/to/repo/clone/location/"`
  * Alternatively you can copy and paste the script contents by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr.ps1)
* Create config from the example: `cp /path/to/repo/clone/location/upgradinatorr-example.conf /path/to/repo/clone/location/upgradinatorr.conf`
  * Alternatively you can copy/paste the config file by clicking on this [link](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr-example.conf)
* Update the config file and enter the parameters in `upgradinatorr.conf`
* Run script (see below)

### Unraid
> Requires Powershell 7 plugin via NerdTools (Unraid 6.11.5) and User Scripts plugin
* Install NerdTools from CA, then install powershell-7.2.7 in NerdTools Plugin Menu
* Install User Scripts plugin from CA
* Save the [Upgradinatorr](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr.ps1) script somewhere easy to maintain (Recommended on your appdata share) ie, `/mnt/user/appdata/scripts` save as `upgradinatorr.ps1`.
* Save the [config](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Upgradinatorr/upgradinatorr-example.conf) in the same directory as the Upgradinatorr script. Save as `upgradinatorr.conf`.
* Update the config file and enter the parameters in `upgradinatorr.conf`
> Upgradinatorr uses app name arguments. So whatever you have setup in the config is what argument you'll use in the script. For instance if you have Radarr and Radarr4K in your config, your arguments will be `-apps radarr,radarr4k` respectively
* Go to Plugins / Settings > User Scripts and click Add New Script. Name it `Upgradinatorr`
* Click the gear icon next to Upgradinatorr and Edit Script
* Paste `pwsh /mnt/user/appdata/scripts/upgradinatorr.ps1 -apps radarr` into the script. Adjust the app names as required for your setup (radarr,radarr4k,sonarr,sonarr4k,lidarr)
* After that, you can click Run Script, Run in Background or set up to run the script on a schedule by clicking `Schedule Disabled` and setting it to whatever you prefer. If you'd like the script to run every 6 hours, select Custom, and the cron will be `0 */6 * * *` where you can replace the 6 with whatever interval you'd like.

### Docker Compose

> **Note**
>
> The variables in the Docker Compose below are optional

```yml
# powershell - https://hub.docker.com/_/microsoft-powershell
  powershell:
    container_name: powershell
    image: mcr.microsoft.com/powershell:latest
    restart: "no"
    logging:
      driver: json-file
      options:
        max-file: ${DOCKERLOGGING_MAXFILE}
        max-size: ${DOCKERLOGGING_MAXSIZE}
    environment:
      - PUID=${PUID}
      - PGID=${PGID}
    volumes:
      - ${DOCKERCONFDIR}/powershell:/scripts
    command: pwsh /scripts/Upgradinatorr/upgradinatorr.ps1 -apps radarr,sonarr
```

```bash
    docker start powershell
```

> **Warning**
>
> This Docker Compose example will **only run once**. If you want to run it on a schedule you will need to cron it

### Linux Usage Example

#### One Time - Single App - Linux

```powershell
  pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr
```

#### One Time - Multiple Apps - Linux

```powershell
  pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr,sonarr,lidarr
```

#### Scheduled Crontab

```bash
  0 */6* **  pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr,sonarr
```

### Windows Usage Example

#### One Time - Single App - Windows

```powershell
  pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr
```

#### One Time - Multiple Apps - Windows

```powershell
  pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr,sonarr,lidarr
```

#### Scheduled Task

* Open `Task Scheduler`
* Create new task
* Under the `General` tab
  * Give your task a name, e.g "Upgradinatorr Script"
  * Set your security options appropiately
    * Don't run your script as the `SYSTEM` account...
    * There's no need to run the script with the highest privileges either
* Under the `Triggers` tab
  * Create a schedule of your choice
* Under the `Actions` tab
  * Action: `Start a program`
  * Program/script: `/path/to/pwsh`
  * Add arguments (optional): `-File /path/to/upgradinatorr/file`

### Verbose Output

> **Note**
>
> Useful for debugging

```powershell
  pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr -verbose
```
