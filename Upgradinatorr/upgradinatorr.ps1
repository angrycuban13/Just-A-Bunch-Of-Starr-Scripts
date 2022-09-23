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
    # Define apps
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

        Write-Verbose "Confirming URL for $((Get-Culture).TextInfo.ToTitleCase("$app"))"
        Confirm-AppURL -App $app -Url $($config.($app)."$($app)Url")

        Write-Verbose "Confirming connectivity for $((Get-Culture).TextInfo.ToTitleCase("$app"))"
        Confirm-AppConnectivity -App $app -Url $($config.($app)."$($app)Url")

        $tagID = Get-TagId -App $app -Url $($config.($app)."$($app)Url") -TagName $($config.$($app)."$($app)TagName")

        Write-Verbose "Tag ID $tagID confirmed for $((Get-Culture).TextInfo.ToTitleCase("$app"))"

        $allMovies = Invoke-RestMethod -Uri "$($config.($app)."$($app)Url")/api/v3/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to get movie list"
        }

        Write-Verbose "Retrieved a total of $($allmovies.Count) movies"

        $filteredMovies = $allMovies | Where-Object {$_.tags -notcontains $tagId -and $_.monitored -eq ([System.Convert]::ToBoolean($config.Radarr.radarrMonitored)) -and $_.status -eq $config.Radarr.radarrMovieStatus}

        Write-Verbose "Filtered movies down to $($filteredMovies.count) movies"

        if ($filteredMovies.Count -eq 0){
            throw "No movies left to search"
        }

        else {
            if ($config.Radarr.radarrCount -eq "max"){
                $config.Radarr.radarrCount = $filteredMovies.count
                Write-Verbose "Radarr count set to max. `nMovie count has been modified to $($filteredMovies.count) movies"
            }
            $randomMovies = Get-Random -InputObject $filteredMovies -Count $config.Radarr.radarrCount
            $movieCounter = 0

            Write-Verbose "Adding tag $($config.Radarr.radarrTagName) to $($config.Radarr.radarrCount) movies"
            Add-Tag -App $app -Movies $randomMovies -TagId $tagID -Url "$($config.($app)."$($app)Url")"

            foreach ($movie in $randomMovies) {
                $movieCounter++
                Write-Progress -Activity "Search in Progress" -PercentComplete (($movieCounter / $config.Radarr.radarrCount) * 100)

                if ($PSCmdlet.ShouldProcess($movie.title, "Searching for movie")){
                    Search-Movies -Movie $movie -Url "$($config.($app)."$($app)Url")"
                    Write-Output "Manual search kicked off for" $movie.title
                }
            }
        }
    }

    if  ($app -eq "sonarr"){
        throw "No"
    }

    if ($app -eq "lidarr"){
        throw "Also no"
    }

    if ($app -eq "whisparr"){
        throw "Also also no"
    }

    if ($app -eq "prowlarr"){
        throw "Really?"
    }

}
