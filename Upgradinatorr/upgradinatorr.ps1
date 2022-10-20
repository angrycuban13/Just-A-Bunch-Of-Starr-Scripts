<#
.SYNOPSIS
This script will kick off manual search on a random number of movies in Radarr and add a specific tag to those movies so they aren't searched again

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

# Import functions
Import-Module $PSScriptRoot\upgradinatorr.psm1 -Force

# Specify location of config file.
$configFile = Join-Path -Path $PSScriptRoot -ChildPath upgradinatorr.conf
Write-Verbose "Location for config file is $configFile"

#Read the parameters from the config file.
if (Test-Path $configFile -PathType Leaf) {

    Write-Verbose 'Parsing config file'
    $config = Read-IniFile -File $configFile
}

else {
    throw 'Could not find config file'
}

Write-Verbose 'Config file parsed successfully'

foreach ($app in $apps) {

    if ($app -like "*lidarr*") {
        throw 'Lidarr is not supported'
    }

    if ($app -like "*whisparr*") {
        throw 'Whisparr is not supported'
    }
    
    if ($app -like "*readarr*") {
        throw 'Readarr is not supported'
    }

    if ($app -like "*prowlarr*") {
        throw 'Really? There is nothing for me to search in Prowlarr.'
    }

    $appconfig = $($config.$($app))
    $webHeaders = @{'x-api-key' = $appconfig.'ApiKey' }
    $aurl = $($appconfig.'Url').TrimEnd('/')
    $tagname = $($appconfig.'TagName')
    $maxcount = $($appconfig.'Count')
    $logVerbose = $($PSCmdlet.MyInvocation.BoundParameters['Verbose'].IsPresent)
    $apptitle = $((Get-Culture).TextInfo.ToTitleCase("$app"))
    $appmonitored = $([System.Convert]::ToBoolean($appconfig.'Monitored'))
    $rununattended = $([System.Convert]::ToBoolean($appconfig.'Unattended'))
    # Create a global variable so they can be used by the functions
    $global:webHeaders = $webHeaders

    Write-Output "Starting $apptitle search"
    Write-Output "Config - URL: $aurl"
    Write-Output "Config - TagName: $tagname"
    Write-Output "Config - Monitored: $appmonitored"
    Write-Output "Config - Unattended: $rununattended"
    Write-Output "Config - Limit: $maxcount"
    Write-Output "Config - TagName: $tagname"

    if ($logVerbose) {
        Write-Output 'Verbose logging enabled'
        Confirm-AppURL -App $app -Url $aurl -Verbose
        Confirm-AppConnectivity -App $app -Url $aurl -Verbose
    }
    else {
        Confirm-AppURL -App $app -Url $aurl
        Confirm-AppConnectivity -App $app -Url $aurl
    }

    $tagID = Get-TagId -App $app -Url $aurl -TagName $tagname

    Write-Verbose "Tag ID $tagID confirmed for $appTitle"

    if ($app -like "*radarr*") {

        $allMovies = Get-ArrItems($app, $aurl)

        Write-Verbose "Retrieved a total of $($allmovies.Count) movies"

        $filteredMovies = $allMovies | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appmonitored -and $_.status -eq $appconfig.'MovieStatus' }

        Write-Verbose "Filtered movies down to $($filteredMovies.count) movies"

        if ($filteredMovies.Count -eq 0 -and $rununattended -ne $false) {
            $moviesWithTag = $allMovies | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $appmonitored -and $_.status -eq $appconfig.'MovieStatus' }

            Write-Verbose "Removing tag $tagname from $($moviesWithTag.Count) movies"

            if ($logVerbose) {
                Remove-Tag -App $app -Url $aurl -movies $moviesWithTag -tagId $tagID -Verbose
            }

            else {
                Remove-Tag -App $app -Url $aurl -movies $moviesWithTag -tagId $tagID
            }

            $allMovies = Get-ArrItems($app, $aurl)

            $newFilteredMovies = $allMovies | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appmonitored -and $_.status -eq $appconfig.'MovieStatus' }

            if ($appconfig.'Count' -eq 'max') {
                $maxcount = $newFilteredMovies.count
                Write-Verbose "$appTitle count set to max. `nMovie count has been modified to $($newFilteredMovies.count) movies"
            }
            $randomMovies = Get-Random -InputObject $newFilteredMovies -Count $appconfig.'Count'
            $movieCounter = 0

            Write-Verbose "Adding tag $tagname to $($maxcount) movies"
            if ($logVerbose) {
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url $aurl -Verbose
            }
            else {
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url $aurl 
            }

            foreach ($movie in $randomMovies) {
                $movieCounter++
                Write-Progress -Activity 'Search in Progress' -PercentComplete (($movieCounter / $maxcount) * 100)

                if ($PSCmdlet.ShouldProcess($movie.title, 'Searching for movie')) {
                    if ($logVerbose) {
                        Search-Movies -Movie $movie -Url $aurl -Verbose
                    }
                    else {
                        Search-Movies -Movie $movie -Url $aurl
                    }
                    Write-Output "Manual search kicked off for $($movie.title)"
                }
            }
        }

        elseif ($filteredMovies.Count -eq 0 -and $rununattended -eq $false) {
            if ($config.General.discordWebhook -ne '') {
                Send-DiscordWebhook -App $app -Url $config.General.discordWebhook -Verbose
            }

            else {
                throw 'No movies left to search'
            }        
        }

        else {
            if ($maxcount -eq 'max') {
                $maxcount = $filteredMovies.count
                Write-Verbose "Radarr count set to max. `nMovie count has been modified to $($filteredMovies.count) movies"
            }
            $randomMovies = Get-Random -InputObject $filteredMovies -Count $maxcount
            $movieCounter = 0

            Write-Verbose "Adding tag $tagname to $($maxcount) movies"
            if ($logVerbose) {
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url $aurl -Verbose
            }

            else {
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url $aurl
            }

            foreach ($movie in $randomMovies) {
                $movieCounter++
                Write-Progress -Activity 'Search in Progress' -PercentComplete (($movieCounter / $maxcount) * 100)

                if ($PSCmdlet.ShouldProcess($movie.title, 'Searching for movie')) {
                    if ($logVerbose) {
                        Search-Movies -Movie $movie -Url $aurl -Verbose
                    }

                    else {
                        Search-Movies -Movie $movie -Url $aurl
                    }
                    Write-Output "Manual search kicked off for $($movie.title)"
                }
            }
        }
    }

    if ($app -like "*sonarr*") {

        $allSeries = Get-ArrItems($app, $aurl)

        Write-Verbose "Retrieved a total of $($allSeries.Count) series"

        if ($appconfig.'SeriesStatus' -eq '') {
            $filteredSeries = $allSeries | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appmonitored }
        }

        else {
            $filteredSeries = $allSeries | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appmonitored -and $_.status -eq $appconfig.'SeriesStatus' }
        }

        Write-Verbose "Filtered series down to $($filteredSeries.count) series"

        if ($filteredSeries.Count -eq 0 -and $rununattended -ne $false) {

            if ($appconfig.'SeriesStatus' -eq '') {
                $filteredSeriesWithTag = $allSeries | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $appmonitored }
            }

            else {
                $filteredSeriesWithTag = $allSeries | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $appmonitored -and $_.status -eq $appconfig.'SeriesStatus' }
            }

            Write-Verbose "Removing tag $tagname from $($filteredSeriesWithTag.Count) series"

            if ($logVerbose) {
                Remove-Tag -App $app -Url $aurl -Series $filteredSeriesWithTag -tagId $tagID -Verbose
            }

            else {
                Remove-Tag -App $app -Url $aurl -Series $filteredSeriesWithTag -tagId $tagID
            }

            $allSeries = Get-ArrItems($app, $aurl)

            if ($appconfig.'SeriesStatus' -eq '') {
                $newFilteredSeries = $allSeries | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appmonitored }
            }

            else {
                $newFilteredSeries = $allSeries | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $appmonitored -and $_.status -eq $appconfig.'SeriesStatus' }
            }

            if ($appconfig.'Count' -eq 'max') {
                $appconfig.'Count' = $newFilteredSeries.count
                Write-Verbose "$appTitle count set to max. `nSeries count has been modified to $($newFilteredSeries.count) movies"
            }
            $randomSeries = Get-Random -InputObject $newFilteredSeries -Count $appconfig.'Count'
            $seriesCounter = 0

            Write-Verbose "Adding tag $tagname to $($maxcount) series"
            if ($logVerbose) {
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url $aurl -Verbose
            }

            else {
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url $aurl
            }

            foreach ($series in $randomSeries) {
                $seriesCounter++
                Write-Progress -Activity 'Search in Progress' -PercentComplete (($seriesCounter / $maxcount) * 100)

                if ($PSCmdlet.ShouldProcess($series.title, 'Searching for series')) {
                    if ($logVerbose) {
                        Search-Series -Series $series -Url $aurl -Verbose
                    }
                    else {
                        Search-Series -Series $series -Url $aurl
                    }
                    Write-Output "Manual search kicked off for $($series.title)"
                }
            }
        }

        elseif ($filteredSeries.Count -eq 0 -and $rununattended -eq $false) {
            if ($config.General.discordWebhook -ne '') {
                Send-DiscordWebhook -App $app -Url $config.General.discordWebhook
            }

            else {
                throw 'No series left to search'
            }
        }

        else {
            if ($appconfig.'Count' -eq 'max') {
                $appconfig.'Count' = $filteredSeries.count
                Write-Verbose "$appTitle count set to max. `nSeries count has been modified to $($filteredSeries.count) series"
            }
            $randomSeries = Get-Random -InputObject $filteredSeries -Count $appconfig.'Count'
            $seriesCounter = 0

            Write-Verbose "Adding tag $tagname to $($maxcount) series"
            if ($logVerbose) {
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url $aurl -Verbose
            }

            else {
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url $aurl
            }

            foreach ($series in $randomSeries) {
                $seriesCounter++
                Write-Progress -Activity 'Search in Progress' -PercentComplete (($seriesCounter / $maxcount) * 100)

                if ($PSCmdlet.ShouldProcess($series.title, 'Searching for series')) {
                    if ($logVerbose) {
                        Search-Series -Series $series -Url $aurl -Verbose
                    }

                    else {
                        Search-Series -Series $series -Url $aurl
                    }
                    Write-Output "Manual search kicked off for $($series.title)"
                }
            }
        }
    }
}
