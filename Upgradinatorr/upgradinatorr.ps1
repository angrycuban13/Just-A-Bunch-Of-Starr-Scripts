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

if ($PSVersionTable.PSVersion -notlike "7.*") {
    throw "You need Powershell 7 to run this script"
}

# Import functions
Import-Module $PSScriptRoot\Upgradinatorr.psm1 -Force

# Specify location of config file.
$configFile = Join-Path -Path $PSScriptRoot -ChildPath upgradinatorr.conf
Write-Verbose "Location for config file is $configFile"

#Read the parameters from the config file.
if (Test-Path  $configFile -PathType Leaf){

    Write-Verbose "Parsing config file"
    $config = Read-IniFile -File $configFile

    #Create global variable so it can be used by the functions
    $global:config=$config
}

else {
    throw "Could not find config file"
}

Write-Verbose "Config file parsed successfully"


foreach ($app in $apps){

    $webHeaders = @{
        "x-api-key" = $config.$($app)."$($app)ApiKey"
    }

    #Create global variables so they can be used by the functions
    $Global:app = $app
    $Global:webHeaders = $webHeaders

    if ($app -eq "radarr"){

        Write-Verbose "Confirming URL for $app"
        Confirm-AppURL -app $app

        Write-Verbose "Confirming connectivity for $app"
        Confirm-AppConnectivity -app $app

        #Create global variable so it can be used by the functions
        $global:tagId = Get-TagId -app $app

        Write-Verbose "Tag ID $tagID confirmed for $app"

        $allMovies = Invoke-RestMethod -Uri "$($config.($app)."$($app)Url")/api/v3/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode
        Write-Verbose "Retrieved a total of $($allmovies.Count) movies"

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to get movie list"
        }

        $filteredMovies = $allMovies | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $config.General.monitored -and $_.status -eq $config.Radarr.movieStatus }
        Write-Verbose "Filtered movies to a total of $($filteredMovies.count) movies"

        if ($filteredMovies.Count -eq 0){
            throw "No movies left to search"
        }

        else {
            $randomMovies = Get-Random -InputObject $filteredMovies -Count $config.Radarr.radarrCount
            $movieCounter = 0

            foreach ($movie in $randomMovies) {

                $movieCounter++
                $global:movie = $movie
                Write-Progress -Activity "Search in Progress" -PercentComplete (($movieCounter / $config.Radarr.radarrCount) * 100)

                if ($PSCmdlet.ShouldProcess($movie.title, "Searching for movie")){
                    Write-Verbose "Adding tag ID $tagID to $($movie.title)"
                    Add-Tag -app $app -movie $movie
                    Search-Movies -app $app -movie $movies
                    Write-Host "Manual search kicked off for" $movie.title
                }
            }
        }#>
    }

    if  ($app -eq "sonarr"){
        throw "Sonarr does not support Custom Formats at this time"
    }

    if ($app -eq "lidarr"){
        throw "Lidarr is not yet configured - and it will probably never be"
    }

    if ($app -eq "whisparr"){
        throw "Whisparr is not yet configured"
    }

    elseif ($app -eq "prowlarr"){
        throw "Really?"
    }

}
