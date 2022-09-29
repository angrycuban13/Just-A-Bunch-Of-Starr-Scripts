function Add-Tag {
    [CmdletBinding()]
    param (
        $app,
        $movies,
        $series,
        $tagId,
        $url
    )

    if ($app -eq "Radarr"){
        Invoke-RestMethod -Uri "$($url)/api/v3/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movies.ID -join ",")],`"tags`":[$tagId],`"applyTags`":`"add`"}" | Out-Null

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to get tag list"
        }
    }

    elseif ($app -eq "Sonarr"){
        Invoke-RestMethod -Uri "$($url)/api/v3/series/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"seriesIds`":[$($series.ID -join ",")],`"tags`":[$tagId],`"applyTags`":`"add`"}" | Out-Null

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to get tag list"
        }
    }
}

function Confirm-AppConnectivity {
    [CmdletBinding()]
    param (
        $app,
        $url
    )

    try {
        Invoke-RestMethod -Uri "$($url)/api/v3/system/status" -Method Get -StatusCodeVariable apiStatusCode -Headers $webHeaders | Out-Null
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

    if ($url -notmatch "https?:\/\/" -or $url.EndsWith("/")){
        throw "Your URL for $((Get-Culture).TextInfo.ToTitleCase($app)) is not formatted correctly, it should start with http(s):// and not end in /"
    }
    else {
        Write-Verbose "$((Get-Culture).TextInfo.ToTitleCase("$app")) URL confirmed"
    }
}

function Get-TagId {
    [CmdletBinding()]
    param (
        $app,
        $tagName,
        $url
    )

    $currentTagList = Invoke-RestMethod -Uri "$($url)/api/v3/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

    if ($apiStatusCode -notmatch "2\d\d"){
        throw "Failed to get tag list"
    }

    $tagNameId = $currentTagList | Where-Object {$_.label -contains $tagName} | Select-Object -ExpandProperty id

    if ($currentTagList.label -notcontains $tagName){

        $Body = @{
            "label" = $tagName
        } | ConvertTo-Json

        Invoke-RestMethod -Uri "$($url)/api/v3/tag" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -Body $Body -ContentType "application/json" | Out-Null

        $updatedTagList = Invoke-RestMethod -Uri "$($url)/api/v3/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

        $tagNameId = $updatedTagList | Where-Object {$_.label -contains $tagName} | Select-Object -ExpandProperty id
    }

    $tagNameId
    Write-Verbose "Tag ID $tagNameId confirmed for $((Get-Culture).TextInfo.ToTitleCase("$app"))"
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
            $name,$value = $matches[1..2]
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

    if ($app -eq "Radarr"){
        Invoke-RestMethod -Uri "$($url)/api/v3/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movies.id -join ",")],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}" | Out-Null

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to get movie list"
        }
    }

    elseif ($app -eq "Sonarr"){
        Invoke-RestMethod -Uri "$($url)/api/v3/series/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"seriesIds`":[$($series.id -join ",")],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}" | Out-Null

        if ($apiStatusCode -notmatch "2\d\d"){
            throw "Failed to get movie list"
        }
    }
}

function Search-Movies {
    [CmdletBinding()]
    param (
        $movie,
        $url
    )
    Invoke-RestMethod -Uri "$($url)/api/v3/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"name`":`"MoviesSearch`",`"movieIds`":[$($movie.ID)]}" | Out-Null

    if ($apiStatusCode -notmatch "2\d\d"){
        throw "Failed to search for $($movie.title) with statuscode $apiStatusCode"
    }
}

function Search-Series {
    [CmdletBinding()]
    param (
        $series,
        $url
    )
    Invoke-RestMethod -Uri "$($url)/api/v3/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"name`":`"SeriesSearch`",`"seriesId`":$($series.ID)}" | Out-Null

    if ($apiStatusCode -notmatch "2\d\d"){
        throw "Failed to search for $($series.title) with statuscode $apiStatusCode"
    }
}

function Send-DiscordWebhook {
    [CmdletBinding()]
    param (
        $app,
        $url
    )
    [System.Collections.ArrayList]$discordEmbedArray= @()
    $color = '15548997'
    $title = "Upgradinatorr"
    if ($app -eq "Radarr"){
        $description = "No movies left to search!"
    }
    elseif ($app -eq "Sonarr") {
        $description = "No series left to search!"
    }
    $username = "Upgradinatorr"
    $thumbnailObject = [PSCustomObject]@{
        url = "https://raw.githubusercontent.com/angrycuban13/Scripts/main/Images/powershell.png"
    }

    $embedObject = [PSCustomObject]@{
        color = $color
        title = $title
        description = $description
        thumbnail = $thumbnailObject
    }

    $discordEmbedArray.Add($embedObject)
    $payload = [PSCustomObject]@{
        embeds = $discordEmbedArray
        username = $username
        avatar_url = "https://raw.githubusercontent.com/angrycuban13/Scripts/main/Images/powershell.png"
    }

    Invoke-RestMethod -Uri $url -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'
}
