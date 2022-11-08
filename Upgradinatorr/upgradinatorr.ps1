<#
.SYNOPSIS
This script will kick off manual search on a random number of movies in Radarr, episodes in Sonarr, and albums in Lidarr, and add a specific tag to those items so they aren't searched again

I'd like to credit @Roxedus and @austinwbest for their guidance and help making this script possible.

.LINK
https://radarr.video/docs/api/#/

.LINK
https://stackoverflow.com/questions/417798/ini-file-parsing-in-powershell

#>

[CmdletBinding(SupportsShouldProcess)]
param (
    # Specify apps
    [Parameter()]
    [string[]]
    $apps
)

if ($PSVersionTable.PSVersion.Major -lt 7) {
    throw 'You need at least Powershell 7 to run this script'
}

$apiVersionRadarr = 'v3'
$apiVersionSonarr = 'v3'
$apiVersionLidarr = 'v1'
function Add-Tag {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $app,
        [Parameter()]
        [array]
        $movies,
        [Parameter()]
        [array]
        $series,
        [Parameter()]
        [array]
        $artist,
        [Parameter()]
        [int]
        $tagId,
        [Parameter()]
        [string[]]
        $url
    )

    if ($app -like '*Radarr*') {
        Invoke-RestMethod -Uri "$($url)/api/$($apiVersionRadarr)/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"movieIds`":[$($movies.id -join ',')],`"tags`":[$tagId],`"applyTags`":`"add`"}" | Out-Null

        if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
            throw 'Failed to get tag list'
        }
    }

    elseif ($app -like '*Sonarr*') {
        Invoke-RestMethod -Uri "$($url)/api/$($apiVersionSonarr)/series/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"seriesIds`":[$($series.id -join ',')],`"tags`":[$tagId],`"applyTags`":`"add`"}" | Out-Null

        if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
            throw 'Failed to get tag list'
        }
    }

    elseif ($app -like '*Lidarr*') {
        Invoke-RestMethod -Uri "$($url)/api/$($apiVersionLidarr)/artist/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"artistIds`":[$($artist.id -join ',')],`"tags`":[$tagId],`"applyTags`":`"add`"}" | Out-Null

        if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
            throw 'Failed to get tag list'
        }
    }
}

function Confirm-ArrResponse {
    [CmdletBinding()]
    param (
        [Parameter()]
        [int]
        $apiStatusCode
    )

    switch -Regex ( $apiStatusCode ) {
        '2\d\d' {
            $true
        }
        302 {
            throw 'Encountered redirect. Are you missing the URL base?'
        }
        400 {
            throw "Invalid Request. Check your application's logs for details"
        }
        401 {
            throw 'Unauthorized. Is APIKey valid?'
        }
        404 {
            throw 'Not Found. Is URL correct?'
        }
        409 {
            throw 'Conflict. Something went wrong'
        }
        500 {
            throw "App responded with Internal Server Error. Check your application's logs for details"
        }
        default {
            throw "Unexpected HTTP status code - $($apiStatusCode)"
        }
    }
}

function Confirm-AppConnectivity {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $app,
        [Parameter()]
        [string]
        $url
    )

    if ($app -like '*Radarr*') {
        $apiVersion = $apiVersionRadarr
    }
    elseif ($app -like '*Sonarr*') {
        $apiVersion = $apiVersionSonarr
    }
    elseif ($app -like '*Lidarr*') {
        $apiVersion = $apiVersionLidarr
    }
    try {
        Invoke-RestMethod -Uri "$($url)/api/$($apiVersion)/system/status" -Method Get -StatusCodeVariable apiStatusCode -Headers $webHeaders | Out-Null
        Write-Verbose "Connectivity to $((Get-Culture).TextInfo.ToTitleCase("$app")) confirmed"
    }
    catch {
        throw "$((Get-Culture).TextInfo.ToTitleCase("$app")) $_."
    }
}

function Confirm-AppURL {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $app,
        [Parameter()]
        [string]
        $url
    )

    if ($url -notmatch 'https?:\/\/') {
        throw "Your URL for $((Get-Culture).TextInfo.ToTitleCase($app)) is not formatted correctly, it must start with http(s)://"
    }
    else {
        Write-Verbose "$((Get-Culture).TextInfo.ToTitleCase("$app")) URL confirmed"
    }
}

function Get-ArrItems {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $app,
        [Parameter()]
        [string]
        $url
    )

    if ($app -like '*Radarr*') {
        $result = Invoke-RestMethod -Uri "$url/api/$($apiVersionRadarr)/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode
    }
    elseif ($app -like '*Sonarr*') {
        $result = Invoke-RestMethod -Uri "$url/api/$($apiVersionSonarr)/series" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode
    }
    elseif ($app -like '*Lidarr*') {
        $result = Invoke-RestMethod -Uri "$url/api/$($apiVersionLidarr)/artist" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode
    }

    if (Confirm-ArrResponse -apiStatusCode $apiStatusCode) {
        $result
    }
    else {
        throw 'Failed to get items'
    }
}
function Get-TagId {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $app,
        [Parameter()]
        [string]
        $tagName,
        [Parameter()]
        [string]
        $url
    )

    if ($app -like '*Radarr*') {
        $apiVersion = $apiVersionRadarr
    }
    elseif ($app -like '*Sonarr*') {
        $apiVersion = $apiVersionSonarr
    }
    elseif ($app -like '*Lidarr*') {
        $apiVersion = $apiVersionLidarr
    }

    $currentTagList = Invoke-RestMethod -Uri "$($url)/api/$($apiVersion)/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

    if (Confirm-ArrResponse($apiStatusCode)) {
        $tagNameId = $currentTagList | Where-Object { $_.label -contains $tagName } | Select-Object -ExpandProperty id

        if ($currentTagList.label -notcontains $tagName) {

            $Body = @{
                'label' = $tagName
            } | ConvertTo-Json


            Invoke-RestMethod -Uri "$($url)/api/$($apiVersion)/tag" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -Body $Body -ContentType 'application/json' | Out-Null

            $updatedTagList = Invoke-RestMethod -Uri "$($url)/api/$($apiVersion)/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

            $tagNameId = $updatedTagList | Where-Object { $_.label -contains $tagName } | Select-Object -ExpandProperty id
        }

        $tagNameId
        Write-Verbose "Tag ID $tagNameId confirmed for $((Get-Culture).TextInfo.ToTitleCase("$app"))"
    }
    else {
        throw 'Failed to get tags'
    }

}

function Read-IniFile {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $file
    )

    $ini = @{}

    # Create a default section if none exist in the file. Like a java prop file.
    $section = 'NO_SECTION'
    $ini[$section] = @{}

    switch -regex -file $file {
        '^\[(.+)\]$' {
            $section = $matches[1].Trim()
            $ini[$section] = @{}
        }
        '^\s*([^#].+?)\s*=\s*(.*)' {
            $name, $value = $matches[1..2]
            # skip comments that start with semicolon:
            if (!($name.StartsWith(';'))) {
                $ini[$section][$name] = $value.Trim()
            }
        }
    }
    $ini
}

function Remove-Tag {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $app,
        [Parameter()]
        [string]
        $url,
        [Parameter()]
        [array]
        $movies,
        [Parameter()]
        [array]
        $series,
        [Parameter()]
        [array]
        $artist,
        [Parameter()]
        [int]
        $tagId
    )

    if ($app -like '*Radarr*') {

        Invoke-RestMethod -Uri "$($url)/api/$($apiVersionRadarr)/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"movieIds`":[$($movies.id -join ',')],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}" | Out-Null
    }
    elseif ($app -like '*Sonarr*') {
        Invoke-RestMethod -Uri "$($url)/api/$($apiVersionSonarr)/series/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"seriesIds`":[$($series.id -join ',')],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}" | Out-Null
    }
    elseif ($app -like '*Lidarr*') {
        Invoke-RestMethod -Uri "$($url)/api/$($apiVersionSonarr)/artist/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"artistIds`":[$($artist.id -join ',')],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}" | Out-Null
    }
    if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
        throw 'Failed to remove tag'
    }
}

function Search-Movie {
    [CmdletBinding()]
    param (
        [Parameter()]
        [array]
        $movie,
        [Parameter()]
        [string]
        $url
    )

    Invoke-RestMethod -Uri "$($url)/api/$($apiVersionRadarr)/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"name`":`"MoviesSearch`",`"movieIds`":[$($movie.id)]}" | Out-Null

    if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
        throw "Failed to search for $($movie.title) with status code $($apiStatusCode)"
    }

}

function Search-Series {
    [CmdletBinding()]
    param (
        [Parameter()]
        [array]
        $series,
        [Parameter()]
        [string]
        $url
    )
    Invoke-RestMethod -Uri "$($url)/api/$($apiVersionSonarr)/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"name`":`"SeriesSearch`",`"seriesId`":$($series.id)}" | Out-Null

    if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
        throw "Failed to search for $($series.title) with status code $($apiStatusCode)"
    }
}

function Search-Artist {
    [CmdletBinding()]
    param (
        [Parameter()]
        [array]
        $artist,
        [Parameter()]
        [string]
        $url
    )
    Invoke-RestMethod -Uri "$($url)/api/$($apiVersionLidarr)/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"name`":`"ArtistSearch`",`"artistId`":$($artist.id)}" | Out-Null

    if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
        throw "Failed to search for $($artist.title) with status code $($apiStatusCode)"
    }
}

function Send-DiscordWebhook {
    [CmdletBinding()]
    param (
        [Parameter()]
        [string]
        $app,
        [Parameter()]
        [string]
        $url
    )
    [System.Collections.ArrayList]$discordEmbedArray = @()
    $color = '15548997'
    $title = 'Upgradinatorr'
    $thumbUrl = 'https://raw.githubusercontent.com/angrycuban13/Scripts/main/Images/powershell.png'
    if ($app -like '*Radarr*') {
        $description = 'No movies left to search!'
    }
    elseif ($app -like '*Sonarr*') {
        $description = 'No series left to search!'
    }
    elseif ($app -like '*Lidarr*') {
        $description = 'No artists left to search!'
    }
    $username = 'Upgradinatorr'
    $thumbnailObject = [PSCustomObject]@{
        url = $thumbUrl
    }

    $embedObject = [PSCustomObject]@{
        color       = $color
        title       = $title
        description = $description
        thumbnail   = $thumbnailObject
    }

    $discordEmbedArray.Add($embedObject)
    $payload = [PSCustomObject]@{
        embeds     = $discordEmbedArray
        username   = $username
        avatar_url = $thumbUrl
    }

    Invoke-RestMethod -Uri $url -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json' | Out-Null
}

if (($apps.GetType()).Name -like 'String*') {
    Write-Verbose 'Array not detected'
    switch -Regex ($apps) {
        ',' {
            Write-Verbose 'Comma detected, splitting values'
            $apps = $apps -split ','
        }
        ' ' {
            Write-Output 'Space detected, splitting values'
            $apps = $apps -split ' '
        }
    }
}

# Specify location of config file.
$configFile = Join-Path -Path $PSScriptRoot -ChildPath upgradinatorr.conf
Write-Verbose "Location for config file is $configFile"

# Read the parameters from the config file.
if (Test-Path $configFile -PathType Leaf) {
    Write-Verbose 'Parsing config file'
    $config = Read-IniFile -File $configFile
}

else {
    throw 'Could not find config file'
}

Write-Verbose 'Config file parsed successfully'

foreach ($app in $apps) {

    switch -Wildcard ($app) {
        'lidarr*' {
            Write-Output 'Valid application specified'
        }
        'whisparr*' {
            throw 'Whisparr is not supported'
        }
        'readarr*' {
            throw 'Readarr is not supported'
        }
        'prowlarr*' {
            throw 'Really? There is nothing for me to search in Prowlarr'
        }
        'sonarr*' {
            Write-Output 'Valid application specified'
        }
        'radarr*' {
            Write-Output 'Valid application specified'
        }
        Default {
            throw 'This error should not be triggered - open a GitHub issue'
        }
    }

    $appConfig = $($config.$($app))
    $appMonitored = $([System.Convert]::ToBoolean($appConfig.'Monitored'))
    $appTitle = $((Get-Culture).TextInfo.ToTitleCase($app))
    $appUrl = $($appConfig.'Url').TrimEnd('/')
    $count = $($appConfig.'Count')
    $logVerbose = $($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent)
    $runUnattended = $([System.Convert]::ToBoolean($appConfig.'Unattended'))
    $tagName = $($appConfig.'TagName')
    $webHeaders = @{
        'x-api-key' = $appConfig.'ApiKey'
    }

    if ($logVerbose) {
        Write-Output 'Verbose logging enabled'
        Confirm-AppURL -App $app -Url $appUrl -Verbose
        Confirm-AppConnectivity -App $app -Url $appUrl -Verbose
        if ($tagName -eq '') {
            throw 'Tag name not detected, please specify a tag'
        }
    }
    else {
        Confirm-AppURL -App $app -Url $appUrl
        Confirm-AppConnectivity -App $app -Url $appUrl
        if ($tagName -eq '') {
            throw 'Tag name not detected, please specify a tag'
        }
    }

    Write-Output "Starting $($appTitle) search"
    Write-Output "Config - URL: $($appUrl)"
    Write-Output "Config - Tag name: $($tagName)"
    Write-Output "Config - Monitored: $($appMonitored)"
    Write-Output "Config - Unattended: $($runUnattended)"
    Write-Output "Config - $((Get-Culture).TextInfo.ToTitleCase($app)) Limit: $($count)"

    if ($logVerbose) {
        Write-Output 'Verbose logging enabled'
        $tagID = Get-TagId -App $app -Url $appUrl -TagName $tagName -Verbose
    }
    else {
        $tagID = Get-TagId -App $app -Url $appUrl -TagName $tagName
    }

    if ($app -like '*radarr*') {
        $allMovies = Get-ArrItems -app $app -url $appUrl

        Write-Verbose "Retrieved a total of $($allMovies.Count) movies"

        $filteredMovies = $allMovies | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appConfig.'MovieStatus' }

        Write-Verbose "Filtered movies down to $($filteredMovies.count) movies"

        if ($filteredMovies.Count -eq 0 -and $runUnattended -ne $false) {
            $moviesWithTag = $allMovies | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appConfig.'MovieStatus' }

            Write-Verbose "Removing tag $tagName from $($moviesWithTag.Count) movies"

            if ($logVerbose) {
                Remove-Tag -App $app -Url $appUrl -Movies $moviesWithTag -tagId $tagID -Verbose
            }

            else {
                Remove-Tag -App $app -Url $appUrl -Movies $moviesWithTag -TagId $tagID
            }

            if ($count -eq 'max') {
                $count = $filteredMovies.count
                Write-Verbose "Radarr count set to max. `nMovie count has been modified to $($filteredMovies.count) movies"
            }

            $randomMovies = Get-Random -InputObject $moviesWithTag -Count $count
            $movieCounter = 0

            Write-Verbose "Adding tag $tagName to $($count) movies"

            if ($logVerbose) {
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url $appUrl -Verbose
            }

            else {
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url $appUrl
            }

            foreach ($movie in $randomMovies) {
                $movieCounter++
                Write-Progress -Activity 'Search in Progress' -PercentComplete (($movieCounter / $count) * 100)

                if ($PSCmdlet.ShouldProcess($movie.title, 'Searching for movie')) {
                    if ($logVerbose) {
                        Search-Movie -Movie $movie -Url $appUrl -Verbose
                    }

                    else {
                        Search-Movie -Movie $movie -Url $appUrl
                    }
                    Write-Output "Manual search kicked off for $($movie.title)"
                }
            }
        }

        elseif ($filteredMovies.Count -eq 0 -and $runUnattended -eq $false) {
            if ($config.General.discordWebhook -ne '') {
                Send-DiscordWebhook -App $app -Url $($config.General.discordWebhook) -Verbose
            }

            else {
                Write-Warning 'No movies left to search'
                Exit 1
            }
        }

        else {
            if ($count -eq 'max') {
                $count = $filteredMovies.count
                Write-Verbose "Radarr count set to max. `nMovie count has been modified to $($filteredMovies.count) movies"
            }
            $randomMovies = Get-Random -InputObject $filteredMovies -Count $count
            $movieCounter = 0

            Write-Verbose "Adding tag $tagName to $($count) movies"
            if ($logVerbose) {
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url $appUrl -Verbose
            }

            else {
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url $appUrl
            }

            foreach ($movie in $randomMovies) {
                $movieCounter++
                Write-Progress -Activity 'Search in Progress' -PercentComplete (($movieCounter / $count) * 100)

                if ($PSCmdlet.ShouldProcess($movie.title, 'Searching for movie')) {
                    if ($logVerbose) {
                        Search-Movie -Movie $movie -Url $appUrl -Verbose
                    }

                    else {
                        Search-Movie -Movie $movie -Url $appUrl
                    }
                    Write-Output "Manual search kicked off for $($movie.title)"
                }
            }
        }
    }

    if ($app -like '*sonarr*') {
        $allSeries = Get-ArrItems -App $app -Url $appUrl

        Write-Verbose "Retrieved a total of $($allSeries.Count) series"

        if ($appConfig.'SeriesStatus' -eq '') {
            $filteredSeries = $allSeries | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appMonitored }
        }

        else {
            $filteredSeries = $allSeries | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appConfig.'SeriesStatus' }
        }

        Write-Verbose "Filtered series down to $($filteredSeries.count) series"

        if ($filteredSeries.Count -eq 0 -and $runUnattended -ne $false) {
            if ($appConfig.'SeriesStatus' -eq '') {
                $seriesWithTag = $allSeries | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $appMonitored }
            }

            else {
                $seriesWithTag = $allSeries | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appConfig.'SeriesStatus' }
            }

            Write-Verbose "Removing tag $tagName from $($seriesWithTag.Count) series"

            if ($logVerbose) {
                Remove-Tag -App $app -Url $appUrl -Series $seriesWithTag -tagId $tagID -Verbose
            }

            else {
                Remove-Tag -App $app -Url $appUrl -Series $seriesWithTag -tagId $tagID
            }

            if ($count -eq 'max') {
                $count = $seriesWithTag.count
                Write-Verbose "$appTitle count set to max. `nSeries count has been modified to $($seriesWithTag.count) series"
            }
            $randomSeries = Get-Random -InputObject $seriesWithTag -Count $count
            $seriesCounter = 0

            Write-Verbose "Adding tag $tagName to $($count) series"
            if ($logVerbose) {
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url $appUrl -Verbose
            }

            else {
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url $appUrl
            }

            foreach ($series in $randomSeries) {
                $seriesCounter++
                Write-Progress -Activity 'Search in Progress' -PercentComplete (($seriesCounter / $count) * 100)

                if ($PSCmdlet.ShouldProcess($series.title, 'Searching for series')) {
                    if ($logVerbose) {
                        Search-Series -Series $series -Url $appUrl -Verbose
                    }

                    else {
                        Search-Series -Series $series -Url $appUrl
                    }
                    Write-Output "Manual search kicked off for $($series.title)"
                }
            }
        }

        elseif ($filteredSeries.Count -eq 0 -and $runUnattended -eq $false) {
            if ($config.General.discordWebhook -ne '') {
                Send-DiscordWebhook -App $app -Url $($config.General.discordWebhook)
            }

            else {
                Write-Warning 'No series left to search'
                Exit 1
            }
        }

        else {
            if ($count -eq 'max') {
                $count = $filteredSeries.count
                Write-Verbose "$appTitle count set to max. `nSeries count has been modified to $($filteredSeries.count) series"
            }
            $randomSeries = Get-Random -InputObject $filteredSeries -Count $count
            $seriesCounter = 0

            Write-Verbose "Adding tag $tagName to $($count) series"
            if ($logVerbose) {
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url $appUrl -Verbose
            }

            else {
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url $appUrl
            }

            foreach ($series in $randomSeries) {
                $seriesCounter++
                Write-Progress -Activity 'Search in Progress' -PercentComplete (($seriesCounter / $count) * 100)

                if ($PSCmdlet.ShouldProcess($series.title, 'Searching for series')) {
                    if ($logVerbose) {
                        Search-Series -Series $series -Url $appUrl -Verbose
                    }

                    else {
                        Search-Series -Series $series -Url $appUrl
                    }
                    Write-Output "Manual search kicked off for $($series.title)"
                }
            }
        }
    }

    if ($app -like '*lidarr*') {
        $allArtists = Get-ArrItems -App $app -Url $appUrl

        Write-Verbose "Retrieved a total of $($allArtists.Count) artists"

        $filteredArtist = $allArtists | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appMonitored }
        Write-Verbose "Filtered artists down to $($filteredArtist.count) artists"

        if ($filteredArtist.Count -eq 0 -and $runUnattended -ne $false) {
            if ($appConfig.'ArtistStatus' -eq '') {
                $artistWithTag = $allArtists | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $appMonitored }
            }

            else {
                $artistWithTag = $allArtists | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appConfig.'ArtistStatus' }
            }

            Write-Verbose "Removing tag $tagName from $($artistWithTag.Count) artists"

            if ($logVerbose) {
                Remove-Tag -App $app -Url $appUrl -Artist $artistWithTag -tagId $tagID -Verbose
            }

            else {
                Remove-Tag -App $app -Url $appUrl -Artist $artistWithTag -tagId $tagID
            }

            if ($count -eq 'max') {
                $count = $artistWithTag.count
                Write-Verbose "$appTitle count set to max. `Artist count has been modified to $($artistWithTag.count) artists"
            }
            $randomArtist = Get-Random -InputObject $artistWithTag -Count $count
            $artistCounter = 0

            Write-Verbose "Adding tag $tagName to $($count) artists"
            if ($logVerbose) {
                Add-Tag -App $app -Artist $randomArtist -TagId $tagID -Url $appUrl -Verbose
            }

            else {
                Add-Tag -App $app -Artist $randomArtist -TagId $tagID -Url $appUrl
            }

            foreach ($artist in $randomArtist) {
                $artistCounter++
                Write-Progress -Activity 'Search in Progress' -PercentComplete (($artistCounter / $count) * 100)

                if ($PSCmdlet.ShouldProcess($artist.title, 'Searching for artists')) {
                    if ($logVerbose) {
                        Search-Artist -Artist $artist -Url $appUrl -Verbose
                    }

                    else {
                        Search-Artist -Artist $artist -Url $appUrl
                    }
                    Write-Output "Manual search kicked off for $($artist.title)"
                }
            }
        }

        elseif ($filteredArtist.Count -eq 0 -and $runUnattended -eq $false) {
            if ($config.General.discordWebhook -ne '') {
                Send-DiscordWebhook -App $app -Url $($config.General.discordWebhook)
            }

            else {
                Write-Warning 'No artists left to search'
                Exit 1
            }
        }

        else {
            if ($count -eq 'max') {
                $count = $filteredArtist.count
                Write-Verbose "$appTitle count set to max. `Artist count has been modified to $($filteredArtist.count) artists"
            }
            $randomArtist = Get-Random -InputObject $filteredArtist -Count $count
            $artistCounter = 0

            Write-Verbose "Adding tag $tagName to $($count) artists"
            if ($logVerbose) {
                Add-Tag -App $app -Artist $randomArtist -TagId $tagID -Url $appUrl -Verbose
            }

            else {
                Add-Tag -App $app -Artist $randomArtist -TagId $tagID -Url $appUrl
            }

            foreach ($artist in $randomArtist) {
                $artistCounter++
                Write-Progress -Activity 'Search in Progress' -PercentComplete (($artistCounter / $count) * 100)

                if ($PSCmdlet.ShouldProcess($artist.title, 'Searching for artists')) {
                    if ($logVerbose) {
                        Search-Artist -Artist $artist -Url $appUrl -Verbose
                    }

                    else {
                        Search-Artist -Artist $artist -Url $appUrl
                    }
                    Write-Output "Manual search kicked off for $($artist.title)"
                }
            }
        }
    }
}
