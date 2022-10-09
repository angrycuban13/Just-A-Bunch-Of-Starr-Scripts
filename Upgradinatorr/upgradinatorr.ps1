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

if ($PSVersionTable.PSVersion.Major -lt 7){
    throw "You need at least Powershell 7 to run this script"
}

# Import functions
Import-Module $PSScriptRoot\upgradinatorr.psm1 -Force

# Specify location of config file.
$configFile = Join-Path -Path $PSScriptRoot -ChildPath upgradinatorr.conf
Write-Verbose "Location for config file is $configFile"

#Read the parameters from the config file.
if (Test-Path  $configFile -PathType Leaf){

    Write-Verbose "Parsing config file"
    $config = Read-IniFile -File $configFile
}

else {
    throw "Could not find config file"
}

Write-Verbose "Config file parsed successfully"


foreach ($app in $apps){
    $webHeaders = @{
        "x-api-key" = $config.$($app)."$($app)ApiKey"
    }

    #Create a global variable so they can be used by the functions
    $global:webHeaders = $webHeaders

    if ($app -eq "radarr"){
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
            Confirm-AppURL -App $app -Url $($config.($app)."$($app)Url") -Verbose
            Confirm-AppConnectivity -App $app -Url $($config.($app)."$($app)Url") -Verbose
        }

        else {
        Confirm-AppURL -App $app -Url $($config.($app)."$($app)Url") -Verbose
        Confirm-AppConnectivity -App $app -Url $($config.($app)."$($app)Url") -Verbose
        }

        $tagID = Get-TagId -App $app -Url $($config.($app)."$($app)Url") -TagName $($config.$($app)."$($app)TagName")

        Write-Verbose "Tag ID $tagID confirmed for $((Get-Culture).TextInfo.ToTitleCase("$app"))"

        $allMovies = Invoke-RestMethod -Uri "$($config.Radarr.radarrUrl)/api/v3/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to get movie list"
        }

        Write-Verbose "Retrieved a total of $($allmovies.Count) movies"

        $filteredMovies = $allMovies | Where-Object {$_.tags -notcontains $tagId -and $_.monitored -eq ([System.Convert]::ToBoolean($config.$($app)."$($app)Monitored")) -and $_.status -eq $config.Radarr.radarrMovieStatus}

        Write-Verbose "Filtered movies down to $($filteredMovies.count) movies"

        if ($filteredMovies.Count -eq 0 -and ([System.Convert]::ToBoolean($config.Radarr.radarrUnattended)) -ne $false){
            $moviesWithTag = $allMovies | Where-Object {$_.tags -contains $tagId -and $_.monitored -eq ([System.Convert]::ToBoolean($config.Radarr.radarrMonitored)) -and $_.status -eq $config.Radarr.radarrMovieStatus}

            Write-Verbose "Removing tag $($config.$($app)."$($app)TagName") from $($moviesWithTag.Count) movies"

            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                Remove-Tag -App $app -Url "$($config.($app)."$($app)Url")" -movies $moviesWithTag -tagId $tagID -Verbose
            }

            else {
                Remove-Tag -App $app -Url "$($config.($app)."$($app)Url")" -movies $moviesWithTag -tagId $tagID -Verbose
            }

            $allMovies = Invoke-RestMethod -Uri "$($config.Radarr.radarrUrl)/api/v3/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

            $newFilteredMovies = $allMovies | Where-Object {$_.tags -notcontains $tagId -and $_.monitored -eq ([System.Convert]::ToBoolean($config.Radarr.radarrMonitored)) -and $_.status -eq $config.Radarr.radarrMovieStatus}

            if ($config.$($app)."$($app)Count" -eq "max"){
                $config.($app)."$($app)Count" = $newFilteredMovies.count
                Write-Verbose "$((Get-Culture).TextInfo.ToTitleCase("$app")) count set to max. `nMovie count has been modified to $($newFilteredMovies.count) movies"
            }
            $randomMovies = Get-Random -InputObject $newFilteredMovies -Count $config.$($app)."$($app)Count"
            $movieCounter = 0

            Write-Verbose "Adding tag $($config.Radarr.radarrTagName) to $($config.Radarr.radarrCount) movies"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url "$($config.($app)."$($app)Url")" -Verbose
            }
            else {
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url "$($config.($app)."$($app)Url")"
            }

            foreach ($movie in $randomMovies) {
                $movieCounter++
                Write-Progress -Activity "Search in Progress" -PercentComplete (($movieCounter / $config.Radarr.radarrCount) * 100)

                if ($PSCmdlet.ShouldProcess($movie.title, "Searching for movie")){
                    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                        Search-Movies -Movie $movie -Url "$($config.($app)."$($app)Url")" -Verbose
                    }
                    else{
                        Search-Movies -Movie $movie -Url "$($config.($app)."$($app)Url")"
                    }
                    Write-Output "Manual search kicked off for $($movie.title)"
                }
            }
        }

        elseif ($filteredMovies.Count -eq 0 -and ([System.Convert]::ToBoolean($config.($app)."$($app)Unattended")) -eq $false){
            if ($config.General.discordWebhook -ne ""){
                Send-DiscordWebhook -App $app -Url $config.General.discordWebhook -Verbose
            }

            else{
                throw "No movies left to search"
            }        }

        else {
            if ($config.($app)."$($app)Count" -eq "max"){
                $config.($app)."$($app)Count" = $filteredMovies.count
                Write-Verbose "Radarr count set to max. `nMovie count has been modified to $($filteredMovies.count) movies"
            }
            $randomMovies = Get-Random -InputObject $filteredMovies -Count $config.($app)."$($app)Count"
            $movieCounter = 0

            Write-Verbose "Adding tag $($config.$($app)."$($app)TagName") to $($config.($app)."$($app)Count") movies"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url "$($config.($app)."$($app)Url")" -Verbose
            }

            else {
                Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url "$($config.($app)."$($app)Url")"
            }

            foreach ($movie in $randomMovies) {
                $movieCounter++
                Write-Progress -Activity "Search in Progress" -PercentComplete (($movieCounter / $config.Radarr.radarrCount) * 100)

                if ($PSCmdlet.ShouldProcess($movie.title, "Searching for movie")){
                    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                        Search-Movies -Movie $movie -Url "$($config.($app)."$($app)Url")" -Verbose
                    }

                    else{
                        Search-Movies -Movie $movie -Url "$($config.($app)."$($app)Url")"
                    }
                    Write-Output "Manual search kicked off for $($movie.title)"
                }
            }
        }
    }

    if  ($app -eq "sonarr"){
        if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
            Confirm-AppURL -App $app -Url $($config.($app)."$($app)Url") -Verbose
            Confirm-AppConnectivity -App $app -Url $($config.($app)."$($app)Url") -Verbose
        }

        else {
        Confirm-AppURL -App $app -Url $($config.($app)."$($app)Url") -Verbose
        Confirm-AppConnectivity -App $app -Url $($config.($app)."$($app)Url") -Verbose
        }

        $tagID = Get-TagId -App $app -Url $($config.($app)."$($app)Url") -TagName $($config.$($app)."$($app)TagName") -Verbose

        $allSeries = Invoke-RestMethod -Uri "$($config.Sonarr.sonarrUrl)/api/v3/series" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to get movie list"
        }

        Write-Verbose "Retrieved a total of $($allSeries.Count) series"

        if ($config.Sonarr.sonarrSeriesStatus -eq ""){
            $filteredSeries = $allSeries | Where-Object {$_.tags -notcontains $tagId -and $_.monitored -eq ([System.Convert]::ToBoolean($config.$($app)."$($app)Monitored"))}
        }

        else {
            $filteredSeries = $allSeries | Where-Object {$_.tags -notcontains $tagId -and $_.monitored -eq ([System.Convert]::ToBoolean($config.$($app)."$($app)Monitored")) -and $_.status -eq $config.Sonarr.sonarrSeriesStatus}
        }

        Write-Verbose "Filtered series down to $($filteredSeries.count) series"

        if ($filteredSeries.Count -eq 0 -and ([System.Convert]::ToBoolean($config.$($app)."$($app)Unattended")) -ne $false){

            if ($config.Sonarr.sonarrSeriesStatus -eq ""){
                $filteredSeriesWithTag = $allSeries | Where-Object {$_.tags -contains $tagId -and $_.monitored -eq ([System.Convert]::ToBoolean($config.$($app)."$($app)Monitored"))}
            }

            else {
                $filteredSeriesWithTag = $allSeries | Where-Object {$_.tags -contains $tagId -and $_.monitored -eq ([System.Convert]::ToBoolean($config.$($app)."$($app)Monitored")) -and $_.status -eq $config.Sonarr.sonarrSeriesStatus}
            }

            Write-Verbose "Removing tag $($config.$($app)."$($app)TagName") from $($filteredSeriesWithTag.Count) series"

            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                Remove-Tag -App $app -Url "$($config.($app)."$($app)Url")" -Series $filteredSeriesWithTag -tagId $tagID -Verbose
            }

            else {
                Remove-Tag -App $app -Url "$($config.($app)."$($app)Url")" -Series $filteredSeriesWithTag -tagId $tagID
            }

            $allSeries = Invoke-RestMethod -Uri "$($config.Sonarr.sonarrUrl)/api/v3/series" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

            if ($config.Sonarr.sonarrSeriesStatus -eq ""){
                $newFilteredSeries = $allSeries | Where-Object {$_.tags -notcontains $tagId -and $_.monitored -eq ([System.Convert]::ToBoolean($config.$($app)."$($app)Monitored"))}
            }

            else {
                $newFilteredSeries = $allSeries | Where-Object {$_.tags -notcontains $tagId -and $_.monitored -eq ([System.Convert]::ToBoolean($config.$($app)."$($app)Monitored")) -and $_.status -eq $config.Sonarr.sonarrSeriesStatus}
            }

            if ($config.$($app)."$($app)Count" -eq "max"){
                $config.$($app)."$($app)Count" = $newFilteredSeries.count
                Write-Verbose "$((Get-Culture).TextInfo.ToTitleCase("$app")) count set to max. `nSeries count has been modified to $($newFilteredSeries.count) movies"
            }
            $randomSeries = Get-Random -InputObject $newFilteredSeries -Count $config.$($app)."$($app)Count"
            $seriesCounter = 0

            Write-Verbose "Adding tag $($config.$($app)."$($app)TagName") to $($config.($app)."$($app)Count") series"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url "$($config.($app)."$($app)Url")" -Verbose
            }

            else {
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url "$($config.($app)."$($app)Url")"
            }

            foreach ($series in $randomSeries) {
                $seriesCounter++
                Write-Progress -Activity "Search in Progress" -PercentComplete (($seriesCounter / $config.($app)."$($app)Count") * 100)

                if ($PSCmdlet.ShouldProcess($series.title, "Searching for series")){
                    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                        Search-Series -Series $series -Url "$($config.($app)."$($app)Url")" -Verbose
                    }
                    else {
                        Search-Series -Series $series -Url "$($config.($app)."$($app)Url")"
                    }
                    Write-Output "Manual search kicked off for $($series.title)"
                }
            }
        }

        elseif ($filteredSeries.Count -eq 0 -and ([System.Convert]::ToBoolean($config.($app)."$($app)Unattended")) -eq $false){
            if ($config.General.discordWebhook -ne ""){
                Send-DiscordWebhook -App $app -Url $config.General.discordWebhook
            }

            else{
                throw "No series left to search"
            }
        }

        else {
            if ($config.$($app)."$($app)Count" -eq "max"){
                $config.$($app)."$($app)Count" = $filteredSeries.count
                Write-Verbose "$((Get-Culture).TextInfo.ToTitleCase("$app")) count set to max. `nSeries count has been modified to $($filteredSeries.count) series"
            }
            $randomSeries = Get-Random -InputObject $filteredSeries -Count $config.$($app)."$($app)Count"
            $seriesCounter = 0

            Write-Verbose "Adding tag $($config.$($app)."$($app)TagName") to $($config.($app)."$($app)Count") series"
            if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url "$($config.($app)."$($app)Url")" -Verbose
            }

            else {
                Add-Tag -App $app -Series $randomSeries -TagId $tagID -Url "$($config.($app)."$($app)Url")"
            }

            foreach ($series in $randomSeries) {
                $seriesCounter++
                Write-Progress -Activity "Search in Progress" -PercentComplete (($seriesCounter / $config.($app)."$($app)Count") * 100)

                if ($PSCmdlet.ShouldProcess($series.title, "Searching for series")){
                    if ($PSCmdlet.MyInvocation.BoundParameters["Verbose"].IsPresent){
                        Search-Series -Series $series -Url "$($config.($app)."$($app)Url")" -Verbose
                    }

                    else {
                        Search-Series -Series $series -Url "$($config.($app)."$($app)Url")"
                    }
                    Write-Output "Manual search kicked off for $($series.title)"
                }
            }
        }
    }

    if ($app -eq "lidarr"){
        throw "Not supported"
    }

    if ($app -eq "whisparr"){
        throw "Not supported"
    }

    if ($app -eq "prowlarr"){
        throw "Really?"
    }

}
