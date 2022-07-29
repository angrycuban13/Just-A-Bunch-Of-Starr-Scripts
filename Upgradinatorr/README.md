# README

This script requires you to have Powershell 7, otherwise it will fail.

To install Powershell 7, follow [this link](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell-on-windows?view=powershell-7.2)

## `upgradinatorr.ps1`examples

### Search for *n* movies

    upgradinator.ps1 -apikey "my_api_key" -uri "http://my_radarr_url" -tagname "my_tag_name" -count 1

### Schedule it to run

    0 */6 * * *    pwsh /opt/scripts/upgradinatorr/upgradinatorr.ps1 -apikey "my_api_key" -uri "http://my_radarr_url" -tagname "my_tag_name" -count 1
