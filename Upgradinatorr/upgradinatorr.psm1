$api_version_radarr = 'v3'
$api_version_sonarr = 'v3'
function Add-Tag {
    [CmdletBinding()]
    param (
        $app,
        $movies,
        $series,
        $tagId,
        $url
    )

    if ($app -like '*Radarr*') {
        Invoke-RestMethod -Uri "$($url)/api/$($api_version_radarr)/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"movieIds`":[$($movies.ID -join ',')],`"tags`":[$tagId],`"applyTags`":`"add`"}" | Out-Null

        if (Confirm-ArrResp($apiStatusCode)) {
        }
        {
            throw 'Failed to get tag list'
        }
    }

    elseif ($app -like '*Sonarr*') {
        Invoke-RestMethod -Uri "$($url)/api/$($api_version_sonarr)/series/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"seriesIds`":[$($series.ID -join ',')],`"tags`":[$tagId],`"applyTags`":`"add`"}" | Out-Null

        if (Confirm-ArrResp($apiStatusCode)) {
        }
        {
            throw 'Failed to get tag list'
        }
    }
}

function Confirm-ArrResp {
    [CmdletBinding()]
    param (
        $apiStatusCode
    )

    switch ( $apiStatusCode ) {
        200 { $true }
        201 { $true }
        202 { $true }
        302 { throw 'Encountered redirect. Possible missing urlbase?' }
        401 { throw 'Unauthorized. Possibly invalid apikey' }
    }

    throw 'Unexpected HTTP status code - $apiStatusCode'

}

function Confirm-AppConnectivity {
    [CmdletBinding()]
    param (
        $app,
        $url
    )

    if ($app -like '*Radarr*') {
        $apiversion = $api_version_radarr
    } elseif ($app -like '*Sonarr*') {
        $apiversion = $api_version_sonarr
    }
    try {
        Invoke-RestMethod -Uri "$($url)/api/$($apiversion)/system/status" -Method Get -StatusCodeVariable apiStatusCode -Headers $webHeaders | Out-Null
        Write-Verbose "Connectivity to $((Get-Culture).TextInfo.ToTitleCase("$app")) confirmed"
    } catch {
        throw "$((Get-Culture).TextInfo.ToTitleCase("$app")) $_."
    }
}

function Confirm-AppURL {
    [CmdletBinding()]
    param (
        $app,
        $url
    )

    if ($url -notmatch 'https?:\/\/') {
        throw "Your URL for $((Get-Culture).TextInfo.ToTitleCase($app)) is not formatted correctly, it must start with http(s)://"
    } else {
        Write-Verbose "$((Get-Culture).TextInfo.ToTitleCase("$app")) URL confirmed"
    }
}

function Get-ArrItems {
    [CmdletBinding()]
    param (
        $app,
        $url
    )

    if ($app -like '*Radarr*') {
        $result = $(Invoke-RestMethod -Uri "$aurl/api/$($api_version_radarr)/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode)
    } elseif ($app -like '*Sonarr*') {
        $result = $(Invoke-RestMethod -Uri "$aurl/api/$($api_version_sonarr)/series" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode)
    }

    if (Confirm-ArrResp($apiStatusCode)) {
        $result
    } else {
        throw 'Failed to get items'
    }
}
function Get-TagId {
    [CmdletBinding()]
    param (
        $app,
        $tagName,
        $url
    )

    if ($app -like '*Radarr*') {
        $apiversion = $api_version_radarr
    } elseif ($app -like '*Sonarr*') {
        $apiversion = $api_version_sonarr
    }

    $currentTagList = Invoke-RestMethod -Uri "$($url)/api/$($apiversion)/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

    if (Confirm-ArrResp($apiStatusCode)) {
        $tagNameId = $currentTagList | Where-Object { $_.label -contains $tagName } | Select-Object -ExpandProperty id

        if ($currentTagList.label -notcontains $tagName) {

            $Body = @{
                'label' = $tagName
            } | ConvertTo-Json

            Invoke-RestMethod -Uri "$($url)/api/$($apiversion)//tag" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -Body $Body -ContentType 'application/json' | Out-Null

            $updatedTagList = Invoke-RestMethod -Uri "$($url)/api/$($apiversion)//tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

            $tagNameId = $updatedTagList | Where-Object { $_.label -contains $tagName } | Select-Object -ExpandProperty id
        }

        $tagNameId
        Write-Verbose "Tag ID $tagNameId confirmed for $((Get-Culture).TextInfo.ToTitleCase("$app"))"
    } else {
        throw 'Failed to get tags'
    }

}

function Read-IniFile {
    [CmdletBinding()]
    param (
        $file
    )

    $ini = @{}

    # Create a default section if none exist in the file. Like a java prop file.
    $section = 'NO_SECTION'
    $ini[$section] = @{}

    switch -regex -file $file {
        '^\[(.+)\]$' {
            $section = $matches[1].Trim()
            $ini[$section] = @{}
        }
        '^\s*([^#].+?)\s*=\s*(.*)' {
            $name, $value = $matches[1..2]
            # skip comments that start with semicolon:
            if (!($name.StartsWith(';'))) {
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

    if ($app -like '*Radarr*') {
        Invoke-RestMethod -Uri "$($url)/api/$($api_version_radarr)/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"movieIds`":[$($movies.id -join ',')],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}" | Out-Null
    }

    elseif ($app -like '*Sonarr*') {
        Invoke-RestMethod -Uri "$($url)/api/$($api_version_sonarr)/series/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"seriesIds`":[$($series.id -join ',')],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}" | Out-Null
    }
    if (Confirm-ArrResp($apiStatusCode)) {
    } else {
        throw 'Failed to remove tag'
    }
}

function Search-Movies {
    [CmdletBinding()]
    param (
        $movie,
        $url
    )

    Invoke-RestMethod -Uri "$($url)/api/$($api_version_radarr)/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"name`":`"MoviesSearch`",`"movieIds`":[$($movie.ID)]}" | Out-Null
    
    if (Confirm-ArrResp($apiStatusCode)) {
    } else {
        throw "Failed to search for $($movie.title) with statuscode $apiStatusCode"
    }
}

function Search-Series {
    [CmdletBinding()]
    param (
        $series,
        $url
    )
    Invoke-RestMethod -Uri "$($url)/api/$($api_version_sonarr)/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType 'application/json' -Body "{`"name`":`"SeriesSearch`",`"seriesId`":$($series.ID)}" | Out-Null

    if (Confirm-ArrResp($apiStatusCode)) {
    } else {
        throw "Failed to search for $($series.title) with statuscode $apiStatusCode"
    }
}

function Send-DiscordWebhook {
    [CmdletBinding()]
    param (
        $app,
        $url
    )
    [System.Collections.ArrayList]$discordEmbedArray = @()
    $color = '15548997'
    $title = 'Upgradinatorr'
    $thumburl = 'https://raw.githubusercontent.com/angrycuban13/Scripts/main/Images/powershell.png'
    if ($app -like '*Radarr*') {
        $description = 'No movies left to search!'
    } elseif ($app -like '*Sonarr*') {
        $description = 'No series left to search!'
    }
    $username = 'Upgradinatorr'
    $thumbnailObject = [PSCustomObject]@{
        url = $thumburl
    }

    $embedObject = [PSCustomObject]@{
        color       = $color
        title       = $title
        description = $description
        thumbnail   = $thumbnailObject
    }

    $discordEmbedArray.Add($embedObject)
    $payload = [PSCustomObject]@{
        embeds     = $discordEmbedArray
        username   = $username
        avatar_url = $thumburl
    }

    Invoke-RestMethod -Uri $url -Body ($payload | ConvertTo-Json -Depth 4) -Method Post -ContentType 'application/json'
}
