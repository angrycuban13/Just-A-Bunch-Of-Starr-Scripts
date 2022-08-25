function Add-Tag {
    param (
        $app,
        $movies,
        $tagId,
        $url
    )

    Invoke-RestMethod -Uri "$($url)/api/v3/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movies.ID -join ",")],`"tags`":[$tagId],`"applyTags`":`"add`"}" | Out-Null

    if ($apiStatusCode -notmatch "2\d\d"){
        throw "Failed to add tag to $($movie.title) with statuscode $apiStatusCode"
    }

}

function Confirm-AppConnectivity {
    param (
        $app,
        $url
    )

    try {
        Invoke-RestMethod -Uri "$($url)/api/v3/system/status" -Method Get -StatusCodeVariable apiStatusCode -Headers $webHeaders | Out-Null
    }
    catch {
        throw "$((Get-Culture).TextInfo.ToTitleCase("$app")) $_."
    }
}

function Confirm-AppURL {
    param (
        $app,
        $url
    )

    if ($url -notmatch "https?:\/\/" -or $url.EndsWith("/")){
        throw "Your URL for $app is not formatted correctly, it should start with http(s):// and not end in /"
    }
    else {
        Write-Output "$((Get-Culture).TextInfo.ToTitleCase("$app")) URL confirmed"
    }
}

function Get-TagId {
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
}

function Read-IniFile {
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

function Search-Movies {
    param (
        $movie,
        $url
    )
    Invoke-RestMethod -Uri "$($url)/api/v3/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"name`":`"MoviesSearch`",`"movieIds`":[$($movie.ID)]}" | Out-Null

    if ($apiStatusCode -notmatch "2\d\d"){
        throw "Failed to search for $($movie.title) with statuscode $apiStatusCode"
    }
}
