#Requires -Version 7

<#
.SYNOPSIS
Initiates a manual search for media in the specified applications.

.DESCRIPTION
The upgradinatorr.ps1 script initiates a manual search for media in the specified applications. The search parameters are determined by the settings in the provided configuration file.

.PARAMETER Apps
Specifies the names of the applications. This parameter is mandatory.

.PARAMETER ConfigFile
Specifies the path to the configuration file. This parameter is not mandatory. If not provided, it defaults to `$PSScriptRoot\upgradinatorr.conf`.

.EXAMPLE
PS C:\> .\upgradinatorr.ps1 -Apps "radarr, sonarr"

This command initiates a manual search for upgrades in the Radarr and Sonarr applications using the settings in the provided configuration file.

.INPUTS
System.String[], System.String. You can pipe a string array that contains application names and a string that contains the configuration file path to the script.

.OUTPUTS
None. The script initiates a manual search for upgrades and does not return any output.

.NOTES
The script throws an error if the API request fails.

Special thanks go to the following people for their contributions and guidance to this script:
- Roxedus
- austinwbest
#>

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $true, Position = 0)]
    [string[]]
    $Apps,

    [Parameter (Mandatory = $false, Position = 1)]
    [string]
    $ConfigFile = "$PSScriptRoot\upgradinatorr.conf"
)

function Add-TagToMedia {
    <#
    .SYNOPSIS
    Adds a tag to media items in a specified application.

    .DESCRIPTION
    The Add-TagToMedia function adds a tag to media items in a specified application.
    It supports Radarr, Sonarr, and Lidarr applications.

    .PARAMETER App
    Specifies the name of the application. This parameter is mandatory.

    .PARAMETER ApiKey
    Specifies the API key for the application. This parameter is mandatory.

    .PARAMETER ApiVersion
    Specifies the API version for the application. This parameter is mandatory.

    .PARAMETER Media
    Specifies the media items to which the tag should be added. This parameter is mandatory.

    .PARAMETER TagId
    Specifies the ID of the tag. This parameter is mandatory.

    .PARAMETER Url
    Specifies the URL of the application's API. This parameter is mandatory.

    .EXAMPLE
    PS C:\> Add-TagToMedia -App "Radarr" -ApiKey "your_api_key" -ApiVersion "v3" -Media $media -TagId "1" -Url "http://localhost:7878"

    This command adds the tag with ID 1 to the specified media items in the Radarr application.

    .INPUTS
    System.String, System.Array. You can pipe a string that contains an application name, API key, API version, tag ID, and URL, and an array that contains media items to the function.

    .OUTPUTS
    System.String. The function returns a string that indicates whether the tag was successfully added to the media items.

    .NOTES
    The function throws an error if the specified application is not supported or if the API request fails.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $App,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true, Position = 3)]
        [array]
        $Media,

        [Parameter(Mandatory = $true, Position = 4)]
        [string]
        $TagId,

        [Parameter(Mandatory = $true, Position = 5)]
        [string]
        $Url
    )

    begin {

        if ($media.Count -gt 1) {
            $mediaId = $($media.id -join ',')
        }

        else {
            $mediaId = $($media.id)
        }

        switch -Wildcard ($app) {
            'radarr*' {
                $body = "{`"movieIds`":[$mediaId],`"tags`":[$($tagId)],`"applyTags`":`"add`"}"
                $apiEndpoint = 'movie/editor'
            }
            'sonarr*' {
                $body = "{`"seriesIds`":[$mediaId],`"tags`":[$tagId],`"applyTags`":`"add`"}"
                $apiEndpoint = 'series/editor'
            }
            'lidarr*' {
                $body = "{`"artistIds`":[$mediaId],`"tags`":[$tagId],`"applyTags`":`"add`"}"
                $apiEndpoint = 'artist/editor'
            }
        }

        $params = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Put'
            Uri                = "$url/api/$apiVersion/$apiEndpoint"
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            Body               = $body
            ContentType        = 'application/json'
        }
    }

    process {
        $tagAddition = Invoke-RestMethod @params

        if (Confirm-AppResponse -StatusCodeResponse $statusCode -FunctionName $($MyInvocation.MyCommand) -App $app) {
            Write-Verbose "Successfully added tag to $($media.Count) items in $app"
        }#>
    }

    end {
        Write-Output "Tag added to $($media.Count) items in $app"
    }
}

function Confirm-Config {
    <#
    .SYNOPSIS
    Validates the configuration for a specified application.

    .DESCRIPTION
    The Confirm-Config function validates the configuration for a specified application.
    It checks various parameters such as API Key, Count, Monitored, MovieStatus, SeriesStatus, ArtistStatus, QualityProfileName, TagName, IgnoreTags, Unattended, and URL.

    .PARAMETER Config
    Specifies the configuration object. This parameter is mandatory.

    .PARAMETER App
    Specifies the name of the application. This parameter is mandatory.

    .EXAMPLE
    PS C:\> Confirm-Config -Config $config -App "Radarr"

    This command validates the configuration for the Radarr application.

    .INPUTS
    PSCustomObject, System.String. You can pipe a configuration object and a string that contains an application name to the function.

    .OUTPUTS
    System.String. The function returns a string that indicates whether the configuration for the specified application is valid.

    .NOTES
    The function throws an error if a configuration parameter is not valid.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [PSCustomObject]
        $Config,

        [Parameter(Mandatory = $true, Position = 1)]
        [String]
        $App
    )

    begin {
        $artistStatusValues = @('continuing', 'ended')
        $discordWebhookRegexMatch = 'https://discord.com/api/webhooks/\d+/.+'
        $monitoredValues = @('true', 'false')
        $movieStatusValues = @('tba', 'announced', 'inCinemas', 'released', 'deleted')
        $seriesStatusValues = @('continuing', 'ended', 'upcoming', 'deleted')
        $qualityProfileNameRegexMatch = '^.*$'
        $tagNameRegexMatch = '^.*$'
        $unattendedValues = @('true', 'false')
        $urlRegexMatch = '^(http|https)://'
    }

    process {
        Write-Verbose 'Validating configuration for Discord Webhook'

        if ($config.General.DiscordWebhook -ne '' -and $config.General.DiscordWebhook -notmatch $discordWebhookRegexMatch) {
            throw "Discord Webhook is not formatted correctly, it should start with `"https://discord.com/api/webhooks/ `""
        }

        Write-Verbose "Validating configuration for $app"

        Write-Verbose "Validating `"API Key`" for $app"
        if ($config.$app.ApiKey.Length -ne 32) {
            throw "API Key for `"$app`" is not 32 characters long"
        }

        Write-Verbose "Validating `"Count`" for $app"
        if ($config.$app.Count -ne 'max') {
            try {
                $num = [int]$config.$app.Count
            }
            catch {
                throw "Count for `"$app`" is not a valid number"
            }
        }

        Write-Verbose "Validating `"Monitored`" for $app"
        if ($config.$app.Monitored -notin $monitoredValues) {
            throw "Monitored for `"$app`" is not a valid value, it should be either `"$($monitoredValues[0])`" or `"$($monitoredValues[1])`""
        }

        switch -Wildcard ($app) {
            'Radarr*' {
                Write-Verbose "Validating `"MovieStatus`" for $app"
                if ($config.$app.MovieStatus -ne '' -and $config.$app.MovieStatus -notin $movieStatusValues) {
                    throw "MovieStatus for `"$app`" is not a valid value, expected one of the following: $($movieStatusValues -join ', ')"
                }
            }
            'Sonarr*' {
                Write-Verbose "Validating `"SeriesStatus`" for $app"
                if ($config.$app.SeriesStatus -ne '' -and $config.$app.SeriesStatus -notin $seriesStatusValues) {
                    throw "SeriesStatus for `"$app`" is not a valid value, expected one of the following:  $($seriesStatusValues -join ', ')"
                }
            }
            'Lidarr*' {
                Write-Verbose "Validating `"ArtistStatus`" for $app"
                if ($config.$app.ArtistStatus -ne '' -and $config.$app.ArtistStatus -notin $artistStatusValues) {
                    throw "ArtistStatus for `"$app`" is not a valid value, expected one of the following: $($artistStatusValues -join ', ')"
                }
            }
        }

        Write-Verbose "Validating `"Quality Profile Name`" for $app"
        if ($config.$app.QualityProfileName -ne '' -and $config.$app.QualityProfileName -notmatch $qualityProfileNameRegexMatch) {
            throw "QualityProfileName for `"$app`" is not formatted correctly, it should only contain alphanumeric characters"
        }

        Write-Verbose "Validating `"Tag Name`" for $app"
        if ($config.$app.TagName -notmatch $tagNameRegexMatch) {
            throw "TagName for `"$app`" is not formatted correctly, it should only contain alphanumeric characters"
        }

        Write-Verbose "Validating `"Ignore Tags`" for $app"
        if ($config.$app.IgnoreTags -ne '' -and $config.$app.IgnoreTags -notmatch $tagNameRegexMatch) {
            throw "IgnoreTags for `"$app`" is not formatted correctly, it should only contain alphanumeric characters"
        }

        Write-Verbose "Validating `"Unattended`" for $app"
        if ($config.$app.Unattended -notin $unattendedValues) {
            throw "Unattended for `"$app`" is not a valid value, it should be either `"$($unattendedValues[0])`" or `"$($unattendedValues[1])`""
        }

        Write-Verbose "Validating `"URL`" for $app"
        if ($config.$app.Url -notmatch $urlRegexMatch) {
            throw "URL for `"$app`" is not formatted correctly, it should start with either `"http://`" or `"https://`""
        }
    }

    end {
        Write-Output "Configuration for $app is valid"
    }
}

function Confirm-AppResponse {
    <#
    .SYNOPSIS
    Validates the HTTP status code response from a specified application.

    .DESCRIPTION
    The Confirm-AppResponse function validates the HTTP status code response from a specified application.
    It checks the status code and throws an error with a specific message based on the status code.

    .PARAMETER App
    Specifies the name of the application. This parameter is mandatory.

    .PARAMETER FunctionName
    Specifies the name of the function that called Confirm-AppResponse. This parameter is mandatory.

    .PARAMETER StatusCodeResponse
    Specifies the HTTP status code response from the application. This parameter is mandatory.

    .EXAMPLE
    PS C:\> Confirm-AppResponse -App "Radarr" -StatusCodeResponse "200"

    This command validates the HTTP status code response from the Radarr application.

    .INPUTS
    System.String. You can pipe a string that contains an application name and a status code response to the function.

    .OUTPUTS
    System.Boolean. The function returns $true if the status code is in the 200 range, and throws an error otherwise.

    .NOTES
    The function throws an error with a specific message based on the status code.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]
        $App,

        [Parameter(Mandatory = $true, Position = 1)]
        [String]
        $FunctionName,

        [Parameter(Mandatory = $true, Position = 2)]
        [String]
        $StatusCodeResponse
    )

    begin {}

    process {
        switch -Regex ( $statusCodeResponse ) {
            '2\d\d' {
                $true
            }
            302 {
                throw "Function: $functionName - Server responded with `"Redirect`" for $($app). Are you missing the URL base?"
            }
            400 {
                throw "Function: $functionName - Server responded with `"Invalid Request`" for $($app). Check your application's logs for details"
            }
            401 {
                throw "Function: $functionName - Server responded with `"Unauthorized`" for $($app). Is $($app) APIKey valid?"
            }
            404 {
                throw "Function: $functionName - Server responded with `"Not Found`" for $($app). Is $($app) URL correct?"
            }
            409 {
                throw "Function: $functionName - Server responded with `"Conflict`" for $($app). Something went wrong, please open a GitHub issue"
            }
            500 {

                throw "Function: $functionName - Server responded with `"Internal Server Error`" for $($app). Check your $($app) application's logs for details"
            }
            default {
                throw "Function: $functionName - Server responded with an unexpected HTTP status code  - ($($StatusCodeResponse)) for $($app). Please open a GitHub issue"
            }
        }
    }

    end {}
}

function Read-ConfigFile {
    <#
    .SYNOPSIS
    Reads a configuration file and returns its content as a custom PowerShell object.

    .DESCRIPTION
    The Read-ConfigFile function reads a configuration file and returns its content as a custom PowerShell object.
    The configuration file should be in the format of 'key = value' pairs under section headers '[section]'.
    Comments that start with a semicolon are skipped.

    .PARAMETER File
    Specifies the path to the configuration file. This parameter is mandatory.

    .EXAMPLE
    PS C:\> Read-ConfigFile -File "C:\path\to\config.ini"

    This command reads the configuration file at the specified path and returns its content as a custom PowerShell object.

    .INPUTS
    System.String. You can pipe a string that contains a path to the function.

    .OUTPUTS
    PSCustomObject. The function returns a custom PowerShell object that contains the content of the configuration file.

    .NOTES
    The function throws an error if the specified configuration file is not found.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [ValidateScript({
                if (-Not (Test-Path $_)) {
                    throw 'Config file not found'
                }
                else {
                    $true
                }
            })]
        [String]
        $File
    )

    begin {
        $configFileContent = @{}
    }

    process {
        switch -Regex -File ($file) {
            '^\[(.+)\]$' {
                $section = $matches[1].Trim()
                $configFileContent[$section] = @{}
            }

            '^\s*([^#].+?)\s*=\s*(.*)' {
                $name, $value = $matches[1..2]

                # skip comments that start with semicolon:
                if (-Not ($name.StartsWith(';'))) {
                    $configFileContent[$section][$name] = $value.Trim()
                }
            }
        }
    }

    end {
        [PSCustomObject]$configFileContent
    }
}

function Get-AppMedia {
    <#
    .SYNOPSIS
    Retrieves media items from a specified application.

    .DESCRIPTION
    The Get-AppMedia function retrieves media items from a specified application.
    It supports Radarr, Sonarr, and Lidarr applications.

    .PARAMETER App
    Specifies the name of the application. This parameter is mandatory.

    .PARAMETER ApiKey
    Specifies the API key for the application. This parameter is mandatory.

    .PARAMETER ApiVersion
    Specifies the API version for the application. This parameter is mandatory.

    .PARAMETER Url
    Specifies the URL of the application's API. This parameter is mandatory.

    .EXAMPLE
    PS C:\> Get-AppMedia -App "Radarr" -ApiKey "your_api_key" -ApiVersion "v3" -Url "http://localhost:7878"

    This command retrieves media items from the Radarr application.

    .INPUTS
    System.String. You can pipe a string that contains an application name, API key, API version, and URL to the function.

    .OUTPUTS
    PSCustomObject. The function returns a custom PowerShell object that contains the media items from the application.

    .NOTES
    The function throws an error if the API request fails.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $App,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true, Position = 3)]
        [string]
        $Url
    )

    begin {

        switch -Wildcard ($app) {
            'radarr*' {
                $apiEndpoint = 'movie'
            }
            'sonarr*' {
                $apiEndpoint = 'series'
            }
            'lidarr*' {
                $apiEndpoint = 'artist'
            }
        }

        $params = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Get'
            Uri                = "$url/api/$apiVersion/$apiEndpoint"
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            ContentType        = 'application/json'
        }
    }

    process {
        $response = Invoke-RestMethod @params

        if (Confirm-AppResponse -StatusCodeResponse $statusCode -FunctionName $($MyInvocation.MyCommand) -App $app) {
            Write-Verbose "Successfully retrieved items from $app"
        }
    }

    end {
        $response
    }
}

function Get-CurrentAPIVersion {
    <#
    .SYNOPSIS
    Retrieves the current API version for a specified application.

    .DESCRIPTION
    The Get-CurrentAPIVersion function retrieves the current API version for a specified application.
    It sends a GET request to the application's API and returns the current API version.

    .PARAMETER App
    Specifies the name of the application. This parameter is mandatory.

    .PARAMETER ApiKey
    Specifies the API key for the application. This parameter is mandatory.

    .PARAMETER Url
    Specifies the URL of the application's API. This parameter is mandatory.

    .EXAMPLE
    PS C:\> Get-CurrentAPIVersion -App "Radarr" -ApiKey "your_api_key" -Url "http://localhost:7878"

    This command retrieves the current API version for the Radarr application.

    .INPUTS
    System.String. You can pipe a string that contains an application name, API key, and URL to the function.

    .OUTPUTS
    System.String. The function returns a string that contains the current API version.

    .NOTES
    The function throws an error if the API request fails.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [String]
        $App,

        [Parameter(Mandatory = $true, Position = 1)]
        [String]
        $ApiKey,

        [Parameter(Mandatory = $true, Position = 2)]
        [String]
        $Url
    )

    begin {
        $params = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Get'
            Uri                = "$url/api"
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            ContentType        = 'application/json'
        }
    }

    process {
        $apiInfo = Invoke-RestMethod @params
    }

    end {
        if (Confirm-AppResponse -StatusCodeResponse $statusCode -FunctionName $($MyInvocation.MyCommand) -App $app) {
            $apiInfo.Current
        }
    }
}

function Get-QualityProfileId {
    <#
    .SYNOPSIS
    Retrieves the ID of a specified quality profile from a specified application.

    .DESCRIPTION
    The Get-QualityProfileId function retrieves the ID of a specified quality profile from a specified application.
    It sends a GET request to the application's API and returns the ID of the quality profile.

    .PARAMETER App
    Specifies the name of the application. This parameter is mandatory.

    .PARAMETER ApiKey
    Specifies the API key for the application. This parameter is mandatory.

    .PARAMETER ApiVersion
    Specifies the API version for the application. This parameter is mandatory.

    .PARAMETER QualityProfileName
    Specifies the name of the quality profile. This parameter is mandatory.

    .EXAMPLE
    PS C:\> Get-QualityProfileId -App "Radarr" -ApiKey "your_api_key" -ApiVersion "v3" -QualityProfileName "Profile1"

    This command retrieves the ID of the quality profile named "Profile1" from the Radarr application.

    .INPUTS
    System.String. You can pipe a string that contains an application name, API key, API version, and quality profile name to the function.

    .OUTPUTS
    System.Int32. The function returns an integer that contains the ID of the quality profile.

    .NOTES
    The function throws an error if the API request fails.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $App,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true, Position = 3)]
        [string]
        $QualityProfileName
    )

    begin {
        $params = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Get'
            Uri                = "$url/api/$apiVersion/qualityProfile"
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            ContentType        = 'application/json'
        }
    }

    process {
        $qualityProfiles = Invoke-RestMethod @params
        if (Confirm-AppResponse -StatusCodeResponse $statusCode -FunctionName $($MyInvocation.MyCommand) -App $app) {
            $qualityProfileId = $qualityProfiles | Where-Object { $_.name -eq $qualityProfileName }
        }
    }

    end {
        $qualityProfileId.id
    }
}

function Get-TagId {
    <#
    .SYNOPSIS
    Retrieves the ID of a specified tag from a specified application.

    .DESCRIPTION
    The Get-TagId function retrieves the ID of a specified tag from a specified application.
    If the tag does not exist, it creates the tag and then retrieves its ID.

    .PARAMETER App
    Specifies the name of the application. This parameter is mandatory.

    .PARAMETER ApiKey
    Specifies the API key for the application. This parameter is mandatory.

    .PARAMETER ApiVersion
    Specifies the API version for the application. This parameter is mandatory.

    .PARAMETER TagName
    Specifies the name of the tag. This parameter is mandatory.

    .PARAMETER Url
    Specifies the URL of the application's API. This parameter is mandatory.

    .EXAMPLE
    PS C:\> Get-TagId -App "Radarr" -ApiKey "your_api_key" -ApiVersion "v3" -TagName "tag1" -Url "http://localhost:7878"

    This command retrieves the ID of the tag named "tag1" from the Radarr application.

    .INPUTS
    System.String. You can pipe a string that contains an application name, API key, API version, tag name, and URL to the function.

    .OUTPUTS
    System.Int32. The function returns an integer that contains the ID of the tag.

    .NOTES
    The function throws an error if the API request fails.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $App,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true, Position = 3)]
        [string]
        $TagName,

        [Parameter(Mandatory = $true, Position = 4)]
        [string]
        $Url
    )

    begin {

        $getTagParams = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Get'
            Uri                = "$url/api/$apiVersion/tag"
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            ContentType        = 'application/json'
        }

        $createTagParams = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Post'
            Uri                = "$url/api/$apiVersion/tag"
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            Body               = @{'label' = $tagName } | ConvertTo-Json
            ContentType        = 'application/json'
        }
    }

    process {

        $currentTagList = Invoke-RestMethod @getTagParams

        if (Confirm-AppResponse -StatusCodeResponse $statusCode -FunctionName $($MyInvocation.MyCommand) -App $app) {
            $tagNameId = $currentTagList | Where-Object { $_.label -contains $tagName }

            if ($null -ne $tagNameId) {
                Write-Verbose "Found tag name `"$($tagName)`" with Id `"$($tagNameId.Id)`""
            }

            else {
                Write-Verbose "Tag name `"$($tagName)`" not found, creating it"

                Invoke-RestMethod @createTagParams

                if (Confirm-AppResponse -StatusCodeResponse $statusCode -FunctionName $($MyInvocation.MyCommand) -App $app) {
                    Write-Verbose "Successfully created tag name `"$($tagName)`""
                    $updatedTagList = Invoke-RestMethod @getTagParams
                    $tagNameId = $updatedTagList | Where-Object { $_.label -contains $tagName }
                }

            }
        }
    }

    end {
        $tagNameId.Id
    }
}

function Remove-TagFromMedia {
    <#
    .SYNOPSIS
    Removes a specified tag from media items in a specified application.

    .DESCRIPTION
    The Remove-TagFromMedia function removes a specified tag from media items in a specified application.
    It supports Radarr, Sonarr, and Lidarr applications.

    .PARAMETER App
    Specifies the name of the application. This parameter is mandatory.

    .PARAMETER ApiKey
    Specifies the API key for the application. This parameter is mandatory.

    .PARAMETER ApiVersion
    Specifies the API version for the application. This parameter is mandatory.

    .PARAMETER Media
    Specifies the media items to remove the tag from. This parameter is mandatory.

    .PARAMETER TagId
    Specifies the ID of the tag to remove. This parameter is mandatory.

    .PARAMETER Url
    Specifies the URL of the application's API. This parameter is mandatory.

    .EXAMPLE
    PS C:\> Remove-TagFromMedia -App "Radarr" -ApiKey "your_api_key" -ApiVersion "v3" -Media $media -TagId "1" -Url "http://localhost:7878"

    This command removes the tag with ID 1 from the specified media items in the Radarr application.

    .INPUTS
    System.String, System.Array. You can pipe a string that contains an application name, API key, API version, tag ID, and URL, and an array that contains media items to the function.

    .OUTPUTS
    System.String. The function returns a string that indicates whether the tag was successfully removed from the media items.

    .NOTES
    The function throws an error if the API request fails.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $App,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true, Position = 3)]
        [array]
        $Media,

        [Parameter(Mandatory = $true, Position = 4)]
        [string]
        $TagId,

        [Parameter(Mandatory = $true, Position = 5)]
        [string]
        $Url
    )

    begin {
        if ($media.Count -gt 1) {
            $mediaId = $($media.id -join ',')
        }

        else {
            $mediaId = $($media.id)
        }

        switch -Wildcard ($app) {
            'radarr*' {
                $body = "{`"movieIds`":[$mediaId],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}"
                $apiEndpoint = 'movie/editor'
            }
            'sonarr*' {
                $body = "{`"seriesIds`":[$mediaId],`"tags`":[$tagId],`"applyTags`":`"remove`"}"
                $apiEndpoint = 'series/editor'
            }
            'lidarr*' {
                $body = "{`"artistIds`":[$mediaId],`"tags`":[$tagId],`"applyTags`":`"remove`"}"
                $apiEndpoint = 'artist/editor'
            }
        }

        $params = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Put'
            Uri                = "$url/api/$apiVersion/$apiEndpoint"
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            Body               = $body
            ContentType        = 'application/json'
        }
    }

    process {
        $removeTag = Invoke-RestMethod @params

        if (Confirm-AppResponse -StatusCodeResponse $statusCode -FunctionName $($MyInvocation.MyCommand) -App $app) {
            Write-Verbose "Successfully removed tag from $($media.Count) items in $app"
        }
    }

    end {
        Write-Output "Removed tag from $($media.Count) items in $app"
    }
}

function Search-Media {
    <#
    .SYNOPSIS
    Initiates a search for media items in a specified application.

    .DESCRIPTION
    The Search-Media function initiates a search for media items in a specified application.
    It supports Radarr, Sonarr, and Lidarr applications.

    .PARAMETER App
    Specifies the name of the application. This parameter is mandatory.

    .PARAMETER ApiKey
    Specifies the API key for the application. This parameter is mandatory.

    .PARAMETER ApiVersion
    Specifies the API version for the application. This parameter is mandatory.

    .PARAMETER Media
    Specifies the media items to search for. This parameter is mandatory.

    .PARAMETER Url
    Specifies the URL of the application's API. This parameter is mandatory.

    .EXAMPLE
    PS C:\> Search-Media -App "Radarr" -ApiKey "your_api_key" -ApiVersion "v3" -Media $media -Url "http://localhost:7878"

    This command initiates a search for the specified media items in the Radarr application.

    .INPUTS
    System.String, System.Array. You can pipe a string that contains an application name, API key, API version, and URL, and an array that contains media items to the function.

    .OUTPUTS
    System.String. The function returns a string that indicates whether the search was successfully started.

    .NOTES
    The function throws an error if the API request fails.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]
        $App,

        [Parameter(Mandatory = $true, Position = 1)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true, Position = 2)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true, Position = 3)]
        [array]
        $Media,

        [Parameter(Mandatory = $true, Position = 4)]
        [string]
        $Url
    )

    begin {

        if ($media.Count -gt 1) {
            $mediaId = $media.id -join ','
        }

        else {
            $mediaId = $media.id
        }

        switch -Wildcard ($app) {
            'radarr*' {
                $body = "{`"name`":`"MoviesSearch`",`"movieIds`":[$mediaId]}"

            }
            'sonarr*' {
                $body = "{`"name`":`"SeriesSearch`",`"seriesId`":$mediaId}"
            }
            'lidarr*' {
                $body = "{`"name`":`"ArtistSearch`",`"artistId`":[$mediaId]}"
            }
        }

        $params = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Post'
            Uri                = "$url/api/$apiVersion/command"
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            Body               = $body
            ContentType        = 'application/json'
        }
    }

    process {
        $mediaSearch = Invoke-RestMethod @params

        if (Confirm-AppResponse -StatusCodeResponse $statusCode -FunctionName $($MyInvocation.MyCommand) -App $app) {
            Write-Verbose "Successfully started search for $($media.Count) items in $app"
        }
    }

    end {
        Write-Output "Searched started for $($media.Count) items in $app"
    }
}

function Send-DiscordMessage {
    <#
    .SYNOPSIS
    Sends a message to a Discord channel.

    .DESCRIPTION
    The Send-DiscordMessage function sends a message to a Discord channel.
    It supports sending a title, description, fields, embed color, thumbnail URL, and username.

    .PARAMETER MessageTitle
    Specifies the title of the message. This parameter is mandatory.

    .PARAMETER MessageDescription
    Specifies the description of the message. This parameter is mandatory.

    .PARAMETER Fields
    Specifies the fields of the message. This parameter is optional.

    .PARAMETER EmbedColor
    Specifies the color of the embed. This parameter is optional.

    .PARAMETER ThumbURL
    Specifies the URL of the thumbnail. This parameter is optional.

    .PARAMETER URL
    Specifies the URL of the Discord webhook. This parameter is mandatory.

    .PARAMETER Username
    Specifies the username to send the message as. This parameter is optional.

    .EXAMPLE
    PS C:\> Send-DiscordMessage -MessageTitle "Title" -MessageDescription "Description" -EmbedColor "Red" -URL "your_webhook_url"

    This command sends a message with the title "Title" and the description "Description" to the Discord channel associated with the specified webhook URL. The color of the embed is red.

    .INPUTS
    System.String, System.Collections.Generic.List[PSCustomObject]. You can pipe a string that contains the message title, message description, embed color, thumbnail URL, webhook URL, and username, and a list that contains the fields to the function.

    .OUTPUTS
    None. The function sends a message to a Discord channel and does not return any output.

    .NOTES
    The function throws an error if the API request fails.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $MessageTitle,

        [Parameter(Mandatory = $true)]
        [string]
        $MessageDescription,

        [Parameter(Mandatory = $false)]
        [System.Collections.Generic.List[PSCustomObject]]
        $Fields,

        [Parameter(Mandatory = $false)]
        [string]
        $EmbedColor,

        [Parameter(Mandatory = $false)]
        [string]
        $ThumbURL,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $URL,

        [Parameter(Mandatory = $false)]
        [string]
        $Username
    )

    switch ($embedColor) {
        'Aqua' { $embedColor = 1752220 }
        'DarkAqua' { $embedColor = 1146986 }
        'Green' { $embedColor = 5763719 }
        'DarkGreen' { $embedColor = 2067276 }
        'Blue' { $embedColor = 3447003 }
        'DarkBlue' { $embedColor = 2123412 }
        'Purple' { $embedColor = 10181046 }
        'DarkPurple' { $embedColor = 7419530 }
        'LuminousVividPink' { $embedColor = 15277667 }
        'DarkVividPink' { $embedColor = 11342935 }
        'Gold' { $embedColor = 15844367 }
        'DarkGold' { $embedColor = 12745742 }
        'Orange' { $embedColor = 15105570 }
        'DarkOrange' { $embedColor = 11027200 }
        'Red' { $embedColor = 15548997 }
        'DarkRed' { $embedColor = 10038562 }
        'Grey' { $embedColor = 9807270 }
        'DarkGrey' { $embedColor = 9936031 }
        'DarkerGrey' { $embedColor = 8359053 }
        'LightGrey' { $embedColor = 12370112 }
        'Navy' { $embedColor = 3426654 }
        'DarkNavy' { $embedColor = 2899536 }
        'Yellow' { $embedColor = 16776960 }
        Default { $embedColor = 0 }
    }

    $body = [PSCustomObject]@{
        avatar_url = $thumbUrl
        username   = $username
        embeds     = @(
            [PSCustomObject]@{
                title       = $messageTitle
                description = $messageDescription
                color       = $embedColor
                fields      = $fields
                thumbnail   = @{
                    url = $thumbUrl
                }
            }
        )
    } | ConvertTo-Json -Depth 50

    Invoke-RestMethod -Uri $url -Body $body -Method Post -ContentType 'application/json'
}

if ($apps[0] -match '[ ,]') {
    $apps = $apps[0] -split '[ ,]+'
}

if ($PSBoundParameters.ContainsKey('ConfigFile')) {
    if (-Not (Test-Path $configFile)) {
        throw 'Config file not found'
    }
    else {
        Write-Verbose 'Reading config file'
        $config = Read-ConfigFile -File $configFile
    }
}

else {
    Write-Verbose 'Reading config file'
    $config = Read-ConfigFile -File $configFile
}

foreach ($app in $apps) {
    $app = $((Get-Culture).TextInfo.ToTitleCase($app))

    switch -Wildcard ($app) {
        'lidarr*' {
            Write-Verbose 'Valid application specified'
        }
        'prowlarr*' {
            throw 'Really? There is nothing for me to search in Prowlarr'
        }
        'radarr*' {
            Write-Verbose 'Valid application specified'
        }
        'sonarr*' {
            Write-Verbose 'Valid application specified'
        }
        'whisparr*' {
            throw 'Whisparr is not supported'
        }
        'readarr*' {
            throw 'Readarr is not supported'
        }
        Default {
            throw 'This error should not be triggered - open a GitHub issue'
        }
    }

    Confirm-Config -Config $config -App $app

    $appConfig = $config.$($app)

    if ($config.General.DiscordWebhook -ne '') {
        Write-Verbose 'Discord webhook specified, notifications will be sent'

        $sendDiscordNotification = $true
        $discordWebhook = $config.General.DiscordWebhook
    }

    else {
        Write-Verbose 'No Discord Webhook specified, no notifications will be sent'
        $sendDiscordNotification = $false
    }

    $apiKey = $appConfig.ApiKey
    $app = (Get-Culture).TextInfo.ToTitleCase($app)
    $count = $appConfig.Count
    $monitored = [System.Convert]::ToBoolean($appConfig.Monitored)
    $qualityProfileName = $appConfig.QualityProfileName
    $ignoreTag = $appConfig.IgnoreTag
    $runUnattended = [System.Convert]::ToBoolean($appConfig.Unattended)
    $url = ($appConfig.Url).TrimEnd('/')
    $apiVersion = Get-CurrentAPIVersion -App $app -ApiKey $apiKey -Url $url
    $tagName = $appConfig.TagName
    $tagId = Get-TagId -App $app -ApiKey $apiKey -ApiVersion $apiVersion -TagName $tagName -Url $url

    if ($app -like 'radarr*') {
        if ($appConfig.MovieStatus -ne '') {
            Write-Verbose "Movie status specified for $app"
            $status = $appConfig.MovieStatus
        }
        else {
            Write-Verbose "No movie status specified for $app"
        }
    }
    elseif ($app -like 'sonarr*') {
        if ($appConfig.SeriesStatus -ne '') {
            Write-Verbose "Series status specified for $app"
            $status = $appConfig.SeriesStatus
        }
        else {
            Write-Verbose "No series status specified for $app"
        }
    }
    elseif ($app -like 'lidarr*') {
        if ($appConfig.ArtistStatus -ne '') {
            Write-Verbose "Artist status specified for $app"
            $status = $appConfig.ArtistStatus
        }
        else {
            Write-Verbose "No artist status specified for $app"
        }
    }

    if ($ignoreTag -ne '') {
        Write-Verbose "Retrieving `"Ignore Tags`" ID"
        $ignoreTagId = Get-TagId -App $app -ApiKey $apiKey -ApiVersion $apiVersion -TagName $ignoreTag -Url $url
    }
    else {
        Write-Verbose 'No Ignore Tags specified'
    }

    if ($appConfig.QualityProfileName -ne '') {
        Write-Verbose "Retrieving `"Quality Profile Name`" ID"

        $qualityProfileId = Get-QualityProfileId -App $app -ApiKey $apiKey -ApiVersion $apiVersion -QualityProfileName $qualityProfileName
    }
    else {
        Write-Verbose 'No Quality Profile Name specified'
    }

    Write-Output "Starting $app search"
    Write-Output "Config - $app - URL: $url"
    Write-Output "Config - $app - Monitored: $monitored"

    if ($null -ne $status) {
        Write-Output "Config - $app - Status: $status"
    }
    else {
        Write-Output "Config - $app - Status: All"
    }

    Write-Output "Config - $app - Unattended: $runUnattended"
    Write-Output "Config - $app - Limit: $count"
    Write-Output "Config - $app - Tag Name: $tagName"
    Write-Output "Config - $app - Tag ID: $tagId"

    if ($null -ne $ignoreTagId) {
        Write-Output "Config - $app - Ignore Tag: $ignoreTag"
        Write-Output "Config - $app - Ignore Tag ID: $ignoreTagId"
    }
    else {
        Write-Output "Config - $app - Ignore Tag: None"
    }

    if ($null -ne $qualityProfileId) {
        Write-Output "Config - $app - Quality Profile Name: $qualityProfileName"
        Write-Output "Config - $app - Quality Profile ID: $qualityProfileId"
    }
    else {
        Write-Output "Config - $app - Quality Profile Name: None"
    }

    if ($app -like 'radarr*') {
        Write-Verbose "Retrieving movies from $app"
        $allMovies = Get-AppMedia -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Url $url

        Write-Verbose "Retrieved a total of $($allMovies.Count) movies from $app"

        if ($null -ne $status) {
            Write-Verbose "Filtering movies that have `"Monitored: $monitored`", `"Status: $status`", and don't have `"Tag ID: $tagId`""

            $filteredMovies = $allMovies | Where-Object { $_.monitored -eq $monitored -and $_.tags -notcontains $tagId -and $_.status -eq $status }

            Write-Verbose "Filtered movies from $($allMovies.count) to $($filteredMovies.Count) movies from $app"
        }

        else {
            Write-Verbose "Filtering movies that have `"Monitored: $monitored`", and don't have `"Tag ID: $tagId`""

            $filteredMovies = $allMovies | Where-Object { $_.monitored -eq $monitored -and $_.tags -notcontains $tagId }

            Write-Verbose "Filtered movies from $($allMovies.count) to $($filteredMovies.Count) movies from $app"
        }

        if ($null -ne $qualityProfileId) {
            Write-Verbose "Filtering movies that have `"Quality Profile ID: $qualityProfileId`""

            $filteredMovies = $filteredMovies | Where-Object { $_.qualityProfileId -eq $qualityProfileId }

            Write-Verbose "Filtered movies to $($filteredMovies.Count) movies from $app"
        }

        if ($null -ne $ignoreTagId) {
            Write-Verbose "Filtering movies that don't contain `"Ignore Tag ID: $ignoreTagId`""

            $filteredMovies = $filteredMovies | Where-Object { $_.tags -notcontains $ignoreTagId }

            Write-Verbose "Filtered movies to $($filteredMovies.Count) movies from $app"
        }

        if ($count -eq 'max') {
            Write-Verbose 'No limit specified, searching for all filtered movies'
            $mediaToSearch = $filteredMovies
        }
        else {
            Write-Verbose "Limiting movie search to $count"
            $mediaToSearch = Get-Random -InputObject $filteredMovies -Count $count
        }

        if ($filteredMovies.Count -eq 0 -and $runUnattended) {
            Write-Output "Running unattended and no movies left to search. Removing `"Tag ID: $tagId`" from all movies and starting search again"

            if ($null -ne $status) {
                Write-Verbose "Finding all movies with `"Tag ID: $tagId`""
                $filteredMovies = $allMovies | Where-Object { $_.monitored -eq $monitored -and $_.tags -contains $tagId -and $_.status -eq $status }
                Write-Verbose "Filtered movies from $($allMovies.count) to $($filteredMovies.Count) movies from $app"
            }
            else {
                Write-Verbose "Finding all movies with `"Tag ID: $tagId`""
                $filteredMovies = $allMovies | Where-Object { $_.monitored -eq $monitored -and $_.tags -contains $tagId }
                Write-Verbose "Filtered movies from $($allMovies.count) to $($filteredMovies.Count) movies from $app"
            }

            if ($null -ne $qualityProfileId) {
                Write-Verbose "Filtering movies that have `"Quality Profile ID: $qualityProfileId`""
                $filteredMovies = $filteredMovies | Where-Object { $_.qualityProfileId -eq $qualityProfileId }
                Write-Verbose "Filtered movies to $($filteredMovies.Count) movies from $app"
            }

            if ($null -ne $ignoreTagId) {
                Write-Verbose "Filtering movies that don't contain `"Ignore Tag ID: $ignoreTagId`""
                $filteredMovies = $filteredMovies | Where-Object { $_.tags -notcontains $ignoreTagId }
                Write-Verbose "Filtered movies to $($filteredMovies.Count) movies from $app"
            }

            Write-Verbose "Unattended: Found $($filteredMovies.Count) movies with `"Tag ID: $tagId`""

            if ($filteredMovies.Count -eq 0) {
                if ($sendDiscordNotification) {
                    $movieTitleList = $mediaToSearch.title | ForEach-Object { "* $_" }
                    $messageDescription = "No movies left to search, is the ignore tag applied to all movies?`n* Tag Name: `"$ignoreTag`"`n* Tag ID: `"$($ignoreTagId)`" "

                    $discordMessageParams = @{
                        MessageTitle       = "Upgradinatorr - $app"
                        MessageDescription = $messageDescription
                        EmbedColor         = 'Red'
                        ThumbURL           = 'https://gh.notifiarr.com/images/icons/radarr.png'
                        URL                = $discordWebhook
                        Username           = "Upgradinatorr - $app"
                    }

                    Send-DiscordMessage @discordMessageParams
                }
                throw 'No movies left to search, is the ignore tag applied to all movies?'
            }

            else {
                Remove-TagFromMedia -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Media $filteredMovies -TagId $tagId -Url $url

                if ($count -eq 'max') {
                    Write-Verbose 'No limit specified, searching for all filtered movies'
                    $mediaToSearch = $filteredMovies
                }
                else {
                    Write-Verbose "Limiting movie search to $count"
                    $mediaToSearch = Get-Random -InputObject $filteredMovies -Count $count
                }

                Search-Media -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Media $mediaToSearch -Url $url

                Add-TagToMedia -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Media $mediaToSearch -TagId $tagId -Url $url

                if ($sendDiscordNotification) {
                    $movieTitleList = $mediaToSearch.title | ForEach-Object { "* $_" }
                    $messageDescription = "Upgradinatorr kicked off search for: `n $($movieTitleList -join `"`n`")"

                    if ($messageDescription.Length -gt 4096) {
                        Write-Warning 'Discord only allows 4096 characters in the description, sending generic message without movie titles list'

                        $messageDescription = "Upgradinatorr kicked off search for $($mediaToSearch.Count) movies"
                    }

                    $discordMessageParams = @{
                        MessageTitle       = "Upgradinatorr - $app"
                        MessageDescription = $messageDescription
                        EmbedColor         = 'Green'
                        ThumbURL           = 'https://gh.notifiarr.com/images/icons/radarr.png'
                        URL                = $discordWebhook
                        Username           = "Upgradinatorr - $app"
                    }

                    Send-DiscordMessage @discordMessageParams
                }
            }
        }

        elseif ($filteredMovies.Count -eq 0 -and -Not $runUnattended) {
            if ($sendDiscordNotification) {
                $discordMessageParams = @{
                    MessageTitle       = "Upgradinatorr - $app"
                    MessageDescription = 'No movies left to search!'
                    EmbedColor         = 'Red'
                    ThumbURL           = 'https://gh.notifiarr.com/images/icons/radarr.png'
                    URL                = $discordWebhook
                    Username           = "Upgradinatorr - $app"
                }

                Send-DiscordMessage @discordMessageParams
            }
            throw 'No movies left to search'
        }

        else {
            Write-Output "Searching for $($mediaToSearch.Count) movies from $app"

            Search-Media -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Media $mediaToSearch -Url $url

            Write-Output "Adding tag `"$tagName`" to $($mediaToSearch.Count) movies in $app"

            Add-TagToMedia -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Media $mediaToSearch -TagId $tagId -Url $url

            if ($sendDiscordNotification) {
                $movieTitleList = $mediaToSearch.title | ForEach-Object { "* $_" }
                $messageDescription = "Upgradinatorr kicked off search for: `n $($movieTitleList -join `"`n`")"

                if ($messageDescription.Length -gt 4096) {
                    Write-Warning 'Discord only allows 4096 characters in the description, sending generic message without movie titles list'

                    $messageDescription = "Upgradinatorr kicked off search for $($mediaToSearch.Count) movies"
                }

                $discordMessageParams = @{
                    MessageTitle       = "Upgradinatorr - $app"
                    MessageDescription = $messageDescription
                    EmbedColor         = 'Green'
                    ThumbURL           = 'https://gh.notifiarr.com/images/icons/radarr.png'
                    URL                = $discordWebhook
                    Username           = "Upgradinatorr - $app"
                }

                Send-DiscordMessage @discordMessageParams
            }
        }
    }

    if ($app -like 'sonarr*') {
        Write-Verbose "Retrieving series from $app"
        $allSeries = Get-AppMedia -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Url $url

        Write-Verbose "Retrieved a total of $($allSeries.Count) series from $app"

        if ($null -ne $status) {
            Write-Verbose "Filtering series that have `"Monitored: $monitored`", `"Status: $status`", and don't have `"Tag ID: $tagId`""

            $filteredSeries = $allSeries | Where-Object { $_.monitored -eq $monitored -and $_.tags -notcontains $tagId -and $_.status -eq $status }

            Write-Verbose "Filtered series from $($allSeries.count) to $($filteredSeries.Count) series from $app"
        }

        else {
            Write-Verbose "Filtering series that have `"Monitored: $monitored`", and don't have `"Tag ID: $tagId`""

            $filteredSeries = $allSeries | Where-Object { $_.monitored -eq $monitored -and $_.tags -notcontains $tagId }

            Write-Verbose "Filtered series from $($allSeries.count) to $($filteredSeries.Count) series from $app"
        }

        if ($null -ne $qualityProfileId) {
            Write-Verbose "Filtering series that have `"Quality Profile ID: $qualityProfileId`""

            $filteredSeries = $filteredSeries | Where-Object { $_.qualityProfileId -eq $qualityProfileId }

            Write-Verbose "Filtered series to $($filteredSeries.Count) series from $app"
        }

        if ($null -ne $ignoreTagId) {
            Write-Verbose "Filtering series that don't contain `"Ignore Tag ID: $ignoreTagId`""

            $filteredSeries = $filteredSeries | Where-Object { $_.tags -notcontains $ignoreTagId }

            Write-Verbose "Filtered series to $($filteredSeries.Count) series from $app"
        }

        if ($count -eq 'max') {
            Write-Verbose 'No limit specified, searching for all filtered series'
            $mediaToSearch = $filteredSeries
        }
        else {
            Write-Verbose "Limiting series search to $count"
            $mediaToSearch = Get-Random -InputObject $filteredSeries -Count $count
        }

        if ($filteredSeries.Count -eq 0 -and $runUnattended) {
            Write-Output "Running unattended and no series left to search. Removing `"Tag ID: $tagId`" from all series and starting search again"

            if ($null -ne $status) {
                Write-Verbose "Finding all series with `"Tag ID: $tagId`""
                $filteredSeries = $allSeries | Where-Object { $_.monitored -eq $monitored -and $_.tags -contains $tagId -and $_.status -eq $status }
                Write-Verbose "Filtered series from $($allSeries.count) to $($filteredSeries.Count) series from $app"
            }
            else {
                Write-Verbose "Finding all series with `"Tag ID: $tagId`""
                $filteredSeries = $allSeries | Where-Object { $_.monitored -eq $monitored -and $_.tags -contains $tagId }
                Write-Verbose "Filtered series from $($allSeries.count) to $($filteredSeries.Count) series from $app"
            }

            if ($null -ne $qualityProfileId) {
                Write-Verbose "Filtering series that have `"Quality Profile ID: $qualityProfileId`""
                $filteredSeries = $filteredSeries | Where-Object { $_.qualityProfileId -eq $qualityProfileId }
                Write-Verbose "Filtered series to $($filteredSeries.Count) series from $app"
            }

            if ($null -ne $ignoreTagId) {
                Write-Verbose "Filtering series that don't contain `"Ignore Tag ID: $ignoreTagId`""
                $filteredSeries = $filteredSeries | Where-Object { $_.tags -notcontains $ignoreTagId }
                Write-Verbose "Filtered series to $($filteredSeries.Count) series from $app"
            }

            if ($filteredMovies.Count -eq 0) {
                if ($sendDiscordNotification) {
                    $movieTitleList = $mediaToSearch.title | ForEach-Object { "* $_" }
                    $messageDescription = "No series left to search, is the ignore tag applied to all series?`n* Tag Name: `"$ignoreTag`"`n* Tag ID: `"$($ignoreTagId)`" "

                    $discordMessageParams = @{
                        MessageTitle       = "Upgradinatorr - $app"
                        MessageDescription = $messageDescription
                        EmbedColor         = 'Red'
                        ThumbURL           = 'https://gh.notifiarr.com/images/icons/sonarr.png'
                        URL                = $discordWebhook
                        Username           = "Upgradinatorr - $app"
                    }

                    Send-DiscordMessage @discordMessageParams
                }
                throw 'No series left to search, is the ignore tag applied to all series?'
            }

            else {
                Write-Verbose "Unattended: Found $($filteredSeries.Count) series with `"Tag ID: $tagId`""

                Remove-TagFromMedia -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Media $filteredSeries -TagId $tagId -Url $url

                if ($count -eq 'max') {
                    Write-Verbose 'No limit specified, searching for all filtered series'
                    $mediaToSearch = $filteredSeries
                }
                else {
                    Write-Verbose "Limiting series search to $count"
                    $mediaToSearch = Get-Random -InputObject $filteredSeries -Count $count
                }

                # Sonarr doesn't allow passing multiple series in an API call, so we need to loop through each series and search for it individually
                foreach ($seriesToSearch in $mediaToSearch) {
                    Search-Media -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Media $seriesToSearch -Url $url
                }

                Add-TagToMedia -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Media $mediaToSearch -TagId $tagId -Url $url

                if ($sendDiscordNotification) {
                    $seriesTitleList = $mediaToSearch.title | ForEach-Object { "* $_" }
                    $messageDescription = "Upgradinatorr kicked off search for: `n $($seriesTitleList -join `"`n`")"

                    if ($messageDescription.Length -gt 4096) {
                        Write-Warning 'Discord only allows 4096 characters in the description, sending generic message without series titles list'

                        $messageDescription = "Upgradinatorr kicked off search for $($mediaToSearch.Count) series"
                    }

                    $discordMessageParams = @{
                        MessageTitle       = "Upgradinatorr - $app"
                        MessageDescription = $messageDescription
                        EmbedColor         = 'Green'
                        ThumbURL           = 'https://gh.notifiarr.com/images/icons/sonarr.png'
                        URL                = $discordWebhook
                        Username           = "Upgradinatorr - $app"
                    }

                    Send-DiscordMessage @discordMessageParams
                }
            }

        }

        elseif ($filteredSeries.Count -eq 0 -and -Not $runUnattended) {
            if ($sendDiscordNotification) {
                $discordMessageParams = @{
                    MessageTitle       = "Upgradinatorr - $app"
                    MessageDescription = 'No series left to search!'
                    EmbedColor         = 'Red'
                    ThumbURL           = 'https://gh.notifiarr.com/images/icons/sonarr.png'
                    URL                = $discordWebhook
                    Username           = "Upgradinatorr - $app"
                }

                Send-DiscordMessage @discordMessageParams
            }

            throw 'No series left to search'
        }

        else {
            Write-Output "Searching for $($mediaToSearch.Count) series from $app"

            # Sonarr doesn't allow passing multiple series in an API call, so we need to loop through each series and search for it individually
            foreach ($seriesToSearch in $mediaToSearch) {
                Search-Media -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Media $seriesToSearch -Url $url
            }

            Write-Output "Adding tag `"$tagName`" to $($mediaToSearch.Count) series in $app"

            Add-TagToMedia -App $app -ApiKey $apiKey -ApiVersion $apiVersion -Media $mediaToSearch -TagId $tagId -Url $url

            if ($sendDiscordNotification) {
                $seriesTitleList = $mediaToSearch.title | ForEach-Object { "* $_" }
                $messageDescription = "Upgradinatorr kicked off search for: `n $($seriesTitleList -join `"`n`")"

                if ($messageDescription.Length -gt 4096) {
                    Write-Warning 'Discord only allows 4096 characters in the description, sending generic message without series titles list'

                    $messageDescription = "Upgradinatorr kicked off search for $($mediaToSearch.Count) series"
                }

                $discordMessageParams = @{
                    MessageTitle       = "Upgradinatorr - $app"
                    MessageDescription = $messageDescription
                    EmbedColor         = 'Green'
                    ThumbURL           = 'https://gh.notifiarr.com/images/icons/sonarr.png'
                    URL                = $discordWebhook
                    Username           = "Upgradinatorr - $app"
                }

                Send-DiscordMessage @discordMessageParams
            }
        }
    }

    if ($app -like 'lidarr*') {
        Write-Output 'To do lol'
    }
}
