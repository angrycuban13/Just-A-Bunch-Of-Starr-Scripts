<#
.SYNOPSIS
This script will kick off manual search on a random number of movies in Radarr and add a specific tag to those movies so they aren't searched again

Thanks @Roxedus for the cleanup and general pointers

.LINK
https://radarr.video/docs/api/#/

#>

[CmdletBinding(SupportsShouldProcess)]
param (
    # Define app
    [Parameter()]
    [string[]]
    $apps,
    # Reset and remove tags
    [Parameter()]
    [bool]
    $reset
)

if ($PSVersionTable.PSVersion -notlike "7.*") {
    throw "You need Powershell 7 to run this script"
}

# Specify location of config file.
$configFile = Join-Path -Path $PSScriptRoot -ChildPath upgradinatorr.conf

#Read the parameters from the config file.
if (Test-Path  $configFile -PathType Leaf){
    Function Parse-IniFile ($file) {
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
                $name,$value = $matches[1..2]
            # skip comments that start with semicolon:
            if (!($name.StartsWith(";"))) {
                $ini[$section][$name] = $value.Trim()
            }
        }
    }
        $ini
    }

    $config = Parse-IniFile -File $configFile
}

else {
    throw "Could not find config file"
}

foreach ($app in $apps){
    if ($app -eq "radarr"){

        # Validate Radarr URL
        if ($config.Radarr.radarrUrl -match "https?:\/\/" -and -Not $config.Radarr.radarrUrl.EndsWith("/")){
            Write-Verbose "URL formatted correctly, continuing"
        }
        elseif ($config.Radarr.radarrUrl.EndsWith("/")){
            throw "Radarr URL should not end with /"
        }
        else{
            throw "Your Radarr URL did not start with http:// or https://"
        } # Radarr URL Validated

        $webHeaders = @{
            "x-api-key" = $config.Radarr.radarrApiKey
        }

        # Query Radarr status via API
        Invoke-RestMethod -Uri "$($config.Radarr.radarrUrl)/api/v3/system/status" -Method Get -StatusCodeVariable apiStatusCode -Headers $webHeaders | Out-Null

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Radarr returned $apiStatusCode"
        }

        # Retrieve all tags in Radarr via API
        $tagList = Invoke-RestMethod -Uri "$($config.Radarr.radarrUrl)/api/v3/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to get tag list"
        }

        # Validate tag name exists
        if ($tagList.label -notcontains $config.Radarr.radarrTagName){
            throw "$($config.Radarr.radarrTagName) doesn't exist in Radarr"
        }

        # Obtain tag id based off provided tag name
        $tagId = $taglist | Where-Object {$_.label -contains $config.Radarr.radarrTagName} | Select-Object -ExpandProperty id

        # Retrieve all movies via API
        $allMovies = Invoke-RestMethod -Uri "$($config.Radarr.radarrUrl)/api/v3/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to get movie list"
        }

        # Filter movies that don't contain $tagId but match $monitored and $movieStatus.
        $movies = $allMovies | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $config.General.monitored -and $_.status -eq $config.Radarr.movieStatus }

        # If $reset set to true, remove tag from movies
        if ($reset){

            # Filter movies that match $tagId, $monitored and $movieStatus.
            $movies = $allMovies | Where-Object { $_.tags -contains $tagId -and $_.monitored -eq $config.General.monitored -and $_.status -eq $config.Radarr.movieStatus }

            $movieCounter = 0

            foreach ($movie in $movies) {
                $movieCounter++
                Write-Progress -Activity "Search in Progress" -PercentComplete (($movieCounter / $movies.Count) * 100)
                if ($PSCmdlet.ShouldProcess($movie.title, "Removing tags")){
                    $removeTag = Invoke-RestMethod -Uri "$($config.Radarr.radarrUrl)/api/v3/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movie.ID)],`"tags`":[$tagId],`"applyTags`":`"remove`"}"

                    if ($apiStatusCode -notmatch "2\d\d"){
                        throw "Failed to remove tag from $($movie.title) with statuscode $apiStatusCode\n content: $removeTag"
                    }
                }
                Write-Host "Removed tag from" $movie.title
            }
        }

        # Exit if there are no more movies available to search
        elseif ($movies.Count -eq 0){
            throw "No movies left to search"
        }

        # Start movie search
        else {
            $randomMovies = Get-Random -InputObject $movies -Count $config.General.count
            $movieCounter = 0

            foreach ($movie in $randomMovies) {
                $movieCounter++
                Write-Progress -Activity "Search in Progress" -PercentComplete (($movieCounter / $config.General.count) * 100)
                if ($PSCmdlet.ShouldProcess($movie.title, "Searching for movie")){
                    $addTag = Invoke-RestMethod -Uri "$($config.Radarr.radarrUrl)/api/v3/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movie.ID)],`"tags`":[$tagId],`"applyTags`":`"add`"}"

                    if ($apiStatusCode -notmatch "2\d\d"){
                        throw "Failed to add tag to $($movie.title) with statuscode $apiStatusCode\n content: $addTag"
                    }

                    $searchMovies = Invoke-RestMethod -Uri "$($config.Radarr.radarrUrl)/api/v3/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"name`":`"MoviesSearch`",`"movieIds`":[$($movie.ID)]}"

                    if ($apiStatusCode -notmatch "2\d\d"){
                        throw "Failed to search for $($movie.title) with statuscode $apiStatusCode\n content: $searchMovies"
                    }
                    Write-Host "Manual search kicked off for" $movie.title
                }
            }
        }
    }

    if  ($app -eq "sonarr"){
        throw "You are getting ahead of yourself..."
    }

    if ($app -eq "lidarr"){
        throw "Definitely not doing Lidarr, sorry"
    }

    if ($app -eq "whisparr"){
        throw "Naughty boy"
    }

    elseif ($app -eq "prowlarr"){
        throw "Is your name Orange?"
    }

}
