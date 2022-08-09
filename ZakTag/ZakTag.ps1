$radarrApiKey = ""
$radarrUrl = ""
$releaseGroups = New-Object System.Collections.Generic.List[System.Object]

$webHeaders = @{
    "x-api-key" = $radarrApiKey
}


$allMovies = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

$releaseGroups.AddRange(($allmovies.moviefile.releasegroup | Select-Object -Unique))

foreach ($releaseGroup in $releaseGroups){

    $allExistingTags = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

    if ($allExistingTags.label -notcontains $releaseGroup){

        Write-Host "Tag with name $($releaseGroup) does not exist, creating one..."

        $Body = @{
            "label" = $releaseGroup
        } | ConvertTo-Json

        $createTag = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/tag" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -Body $Body -ContentType "application/json"

        $allExistingTags = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode
    }
}

foreach ($tag in $allExistingTags){
    $movies = $allmovies | Where-Object {$_.moviefile.releasegroup -contains $tag.label}

    $setTag = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movies.ID -join ",")],`"tags`":[$($tag.id)],`"applyTags`":`"add`"}"

}
