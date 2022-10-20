# README

Upgradinatorr is a powershell script to automate the manual searching of *N* items in your Radarr/Sonarr media library that are not tagged with a Upgradinatorr configured Tag .

*N* is the number of items this script will search for, this has the added benefit that you don't hammer your indexers and get banned :)

## Requirements

* Powershell 7: To install Powershell 7, follow [this link](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7.2)
* Radarr
  * `Upgrade Until Custom Format Score` set to at least `10000`
  * Radarr => Settings => Profiles => Quality Profile => Upgrade Until Custom Format Score
* Sonarr
  * None
* *Optional*: Using [TRaSH Guides](https://trash-guides.info/)

## Why should I use this script?

* Let's say you recently started using TRaSH Guides. Now you are wondering if the releases Radarr has grabbed in the past are the highest scored releases per the Custom Format scoring and you have 1000+ movies. Manually searching and keeping track of what was searched is tedious and boring. This script helps with that!

## Script Arguments

`-radarr` - Run script for Radarr

`-sonarr` - Run script for Sonarr

## Config File Attributes

* **Note: Do not use any quotation marks within the config file**

### General Configuration Attributes

* `discordWebhook`: Discord webhook to send notifications when no movies movies or series are left to search. Default: ""

### Radarr Configuration Attributes

| Attribute   | Description                                                                                               | Default Value | Allowed Values                      |
| ----------- | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| ApiKey      | Radarr API Key from Settings => General                                                                   | ""            | alphanumeric string                 |
| Count       | Number of Movies to be searched                                                                           | 10            | integer > 0                         |
| Monitored   | Search Monitored Movies or Unmonitored Movies                                                             | true          | boolean (true/false)                |
| MovieStatus | Minimum Movie Status to search                                                                            | `released`    | `announced` `in cinemas` `released` |
| TagName     | Name of the Tag that will be applied to the movies after they are  searched.                              | ""            | alphanumeric string                 |
| Unattended  | Run the script in an infinite loop and search the library forever and  ever until the end of the Internet | false         | boolean (true/false)                |
| URL         | Radarr URL starting with "http(s)://" including baseurl and  port if required                             | ""            | URL                                 |

### Sonarr

| Attribute    | Description                                                                                               | Default Value | Allowed Values                      |
| ------------ | --------------------------------------------------------------------------------------------------------- | ------------- | ----------------------------------- |
| ApiKey       | Sonarr API Key from Settings => General                                                                   | ""            | alphanumeric string                 |
| Count        | Number of Series to be searched                                                                           | 5             | integer > 0                         |
| Monitored    | Search Monitored Series or Unmonitored Series                                                             | true          | boolean (true/false)                |
| SeriesStatus | Minimum Series Status to search                                                                           | ""            | `continuing`   `upcoming`   `ended` |
| TagName      | Name of the Tag that will be applied to the Series after they are  searched.                              | ""            | alphanumeric string                 |
| Unattended   | Run the script in an infinite loop and search the library forever and  ever until the end of the Internet | false         | boolean (true/false)                |
| URL          | Sonarr URL starting with "http(s)://" including baseurl and  port if required                             | ""            | URL                                 |

## How To Use

The instructions below are for Linux, but the concept for non-linux are the same.

* Clone repo: `git clone "https://github.com/angrycuban13/Scripts.git" "/path/to/repo/clone/location/"`
* Create config from the example: `cp /path/to/repo/clone/location/upgradinatorr-example.conf /path/to/repo/clone/location/upgradinatorr.conf`
* Update the config file and enter the parameters in `upgradinatorr.conf`
* Run script (see below)

## `upgradinatorr.ps1` usage

### One Time

```powershell
  pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr
```

#### One Time - Multiple Apps

```powershell
  pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr,sonarr
```

### Verbose Output

* Useful for debugging

```powershell
  pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr -verbose
```

### Scheduled Crontab

```none
  0 */6* **  pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr
```
