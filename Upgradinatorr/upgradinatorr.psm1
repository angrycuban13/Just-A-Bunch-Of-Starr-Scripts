function Add-Tag {
    param (
        $app,
        $movie
    )

    $addTag = Invoke-RestMethod -Uri "$($config.($app)."$($app)Url")/api/v3/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movie.ID)],`"tags`":[$tagId],`"applyTags`":`"add`"}"

    if ($apiStatusCode -notmatch "2\d\d"){
        throw "Failed to add tag to $($movie.title) with statuscode $apiStatusCode\n content: $addTag"
    }

}

function Confirm-AppConnectivity {
    param (
        $app
    )

    try {
        Invoke-RestMethod -Uri "$($config.($app)."$($app)Url")/api/v3/system/status" -Method Get -StatusCodeVariable apiStatusCode -Headers $webHeaders | Out-Null
    }
    catch {
        throw "$app $_."
    }
}

function Confirm-AppURL {
    param (
        $app
    )

    if ($config.$($app)."$($app)Url" -notmatch "https?:\/\/" -and $config."$($app)"."$($app)Url".EndsWith("/")){
        throw "Your URL for $app is not formatted correctly, it should start with http(s):// and not end in /"
    }
}

function Get-TagId {
    param (
        $app
    )

    Write-Verbose "Getting tag id for $app"
    Write-Verbose "Tag name is $($($config.$($app)."$($app)TagName"))"
    $tagList = Invoke-RestMethod -Uri "$($config.($app)."$($app)Url")/api/v3/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

    $tagId = $taglist | Where-Object {$_.label -contains $config.$($app)."$($app)TagName"} | Select-Object -ExpandProperty id


    if ($apiStatusCode -notmatch "2\d\d"){
        throw "Failed to get tag list"
    }

    if ($tagList.label -notcontains $config.$($app)."$($app)TagName"){
        throw "$($config.$($app)."$($app)TagName") doesn't exist in $app"
    }
    $tagID
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
        $app,
        $movie
    )
    $searchMovies = Invoke-RestMethod -Uri "$($config.($app)."$($app)Url")/api/v3/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"name`":`"MoviesSearch`",`"movieIds`":[$($movie.ID)]}"

    if ($apiStatusCode -notmatch "2\d\d"){
        throw "Failed to search for $($movie.title) with statuscode $apiStatusCode\n content: $searchMovies"
    }
}
