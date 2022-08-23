[CmdletBinding()]
param (
)

#------------- DEFINE VARIABLES -------------#

$radarrApiKey = ""
$radarrUrl = ""

#------------- SCRIPT STARTS -------------#

$releaseGroups = New-Object System.Collections.Generic.List[System.Object]
$releaseGroupTagsOnly = New-Object System.Collections.Generic.List[System.Object]

# Powershell version check
if ($PSVersionTable.PSVersion -like "5.*") {
    throw "You need at least Powershell 7 to run this script"
}

# Web headers to be sent with each request
$webHeaders = @{
    "x-api-key" = $radarrApiKey
}

# Retrieve all movies
$allMovies = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

$allMoviesWithFiles = $allMovies | Where-Object {$_.hasFile -contains "True"}

# Retrieve all existing tags
$allExistingTags = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

# Add all existing release groups to a list
$releaseGroups.AddRange(($allMoviesWithFiles.moviefile.releasegroup | Sort-Object -Unique))

Write-Verbose "Checking that tags exist. If this is your first time running this script it might take a while - depending on your library size."

# Loop through each release group and check if the tag exists in Radarr
foreach ($releaseGroup in $releaseGroups){
    # Try to match existing tag labels with current release group
    if ($allExistingTags.label -notcontains $releaseGroup){
        Write-Verbose "Tag with name $($releaseGroup) does not exist, creating tag..."

        $Body = @{
            "label" = $releaseGroup
        } | ConvertTo-Json

        # Create tag with current release group in Radarr
        Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/tag" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -Body $Body -ContentType "application/json" | Out-Null
    }
}

# Retrieve tags again so it includes the newly added release group tags
$updatedTags = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

# Loop through each existing tag and select release groups tags only to avoid including previously defined tags
foreach ($releaseGroup in $releaseGroups){
    $releaseGroupTagsOnly.Add(($updatedTags | Where-Object {$_.label -contains $releaseGroup}))
    }


Write-Verbose "Checking that existing movies have the correct tag, if the wrong tag is found it will be removed."

# Loop through each movie
foreach ($movie in $allMoviesWithFiles){
    # Loop through each tag id in current movie
    foreach ($tagId in $movie.tags){
        # If tag id matches a release group tag, look up the tag information
        if ($releaseGroupTagsOnly.id -contains $tagId){
            $tagLookup = $releaseGroupTagsOnly | Where-Object {$_.id -contains $tagId}
        }
        # Check if the movie's release group matches the tag, otherwise remove it
        if ($movie.movieFile.releasegroup -notlike $tagLookup.label){
            Write-Verbose "Removing tag $($tagLookup.label) from $($movie.title)"
            Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movie.id)],`"tags`":[$($tagLookup.id -join ",")],`"applyTags`":`"remove`"}" | Out-Null
        }
    }

    $movieReleaseGroup = $movie.movieFile.releaseGroup
    $releaseGroupTag = $releaseGroupTagsOnly | Where-Object {$_.label -contains $movieReleaseGroup}

    if ($movie.tags -contains $releaseGroupTag.id){
        Write-Verbose "$($movie.title) already has tag $($releaseGroupTag.label)"
    }

    else {
        Write-Verbose "Adding tag $($releaseGroupTag.label) to $($movie.title)"

        Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movie.id)],`"tags`":[$($releaseGroupTag.id)],`"applyTags`":`"add`"}" | Out-Null
    }
}
