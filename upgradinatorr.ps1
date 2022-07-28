<#
.SYNOPSIS
This script will kick off manual search on a random number of movies in Radarr and add a specific tag to those movies so they aren't searched again

.LINK
https://radarr.video/docs/api/#/

#>


[CmdletBinding()]
param (
    [Parameter(Mandatory)]
    [string]
    $apiKey,
    [Parameter(Mandatory)]
    [string]
    $uri,
    [Parameter(Mandatory)]
    [string]
    $tagId,
    [Parameter(Mandatory)]
    [string]
    $count

)

Write-Host "Checking that Radarr is accessible" -ForegroundColor Yellow
$webRequestGetHeaders = @{
    "method"="GET"
    "path"="/api/v3/system/status"
    "x-api-key"= $apiKey
}
$webRequest = Invoke-WebRequest -UseBasicParsing -Uri $uri -Header $webRequestGetHeaders

if ($webRequest.StatusCode -eq 200){
    Write-Host "Success!" -ForegroundColor "Green"
}

else {
    Write-Host "Radarr does not seem to be accessible, it responded with status code" $webRequest.StatusCode -ForegroundColor Red
    Exit 1
}

Write-Host "Checking that the tag ID provided exists in Radarr" -ForegroundColor Yellow

try {
    $tagGetHeaders = @{
        "method"="GET"
        "path"="/api/v3/tag"
        "x-api-key"= $apiKey
    }
    $tagList = Invoke-RestMethod  -Uri "$($uri)/api/v3/tag" -Method Get -Headers $tagGetHeaders
    if ($tagList.id -contains $tagId){
        Write-Host "Tag ID exists in Radarr" -ForegroundColor Green
    }

    else {
        Write-Host "Tag ID" $tagid "does not exist in Radarr. Below is a list of all existing tags in Radarr" -ForegroundColor Red
        $taglist | Sort-Object id
    }
}
catch {
    Write-Host $_ -ForegroundColor Red
    Exit 1
}

try {
    $getMovieHeaders = @{
        "method"="GET"
        "path"="/api/v3/movie"
        "x-api-key"= $apiKey
    }
    $commandMovieHeaders = @{
        "method"="POST"
        "path"="/api/v3/command"
        "x-api-key"= $apiKey
    }
    $putTagHeaders = @{
        "method"="PUT"
        "path"="/api/v3/movie/editor"
        "x-api-key"= $apiKey
    }

    $allMovies = Invoke-RestMethod -Uri "$uri/api/v3/movie" -Headers $getMovieHeaders
    $movies = $AllMovies | Where-Object {$_.tags -notcontains $tagNumber}
    $randomMovies = Get-Random -InputObject $movies -Count $count

    foreach ($movie in $randomMovies){
        Invoke-RestMethod -Uri "$uri/api/v3/movie/editor" -Method Put -Headers $putTagHeaders -ContentType "application/json" -Body "{`"movieIds`":[$($movie.ID)],`"tags`":[20],`"applyTags`":`"add`"}"
        Invoke-RestMethod -Uri "$($uri)/api/v3/command" -Method "POST" -Headers $commandMovieHeaders -ContentType "application/json" -Body "{`"name`":`"MoviesSearch`",`"movieIds`":[$($movie.ID)]}"
    }

}
catch {
    Write-Host $_ -ForegroundColor Red
    Exit 1
}
