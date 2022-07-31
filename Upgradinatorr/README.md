# README

Script to manually search *n* items that are not tagged with a specific tag in your - Radarr only for now -  media library. *n* is the number of items this script will search for, this has the added benefit that you don't hammer your indexers and get banned :)

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

`count`: Defaults to 10. Number of items to be searched
`monitored`: Defaults to `$true`. Set to `$false` to only search unmonitored items

### Radarr

`movieStatus`: Defaults to `released`. Accepts any of the movie status options available in Radarr API.
`radarrApiKey`: Your Radarr API key.
`radarrTagName`: Tag you wish to use to tag movies that have already been searched.
`radarrUrl`: Radarr URL starting with `http(s)://` and **not** ending in `/`

## How To Use

* Clone repo
* Fill in parameters in `upgradinatorr.conf`
* Run script

## `upgradinatorr.ps1` usage

### One Time

    upgradinator.ps1 -apps radarr

### Scheduled

    0 */6 * * *    pwsh /path/to/repo/clone/location/upgradinatorr/upgradinatorr.ps1 -apps radarr
