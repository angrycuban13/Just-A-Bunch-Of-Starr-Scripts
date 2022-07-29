# README

This script requires you to have Powershell 7, otherwise it will fail.

To install Powershell 7, follow [this link](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2)

## Parameter List

* apiKey = Grab this from `Radarr > Settings > General > Security`
* uri = Radarr URL starting with `http(s)://` and not ending with `/`
* tagName = An **existing** tag in Radarr you wish to tag movies with
* count = Number of movies you wish to manually search for. Be aware of your indexer limits, I'm not responsible if you get banned for hammering their API.
* monitored = Defaults to `$true`. Accepts `$true` or `$false`.
* moviestatus = Defaults to `released` so you aren't searching for movies that are `missing`

## `upgradinatorr.ps1`examples

### Search for *n* movies

    upgradinator.ps1 -apikey "my_api_key" -uri "http://my_radarr_url" -tagname "my_tag_name" -count 1

### Schedule it to run

    0 */6 * * *    pwsh /opt/scripts/upgradinatorr/upgradinatorr.ps1 -apikey "my_api_key" -uri "http://my_radarr_url" -tagname "my_tag_name" -count 1
