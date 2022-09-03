# README

This script will grab all your series and select the first 10 on the list. After it will query the `rename` endpoint in Sonarr's API to see which of these series have episodes that need to be renamed. If episodes need to be renamed, it will grab all `episodeFileId` and will send a `RenameFiles` command back to Sonarr and wait for that command to be completed before moving on. Any series that are checked are automatically written in `seriesChecked.txt` which serves as a "cache". In the event, that your whole library is checked, it will clear the contents of that file and start over again.

## Why should I use this script?

* You should use this script if you want to slowly and programatically rename your Sonarr library after a name scheme change.

### Parameters

* `$sonarrApiKey` - Your Sonarr API Key
* `$sonarrUrl` - Your Sonarr URL
* `$seriesToRename` - Number of series you want to check at a time

## `owinenatorr.ps1` usage

* `pwsh owinenatorr.ps1`
* `pwsh owinenatorr.ps1 -Verbose`

### Scheduled

    0 */6 * * *    pwsh /path/to/repo/clone/location/owinenatorr/owinenatorr.ps1
