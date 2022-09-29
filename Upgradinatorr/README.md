# README

Script to manually search *n* items that are not tagged with a specific tag in your Radarr/Sonarr media library. *n* is the number of items this script will search for, this has the added benefit that you don't hammer your indexers and get banned :)

## Requirements

* Powershell 7: To install Powershell 7, follow [this link](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2)
* `Upgrade Until Custom Format Score` set to at least `10000`
  * Radarr > Settings > Profiles > Quality Profile > Upgrade Until Custom Format Score
* *Optional*: Using [TRaSH guides](https://trash-guides.info/)

## Why should I use this script?

* Let's say you recently started using TRaSH guides. Now you are wondering if the releases Radarr has grabbed in the past are the highest scored releases per the Custom Format scoring and you have 1000+ movies. Manually searching and keeping track of what was searched is tedious and boring. This script helps with that!

## Config File Parameters

* **No quotation marks**

### General

### Radarr

* `radarrApiKey`: Your Radarr API key. Defaults to empty unless I commit my API key lol.
* `radarrCount`: Number of movies to be searched. Defaults to 10.
* `radarrMonitored`: Accepts `true` or `false`. If you want to search monitored movies, set to `true`. If you want to search unmonitored movies, set to `false`. Defaults to `true`.
* `radarrMovieStatus`: Accepts `announced`, `in cinemas`, `released` and `tba`. Defaults to `released`.
* `radarrTagName`: Tag name that will be applied to movies that are searched. If the tag does not exist in Radarr, it will create it.
* `radarrUnattended`: Accepts `true` or `false`. This will make the script run in an infinite loop in case you always want to constantly search your library forever and ever until the end of the Internet. Defaults to `false`
* `radarrUrl`: Radarr URL starting with `http(s)://` and **not** ending in `/`

### Sonarr

* `sonarrApiKey`: Your Sonarr API key. Defaults to empty unless I commit my API key lol.
* `sonarrCount`: Number of series to be searched. Defaults to 5.
* `sonarrMonitored`: Accepts `true` or `false`. If you want to search monitored series, set to `true`. If you want to search unmonitored series, set to `false`. Defaults to `true`.
* `sonarrSeriesStatus`: Accepts any values listed [here](https://github.com/Sonarr/Sonarr/blob/0a2b109a3fe101e260b623d0768240ef8b7a47ae/frontend/src/Components/Filter/Builder/SeriesStatusFilterBuilderRowValue.js#L5-L7). Defaults to empty
* `sonarrTagName`:  Tag name that will be applied to series that are searched. If the tag does not exist in Sonarr, it will create it.
* `sonarrUnattended`: Accepts `true` or `false`. This will make the script run in an infinite loop in case you always want to constantly search your library forever and ever until the end of the Internet. Defaults to `false`
* `sonarrUrl`: Sonarr URL starting with `http(s)://` and **not** ending in `/`

## How To Use

The instructions are for linux, but the concepts for non-linux are the same.

* Clone repo: `git clone "https://github.com/angrycuban13/Scripts.git" "/path/to/repo/clone/location/"`
* Fill in parameters in `upgradinatorr.conf`
* Run script (see below)

## `upgradinatorr.ps1` usage

### One Time

    pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr

#### One Time - Multiple Apps

    pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr,sonarr

### Verbose Output

    pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr -verbose

### Scheduled Crontab

    0 */6 * * *    pwsh /path/to/repo/clone/location/Upgradinatorr/upgradinatorr.ps1 -apps radarr
