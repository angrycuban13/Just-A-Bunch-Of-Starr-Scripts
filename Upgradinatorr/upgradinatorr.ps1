<#
.SYNOPSIS
This script will kick off manual search on a random number of movies in Radarr and add a specific tag to those movies so they aren"t searched again

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
    throw "You need at least Powershell 7 to run this script"
}

$api_version_radarr = "v3"
$api_version_sonarr = "v3"
function Add-Tag {
    [CmdletBinding()]
    param (
        $app,
        $movies,
        $series,
        $tagId,
        $url
    )

    if ($app -like "*Radarr*") {
        Invoke-RestMethod -Uri "$($url)/api/$($api_version_radarr)/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movies.ID -join ",")],`"tags`":[$tagId],`"applyTags`":`"add`"}" | Out-Null

        if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
            throw "Failed to get tag list"
        }
    }

    elseif ($app -like "*Sonarr*") {
        Invoke-RestMethod -Uri "$($url)/api/$($api_version_sonarr)/series/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"seriesIds`":[$($series.ID -join ",")],`"tags`":[$tagId],`"applyTags`":`"add`"}" | Out-Null

        if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
            throw "Failed to get tag list"
        }
    }
}

function Confirm-ArrResponse {
    [CmdletBinding()]
    param (
        $apiStatusCode
    )

    switch -Regex ( $apiStatusCode ) {
        "2\d\d" {
            $true
        }
        302 {
            throw "Encountered redirect. Are you missing a urlbase?"
        }
        400 {
            throw "Invalid Request. Check your application's logs for details"
        }
        401 {
            throw "Unauthorized. Is APIKey valid?"
        }
        404 {
            throw "Not Found. Is URL correct?"
        }
        409 {
            throw "Conflict. Something went wrong"
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
        $app,
        $url
    )

    if ($app -like "*Radarr*") {
        $apiversion = $api_version_radarr
    }
    elseif ($app -like "*Sonarr*") {
        $apiversion = $api_version_sonarr
    }
    try {
        Invoke-RestMethod -Uri "$($url)/api/$($apiversion)/system/status" -Method Get -StatusCodeVariable apiStatusCode -Headers $webHeaders | Out-Null
        Write-Verbose "Connectivity to $((Get-Culture).TextInfo.ToTitleCase("$app")) confirmed"
    }
    catch {
        throw "$((Get-Culture).TextInfo.ToTitleCase("$app")) $_."
    }
}

function Confirm-AppURL {
    [CmdletBinding()]
    param (
        $app,
        $url
    )

    if ($url -notmatch "https?:\/\/") {
        throw "Your URL for $((Get-Culture).TextInfo.ToTitleCase($app)) is not formatted correctly, it must start with http(s)://"
    }
    else {
        Write-Verbose "$((Get-Culture).TextInfo.ToTitleCase("$app")) URL confirmed"
    }
}

function Get-ArrItems {
    [CmdletBinding()]
    param (
        $app,
        $url
    )

    if ($app -like "*Radarr*") {
        $result = Invoke-RestMethod -Uri "$url/api/$($api_version_radarr)/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode
    }
    elseif ($app -like "*Sonarr*") {
        $result = Invoke-RestMethod -Uri "$url/api/$($api_version_sonarr)/series" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode
    }

    if (Confirm-ArrResponse -apiStatusCode $apiStatusCode) {
        $result
    }
    else {
        throw "Failed to get items"
    }
}
function Get-TagId {
    [CmdletBinding()]
    param (
        $app,
        $tagName,
        $url
    )

    if ($app -like "*Radarr*") {
        $apiversion = $api_version_radarr
    }
    elseif ($app -like "*Sonarr*") {
        $apiversion = $api_version_sonarr
    }

    $currentTagList = Invoke-RestMethod -Uri "$($url)/api/$($apiversion)/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

    if (Confirm-ArrResponse($apiStatusCode)) {
        $tagNameId = $currentTagList | Where-Object { $_.label -contains $tagName } | Select-Object -ExpandProperty id

        if ($currentTagList.label -notcontains $tagName) {

            $Body = @{
                "label" = $tagName
            } | ConvertTo-Json

            Invoke-RestMethod -Uri "$($url)/api/$($apiversion)//tag" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -Body $Body -ContentType "application/json" | Out-Null

            $updatedTagList = Invoke-RestMethod -Uri "$($url)/api/$($apiversion)//tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

            $tagNameId = $updatedTagList | Where-Object { $_.label -contains $tagName } | Select-Object -ExpandProperty id
        }

        $tagNameId
        Write-Verbose "Tag ID $tagNameId confirmed for $((Get-Culture).TextInfo.ToTitleCase("$app"))"
    }
    else {
        throw "Failed to get tags"
    }

}

function Get-QualityProfile {
    [CmdletBinding()]
    param (
        $app,
        [string[]]$profileName,
        $url
    )

    if ($app -like "*Radarr*") {
        $apiversion = $api_version_radarr
    }
    elseif ($app -like "*Sonarr*") {
        $apiversion = $api_version_sonarr
    }

    $qualityProfiles = Invoke-RestMethod -Uri "$($url)/api/$($apiversion)/qualityprofile" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

    if (Confirm-ArrResponse($apiStatusCode)) {
        $qualityProfilesIds = $qualityProfiles | Where-Object {$_.name -in $profileName} | Select-Object -ExpandProperty id
        $qualityProfilesIds
    }
    else {
        throw "Failed to get quality profiles"
    }
}
function Read-IniFile {
    [CmdletBinding()]
    param (
        $file
    )

    $ini = @{}

    # Create a default section if none exist in the file. Like a java prop file.
    $section = "NO_SECTION"
    $ini[$section] = @{}

    switch -regex -file $file {
        "^\[(.+)\]$" {
            $section = $matches[1].Trim()
            $ini[$section] = @{}
        }
        "^\s*([^#].+?)\s*=\s*(.*)" {
            $name, $value = $matches[1..2]
            # skip comments that start with semicolon:
            if (!($name.StartsWith(";"))) {
                $ini[$section][$name] = $value.Trim()
            }
        }
    }
    $ini
}

function Remove-Tag {
    [CmdletBinding()]
    param (
        $app,
        $url,
        $movies,
        $series,
        $tagId
    )

    if ($app -like "*Radarr*") {
        Invoke-RestMethod -Uri "$($url)/api/$($api_version_radarr)/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movies.id -join ",")],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}" | Out-Null
    }

    elseif ($app -like "*Sonarr*") {
        Invoke-RestMethod -Uri "$($url)/api/$($api_version_sonarr)/series/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"seriesIds`":[$($series.id -join ",")],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}" | Out-Null
    }
    if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
        throw "Failed to remove tag"
    }
}

function Search-Movies {
    [CmdletBinding()]
    param (
        $movie,
        $url
    )

    Invoke-RestMethod -Uri "$($url)/api/$($api_version_radarr)/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"name`":`"MoviesSearch`",`"movieIds`":[$($movie.ID)]}" | Out-Null

    if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
        throw "Failed to search for $($movie.title) with statuscode $apiStatusCode"
    }

}

function Search-Series {
    [CmdletBinding()]
    param (
        $series,
        $url
    )
    Invoke-RestMethod -Uri "$($url)/api/$($api_version_sonarr)/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"name`":`"SeriesSearch`",`"seriesId`":$($series.ID)}" | Out-Null

    if (-Not (Confirm-ArrResponse -apiStatusCode $apiStatusCode)) {
        throw "Failed to search for $($series.title) with statuscode $apiStatusCode"
    }
}

function Send-DiscordWebhook {
    [CmdletBinding()]
    param (
        $app,
        $url
    )
    [System.Collections.ArrayList]$discordEmbedArray = @()
    $color = "15548997"
    $title = "Upgradinatorr"
    $thumburl = "https://raw.githubusercontent.com/angrycuban13/Scripts/main/Images/powershell.png"
    if ($app -like "*Radarr*") {
        $description = "No movies left to search!"
    }
    elseif ($app -like "*Sonarr*") {
        $description = "No series left to search!"
    }
    $username = "Upgradinatorr"
    $thumbnailObject = [PSCustomObject]@{
        url = $thumburl
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
        avatar_url = $thumburl
    }

    Invoke-RestMethod -Uri $url -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType "application/json"
}

if (($apps.GetType()).Name -like "String*"){
    Write-Verbose "Array not detected"
    switch -Regex ($apps){
        ',' {
            Write-Verbose "Comma detected, splitting values"
            $apps = $apps -split ","
        }
        " " {
            Write-Output "Space detected, splitting values"
            $apps = $apps -split " "
        }
    }
}

# Specify location of config file.
$configFile = Join-Path -Path $PSScriptRoot -ChildPath upgradinatorr.conf
Write-Verbose "Location for config file is $configFile"

# Read the parameters from the config file.
if (Test-Path $configFile -PathType Leaf) {
    Write-Verbose "Parsing config file"
    $config = Read-IniFile -File $configFile
}

else {
    throw "Could not find config file"
}

Write-Verbose "Config file parsed successfully"

foreach ($app in $apps) {

    switch -Wildcard ($app) {
        "lidarr*" {
            throw "Lidarr is not supported"
        }
        "whisparr*" {
            throw "Whisparr is not supported"
        }
        "readarr*" {
            throw "Readarr is not supported"
        }
        "prowlarr*" {
            throw "Really? There is nothing for me to search in Prowlarr"
        }
        "sonarr*" {
            Write-Output "Valid application specified"
        }
        "radarr*" {
            Write-Output "Valid application specified"
        }
        Default {
            throw "This error should not be triggered - open a GitHub issue"
        }
    }

    $appConfig = $($config.$($app))
    $appMonitored = $([System.Convert]::ToBoolean($appConfig."Monitored"))
    $appTitle = $((Get-Culture).TextInfo.ToTitleCase($app))
    $appUrl = $($appConfig."Url").TrimEnd("/")
    $count = $($appConfig."Count")
    $logVerbose = $($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent)
    $runUnattended = $([System.Convert]::ToBoolean($appConfig."Unattended"))
    $tagName = $($appConfig."TagName")
    $webHeaders = @{
        "x-api-key" = $appconfig."ApiKey"
    }
    if ($($appConfig."ProfileName") -ne ""){
        $profileName = $($appConfig."ProfileName") -split ","
    }
    if ($($appConfig."TagIgnore") -ne ""){
        $tagIgnore = $($appConfig."TagIgnore") -split ","
    }

    if ($logVerbose) {
        Write-Output "Verbose logging enabled"
        Confirm-AppURL -App $app -Url $appUrl -Verbose
        Confirm-AppConnectivity -App $app -Url $appUrl -Verbose
        if ($tagName -eq ""){
            throw "Tag name not detected, please specify a tag"
        }
    }
    else {
        Confirm-AppURL -App $app -Url $appUrl
        Confirm-AppConnectivity -App $app -Url $appUrl
        if ($tagName -eq ""){
            throw "Tag name not detected, please specify a tag"
        }
    }

    Write-Output "Starting $($appTitle) search"
    Write-Output "Config - URL: $($appUrl)"
    Write-Output "Config - Monitored: $($appMonitored)"
    Write-Output "Config - Unattended: $($runUnattended)"
    Write-Output "Config - $((Get-Culture).TextInfo.ToTitleCase($app)) Limit: $($count)"
    switch ($profileName){
        $null {
            Write-Warning "Config - Profile: No profile specified"
        }
        {$profileName.count -eq 1} {
            Write-Output "Config - Profile: $profileName"
        }
    }
    if ($profileName.count -gt 1){
        Write-Output "Config - Profile: $($profileName -join ", ")"
    }
    Write-Output "Config - Tag name: $($tagName)"
    switch ($tagIgnore){
        $null {
            Write-Warning "Config - Tag ignore list: No tag blacklist specified"
        }
        {$tagIgnore.count -eq 1} {
            Write-Output "Config - Tag ignore list: $tagIgnore"
        }
    }
    if ($tagIgnore.count -gt 1){
            Write-Output "Config - Tag ignore list: $($tagIgnore -join ", ")"
    }

    if ($null -ne $profileName){
        $qualityProfileId = Get-QualityProfile -App $app -Url $appUrl -ProfileName $profileName
        Write-Output "Quality Profile IDs $($qualityProfileId -join ", ") confirmed for $appTitle"
    }

    $tagID = Get-TagId -App $app -Url $appUrl -TagName $tagName

    Write-Verbose "Tag ID $tagID confirmed for $appTitle"

    if ($app -like "*radarr*") {
        $allMovies = Get-ArrItems -app $app -url $appUrl
        $allMovies | Select -First 1

        Write-Output "Retrieved a total of $($allmovies.Count) movies"

        if ($null -ne $profileName ) {
            $filteredMovies = $allMovies | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appconfig."MovieStatus" -and $_.qualityProfileId -notin $qualityProfileId}
        }
        elseif ($null -ne $tagIgnore) {
            //TODO
        }
        elseif (($null -ne $tagIgnore) -and ($null -ne $profileName)){
            //TODO

        }
        elseif (($null -eq $profileName) -and ($null -eq $tagIgnore)){
            $filteredMovies = $allMovies | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appconfig."MovieStatus"}
        }

        Write-Output "Filtered movies down to $($filteredMovies.count) movies"

        if ($filteredMovies.Count -eq 0 -and $runUnattended -ne $false) {
            $moviesWithTag = $allMovies | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appconfig."MovieStatus" }

            Write-Verbose "Removing tag $tagName from $($moviesWithTag.Count) movies"

            if ($logVerbose) {
                Remove-Tag -App $app -Url $appUrl -movies $moviesWithTag -tagId $tagID -Verbose
            }

            else {
                Remove-Tag -App $app -Url $appUrl -movies $moviesWithTag -tagId $tagID
            }

            $allMovies = Get-ArrItems -app $app -url $appUrl

            $newFilteredMovies = $allMovies | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appconfig."MovieStatus" }

            if ($appconfig."Count" -eq "max") {
                $count = $newFilteredMovies.count
                Write-Verbose "$appTitle count set to max. `nMovie count has been modified to $($newFilteredMovies.count) movies"
            }
            $randomMovies = Get-Random -InputObject $newFilteredMovies -Count $appconfig."Count"
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
                Write-Progress -Activity "Search in Progress" -PercentComplete (($movieCounter / $count) * 100)

                if ($PSCmdlet.ShouldProcess($movie.title, "Searching for movie")) {
                    if ($logVerbose) {
                        Search-Movies -Movie $movie -Url $appUrl -Verbose
                    }
                    else {
                        Search-Movies -Movie $movie -Url $appUrl
                    }
                    Write-Output "Manual search kicked off for $($movie.title)"
                }
            }
        }

        elseif ($filteredMovies.Count -eq 0 -and $runUnattended -eq $false) {
            if ($config.General.discordWebhook -ne "") {
                Send-DiscordWebhook -App $app -Url $config.General.discordWebhook -Verbose
            }

            else {
                throw "No movies left to search"
            }
        }

        else {
            if ($count -eq "max") {
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

            <#foreach ($movie in $randomMovies) {
                $movieCounter++
                Write-Progress -Activity "Search in Progress" -PercentComplete (($movieCounter / $count) * 100)

                if ($PSCmdlet.ShouldProcess($movie.title, "Searching for movie")) {
                    if ($logVerbose) {
                        Search-Movies -Movie $movie -Url $appUrl -Verbose
                    }

                    else {
                        Search-Movies -Movie $movie -Url $appUrl
                    }
                    Write-Output "Manual search kicked off for $($movie.title)"
                }
            }#>
        }
    }

    if ($app -like "*sonarr*") {
        $allSeries = Get-ArrItems -app $app -url $appUrl

        Write-Verbose "Retrieved a total of $($allSeries.Count) series"

        if ($appconfig."SeriesStatus" -eq "") {
            $filteredSeries = $allSeries | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appMonitored }
        }

        else {
            $filteredSeries = $allSeries | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appconfig."SeriesStatus" }
        }

        Write-Verbose "Filtered series down to $($filteredSeries.count) series"

        if ($filteredSeries.Count -eq 0 -and $runUnattended -ne $false) {
            if ($appconfig."SeriesStatus" -eq "") {
                $filteredSeriesWithTag = $allSeries | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $appMonitored }
            }

            else {
                $filteredSeriesWithTag = $allSeries | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appconfig."SeriesStatus" }
            }

            Write-Verbose "Removing tag $tagName from $($filteredSeriesWithTag.Count) series"

            if ($logVerbose) {
                Remove-Tag -App $app -Url $appUrl -Series $filteredSeriesWithTag -tagId $tagID -Verbose
            }

            else {
                Remove-Tag -App $app -Url $appUrl -Series $filteredSeriesWithTag -tagId $tagID
            }

            $allSeries = Get-ArrItems -app $app -url $appUrl

            if ($appconfig."SeriesStatus" -eq "") {
                $newFilteredSeries = $allSeries | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appMonitored }
            }

            else {
                $newFilteredSeries = $allSeries | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appMonitored -and $_.status -eq $appconfig."SeriesStatus" }
            }

            if ($appconfig."Count" -eq "max") {
                $appconfig."Count" = $newFilteredSeries.count
                Write-Verbose "$appTitle count set to max. `nSeries count has been modified to $($newFilteredSeries.count) movies"
            }
            $randomSeries = Get-Random -InputObject $newFilteredSeries -Count $appconfig."Count"
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
                Write-Progress -Activity "Search in Progress" -PercentComplete (($seriesCounter / $count) * 100)

                if ($PSCmdlet.ShouldProcess($series.title, "Searching for series")) {
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
            if ($config.General.discordWebhook -ne "") {
                Send-DiscordWebhook -App $app -Url $config.General.discordWebhook
            }

            else {
                throw "No series left to search"
            }
        }

        else {
            if ($appconfig."Count" -eq "max") {
                $appconfig."Count" = $filteredSeries.count
                Write-Verbose "$appTitle count set to max. `nSeries count has been modified to $($filteredSeries.count) series"
            }
            $randomSeries = Get-Random -InputObject $filteredSeries -Count $appconfig."Count"
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
                Write-Progress -Activity "Search in Progress" -PercentComplete (($seriesCounter / $count) * 100)

                if ($PSCmdlet.ShouldProcess($series.title, "Searching for series")) {
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
}
