<#
.SYNOPSIS
This script will kick off manual search on a random number of movies in Radarr and add a specific tag to those movies so they aren't searched again

Thanks @Roxedus for the cleanup and general pointers

.LINK
https://radarr.video/docs/api/#/

#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory)]
    [string]
    $apiKey,
    [Parameter(Mandatory)]
    [string]
    [ValidateScript({
        if ($_.StartsWith('http://') -and -Not $_.EndsWith("/")){
            return $true
        }
        elseif ($_.EndsWith("/")){
            throw "Url should not end with /"
        }
        else{
            throw "Your Url did not start with http://"
        }
    })]
    $uri,
    [Parameter(Mandatory)]
    [ValidateRange("Positive")]
    [Int]
    $tagId,
    [Parameter(Mandatory)]
    [ValidateRange("Positive")]
    [Int]
    $count,
    [Parameter()]
    [Bool]
    $monitored = $true
)

if ($host.Version -notlike "7.*"){
    throw "You need Powershell 7 to run this script"
}

$webHeaders = @{
    "x-api-key" = $apiKey
}

Invoke-RestMethod -Uri $uri/api/v3/system/status -Method Get -StatusCodeVariable apiStatusCode -Headers $webHeaders | Out-Null

if ($apiStatusCode -notmatch "2\d\d"){
    throw "Radarr returned $apiStatusCode"
}

$tagList = Invoke-RestMethod  -Uri "$($uri)/api/v3/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

if ($apiStatusCode -notmatch "2\d\d"){
    throw "Failed to get tag list"
}

if ($tagList.id -notcontains $tagId){
    Write-Host "Tag ID $tagId does not exist in Radarr. Below is a list of all existing tags in Radarr:" -ForegroundColor Red
    $taglist | Sort-Object id
}

$allMovies = Invoke-RestMethod -Uri "$uri/api/v3/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

if ($apiStatusCode -notmatch "2\d\d"){
    throw "Failed to get movie list"
}

$movies = $allMovies | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $monitored }
$randomMovies = Get-Random -InputObject $movies -Count $count
$movieCounter = 0

foreach ($movie in $randomMovies) {
    $movieCounter++
    Write-Progress -Activity "Search in Progress" -PercentComplete (($movieCounter / $count) * 100)
    if ($PSCmdlet.ShouldProcess($movie.title, "Searching for movie")){
        $addTag = Invoke-RestMethod -Uri "$uri/api/v3/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movie.ID)],`"tags`":[$tagId],`"applyTags`":`"add`"}"

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to add tag to $($movie.title) with statuscode $apiStatusCode\n content: $addTag"
        }

        $searchMovies = Invoke-RestMethod -Uri "$($uri)/api/v3/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"name`":`"MoviesSearch`",`"movieIds`":[$($movie.ID)]}"

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to search for $($movie.title) with statuscode $apiStatusCode\n content: $searchMovies"
        }
        Write-Host "Manual search kicked off for" $movie.title
    }
}
