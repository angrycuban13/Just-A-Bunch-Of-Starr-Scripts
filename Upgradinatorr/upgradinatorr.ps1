<#
.SYNOPSIS
    Manages media upgrades by kicking off a manual search in Starr applications (Radarr/Sonarr/Lidarr).

.DESCRIPTION
    The Upgradinatorr script automates media upgrades in Starr applications by triggering a manual search for media items that meet specific criteria. While the Starr applications already look for better quality media, it only "searches forward". If you modify a Custom Format, media items that were previously ignored will not be picked up by the automatic search. This script allows you to manually look forward and backward to find media items that can be upgraded.

.PARAMETER ApplicationList
    Array of Starr applications to process.
    Aliases : Apps, AppsList
    Required: True

.PARAMETER ConfigurationFile
    Path to the configuration file.
    Aliases: Config, ConfigFile
    Default: "./upgradinatorr.conf"
    Required: False

.EXAMPLE
    ./Upgradinatorr.ps1 -ApplicationList "Radarr","Sonarr" -ConfigurationFile "custom.conf"
    # Process Radarr and Sonarr using custom config file

.EXAMPLE
    ./Upgradinatorr.ps1 -Apps "Lidarr"
    # Process Lidarr using default config file

.NOTES
    Author      : angrycuban13
    Dependencies: None
    Requires    : PowerShell 7+
    Version     : 3.0

    Special thanks to Roxedus and austinwbest for giving me a guiding hand at the beginning of this script.
#>

#Requires -Version 7

[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter(Mandatory = $true)]
    [Alias('Apps', 'AppsList')]
    [string[]]
    $ApplicationList,

    [Parameter(Mandatory = $false)]
    [Alias('Config', 'ConfigFile')]
    [System.IO.FileInfo]
    $ConfigurationFile = (Join-Path -Path $PSScriptRoot -ChildPath "upgradinatorr.conf")
)

$ErrorActionPreference = 'Stop'

function Add-StarrMediaTag {
    <#
    .SYNOPSIS
        Adds specified tag to media items in a Starr application.

    .DESCRIPTION
        Adds a tag to specified media items in Radarr, Sonarr, or Lidarr using their respective APIs.
        Handles different media types appropriately:
        - Radarr: Movies tagging
        - Sonarr: Series tagging
        - Lidarr: Artist tagging

    .PARAMETER ApiKey
        The API key for the Starr application.

    .PARAMETER ApiVersion
        The API version of the Starr application (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr/Lidarr).

    .PARAMETER Media
        Array of media objects to add the tag to.

    .PARAMETER TagId
        The ID of the tag to add.

    .PARAMETER Url
        The base URL of the Starr application (e.g., http://localhost:7878).

    .EXAMPLE
        Add-StarrMediaTag -ApiKey "1234..." -ApiVersion "v3" -Application "Radarr" -Media $movieArray -TagId 1 -Url "http://localhost:7878"
        # Adds tag ID 1 to specified movies in Radarr

    .EXAMPLE
        Add-StarrMediaTag -ApiKey "1234..." -ApiVersion "v3" -Application "Sonarr" -Media $seriesArray -TagId 2 -Url "http://localhost:8989"
        # Adds tag ID 2 to specified series in Sonarr

    .OUTPUTS
        None. Displays verbose message when tag is added.

    .NOTES
        - Requires valid API key and accessible application URL
        - Uses Confirm-StarrApiResponse for error handling
        - Supports batch operations via media array
        - Tag operations are processed synchronously
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]
        $Application,

        [Parameter(Mandatory = $true)]
        [System.Object[]]
        $Media,

        [Parameter(Mandatory = $true)]
        [int]
        $TagId,

        [Parameter(Mandatory = $true)]
        [string]
        $Url
    )

    begin {
        # Join media IDs into a comma-separated string
        $mediaId = $media.id -join ','

        # Determine the API endpoint and body based on the application
        switch -Regex ($application) {
            "radarr" {
                $body = "{`"movieIds`":[$mediaId],`"tags`":[$($tagId)],`"applyTags`":`"add`"}"
                $apiEndpoint = 'movie/editor'
            }
            "sonarr" {
                $body = "{`"seriesIds`":[$mediaId],`"tags`":[$tagId],`"applyTags`":`"add`"}"
                $apiEndpoint = 'series/editor'

            }
            "lidarr" {
                $body = "{`"artistIds`":[$mediaId],`"tags`":[$tagId], `"applyTags`":`"add`"}"
                $apiEndpoint = 'artist/editor'
            }
        }

        # Create a splat for Invoke-RestMethod
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
        # Make the API call to add the tag to media items
        $apiResponse = Invoke-RestMethod @params
    }

    end {
        # Check the response status code and display success message if successful
        if (Confirm-StarrApiResponse -Application $application -Function $MyInvocation.MyCommand -StatusCode $statusCode) {
            Write-Verbose "Tag added to $($media.Count) media items in $application"
        }
    }
}

function Confirm-Application {
    <#
    .SYNOPSIS
        Validates if the specified application is a supported Starr application.

    .DESCRIPTION
        The Confirm-Application function checks if the provided application name
        is one of the supported Starr applications (Radarr, Sonarr, or Lidarr).
        It performs a case-insensitive validation using regex pattern matching.

    .PARAMETER Application
        The name of the application to validate. Must be one of: radarr, sonarr, or lidarr.
        This parameter is case-insensitive.

    .EXAMPLE
        Confirm-Application -Application "radarr"
        # Validates that radarr is a supported application

    .EXAMPLE
        Confirm-Application -Application "plex"
        # Throws an error as plex is not a supported application

    .OUTPUTS
        None. The function throws an error if the application is not supported.

    .NOTES
        Supported applications:
        - Radarr
        - Sonarr
        - Lidarr
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Application
    )

    begin {}

    process {
        switch -Regex ($application) {
            "radarr|sonarr|lidarr" {
                Write-Verbose "$application is a supported application"
            }
            default {
                throw "$application is not a supported application"
            }
        }
    }

    end {}
}

function Confirm-Configuration {
    <#
    .SYNOPSIS
        Validates configuration settings for Starr applications (Radarr/Sonarr/Lidarr) and notification services.

    .DESCRIPTION
        The Confirm-Configuration function performs comprehensive validation of configuration settings for *arr applications and notification services. It checks:
        - API key format and length
        - URL formatting
        - Status values for different media types
        - Monitored and unattended flags
        - Tag name presence
        - Discord and Notifiarr webhook formatting
        - Configuration value quote validation

    .PARAMETER Configuration
        PSCustomObject containing the configuration settings to validate. Should include sections for each application
        and notifications with their respective settings.

    .PARAMETER Section
        String specifying which section to validate. Can be 'Quotes', 'Notifications', or an application name (e.g., 'Radarr').

    .EXAMPLE
        $config = Read-ConfigurationFile -File "config.ini"
        $isValid = Confirm-Configuration -Configuration $config -Section "Quotes"
        # Validates entire configuration including quote checks

    .EXAMPLE
        $isValid = Confirm-Configuration -Configuration $config -Section "Notifications"
        # Validates only Discord and Notifiarr webhook settings

    .EXAMPLE
        $isValid = Confirm-Configuration -Configuration $config -Section "Radarr"
        # Validates Radarr-specific settings including API key, URL, and movie status

    .OUTPUTS
        [Boolean]
        Returns $true if all validations pass, $false if any validation fails.

    .NOTES
        Validation Rules:
        - API Keys must be 32 characters
        - URLs must start with http:// or https://
        - Count must be 'max' or a positive integer
        - Monitored and Unattended must be 'true' or 'false'
        - Movie/Series/Artist status must match predefined values
        - Discord webhooks must match specific URL pattern
        - Notifiarr webhooks must match UUID pattern
        - No quotes allowed in configuration values
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [PSCustomObject]
        $Configuration,

        [Parameter(Mandatory = $true)]
        [String]
        $Section
    )

    begin {
        $errorCount = 0
        $monitoredValues = @('true', 'false')
        $statusValuesForArtists = @('continuing', 'ended')
        $statusValuesForMovies = @('tba', 'announced', 'inCinemas', 'released', 'deleted')
        $statusValuesForSeries = @('continuing', 'ended', 'upcoming', 'deleted')
        $unattendedValues = @('true', 'false')
        $urlRegexMatch = '^(http|https)://'
        $webhookRegexMatchDiscord = 'https://discord\.com/api/webhooks/\d{17,19}/[A-Za-z0-9_-]{68,}'
        $webhookRegexMatchNotifiarrPassthrough = 'https://notifiarr.com/api/v1/notification/passthrough/[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}'
    }

    process {
        # Add quote validation before other checks
        if ($section -eq "Quotes") {
            $configuration.PSObject.Properties | ForEach-Object {
                $sectionName = $_.Name
                $sectionValues = $_.Value

                foreach ($configurationValue in $sectionValues.GetEnumerator()) {
                    if ($configurationValue.Value -match '"') {
                        Write-Warning "Configuration value for `"$($configurationValue.Key)`" in the $sectionName configuration contains quotes which are not allowed. Please remove all quotes from your configuration."
                        $errorCount++
                    }
                }
            }
        }

        # Validate the Notifications section
        elseif ($section -eq 'Notifications') {
            # Check if the Discord Webhook has been specified
            if ((-Not [string]::IsNullOrWhiteSpace($configuration.Notifications.DiscordWebhook)) -or (-Not [string]::IsNullOrWhiteSpace($configuration.General.DiscordWebhook))) {
                Write-Verbose "Discord Webhook has been specified, verifying it is formatted correctly"

                # Validate the Discord Webhook URL is formatted correctly
                if (-Not [string]::IsNullOrWhiteSpace($configuration.Notifications.DiscordWebhook)) {
                    if ($configuration.Notifications.DiscordWebhook -notmatch $webhookRegexMatchDiscord) {
                        Write-Warning "Discord Webhook in Notifications section is not formatted correctly, it should look like `"https://discord.com/api/webhooks/Id123/Token123`""
                        $errorCount++
                    }
                }
                if (-Not [string]::IsNullOrWhiteSpace($configuration.General.DiscordWebhook)) {
                    if ($configuration.General.DiscordWebhook -notmatch $webhookRegexMatchDiscord) {
                        Write-Warning "Discord Webhook in General section is not formatted correctly, it should look like `"https://discord.com/api/webhooks/Id123/Token123`""
                        $errorCount++
                    }
                }
            }

            # Check if the Notifiarr Passthrough Webhook has been specified
            if ((-Not [string]::IsNullOrWhiteSpace($configuration.Notifications.NotifiarrPassthroughWebhook)) -or (-Not [string]::IsNullOrWhiteSpace($configuration.General.NotifiarrPassthroughWebhook))) {
                Write-Verbose "Notifiarr Passthrough Webhook has been specified, verifying it is formatted correctly"

                # Validate the Discord Webhook URL is formatted correctly
                if (-Not [string]::IsNullOrWhiteSpace($configuration.Notifications.NotifiarrPassthroughWebhook)) {
                    if ($configuration.Notifications.NotifiarrPassthroughWebhook -notmatch $webhookRegexMatchNotifiarrPassthrough) {
                        Write-Warning "Notifiarr Passthrough Webhook is not formatted correctly, it should look like `"https://notifiarr\.com/api/v1/notification/passthrough/uuid-uuid-uuid-uuid-uuid`""
                        $errorCount++
                    }
                    if ($configuration.Notifications.NotifiarrPassthroughDiscordChannelId -notmatch '^\d{17,19}$') {
                        Write-Warning "Notifiarr Passthrough Discord Channel ID is not formatted correctly, it should be a 17-19 digit number"
                        $errorCount++
                    }
                }

                if (-Not [string]::IsNullOrWhiteSpace($configuration.General.NotifiarrPassthroughWebhook)) {
                    if ($configuration.General.NotifiarrPassthroughWebhook -notmatch $webhookRegexMatchNotifiarrPassthrough) {
                        Write-Warning "Notifiarr Passthrough Webhook is not formatted correctly, it should look like `"https://notifiarr\.com/api/v1/notification/passthrough/uuid-uuid-uuid-uuid-uuid`""
                        $errorCount++
                    }
                    if ($configuration.General.NotifiarrPassthroughDiscordChannelId -notmatch '^\d{17,19}$') {
                        Write-Warning "Notifiarr Passthrough Discord Channel ID is not formatted correctly, it should be a 17-19 digit number"
                        $errorCount++
                    }
                }
            }
        }

        # Validate the application sections
        else {
            $applicationName = $section
            $applicationConfig = $configuration.$applicationName

            # Validate API Key
            Write-Verbose "Validating `"ApiKey`" for `"$applicationName`""
            if ($applicationConfig.ApiKey.Length -ne 32) {
                Write-Warning "API Key for `"$applicationName`" is not 32 characters long"
                $errorCount++
            }

            # Validate Count
            Write-Verbose "Validating `"Count`" for `"$applicationName`""
            if ($applicationConfig.Count -ne 'max') {
                try {
                    $num = [int]$applicationConfig.Count
                    if ($num -lt 1) {
                        Write-Warning "Count for `"$applicationName`" is not a valid value, it should be greater than 0 or equal to `"max`""
                        $errorCount++
                    }
                }
                catch {
                    Write-Warning "Count for `"$applicationName`" is not a valid value, it should be an integer or equal to `"max`""
                    $errorCount++
                }
            }

            # Validate Monitored
            Write-Verbose "Validating `"Monitored`" for `"$applicationName`""
            if ($applicationConfig.Monitored -notin $monitoredValues) {
                Write-Warning "Monitored for `"$applicationName`" is not a valid value, it should be either `"$($monitoredValues[0])`" or `"$($monitoredValues[1])`""
                $errorCount++
            }

            # Validate Status based on application
            if ($applicationName -like "*Radarr*") {
                Write-Verbose "Validating `"MovieStatus`" for `"$applicationName`""
                if ($applicationConfig.MovieStatus -notin $statusValuesForMovies -and -Not [string]::IsNullOrWhiteSpace($applicationConfig.MovieStatus)) {
                    Write-Warning "MovieStatus for `"$applicationName`" is not a valid value, expected one of the following: $($statusValuesForMovies -join ', ')"
                    $errorCount++
                }
            }

            if ($applicationName -like "*Sonarr*") {
                Write-Verbose "Validating `"SeriesStatus`" for `"$applicationName`""
                if ($applicationConfig.SeriesStatus -notin $statusValuesForSeries -and -Not [string]::IsNullOrWhiteSpace($applicationConfig.SeriesStatus)) {
                    Write-Warning "SeriesStatus for `"$applicationName`" is not a valid value, expected one of the following: $($statusValuesForSeries -join ', ')"
                    $errorCount++
                }
            }

            if ($applicationName -like "*Lidarr*") {
                Write-Verbose "Validating `"ArtistStatus`" for `"$applicationName`""
                if ($applicationConfig.ArtistStatus -notin $statusValuesForArtists -and -Not [string]::IsNullOrWhiteSpace($applicationConfig.ArtistStatus)) {
                    Write-Warning "ArtistStatus for `"$applicationName`" is not a valid value, expected one of the following: $($statusValuesForArtists -join ', ')"
                    $errorCount++
                }
            }

            # Validate TagName
            Write-Verbose "Validating `"TagName`" for `"$applicationName`""
            if ([string]::IsNullOrWhiteSpace($applicationConfig.TagName)) {
                Write-Warning "A tag name must be specified for `"$applicationName`""
                $errorCount++
            }

            # Validate Unattended
            Write-Verbose "Validating `"Unattended`" for `"$applicationName`""
            if ($applicationConfig.Unattended -notin $unattendedValues) {
                Write-Warning "Unattended for `"$applicationName`" is not a valid value, it should be either `"$($unattendedValues[0])`" or `"$($unattendedValues[1])`""
                $errorCount++
            }

            # Validate URL
            Write-Verbose "Validating `"URL`" for `"$applicationName`""
            if ($applicationConfig.Url -notmatch $urlRegexMatch) {
                Write-Warning "URL for `"$applicationName`" is not formatted correctly, it should start with either `"http://`" or `"https://`""
                $errorCount++
            }
        }
    }

    end {
        # Return $true if no errors were found, $false otherwise
        if ($errorCount -gt 0) {
            $false
        }
        else {
            $true
        }
    }
}

function Confirm-StarrApiResponse {
    <#
    .SYNOPSIS
        Validates HTTP response codes from Starr application API calls.

    .DESCRIPTION
        Validates HTTP status codes returned from Starr applications (Radarr/Sonarr/Lidarr).
        Throws descriptive errors for common HTTP error codes and provides guidance for resolution.
        Returns true for successful (2xx) responses.

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr/Lidarr) making the API call.

    .PARAMETER FunctionName
        The name of the function that made the API call, used for error reporting.

    .PARAMETER StatusCode
        The HTTP status code returned from the API call.

    .EXAMPLE
        Confirm-StarrApiResponse -Application "Radarr" -FunctionName "Get-Movies" -StatusCode 200
        # Returns $true for successful response

    .EXAMPLE
        Confirm-StarrApiResponse -Application "Sonarr" -FunctionName "Get-Series" -StatusCode 401
        # Throws unauthorized error with guidance to check API key

    .OUTPUTS
        [Boolean]
        Returns $true for successful responses (2xx status codes).
        Throws an exception with detailed error message for other status codes.

    .NOTES
        Handled Status Codes:
        - 2xx: Success
        - 302: Redirect (missing URL base)
        - 400: Bad Request
        - 401: Unauthorized (invalid API key)
        - 404: Not Found
        - 409: Conflict
        - 500: Internal Server Error
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $Application,

        [Parameter(Mandatory = $true)]
        [string]
        $FunctionName,

        [Parameter(Mandatory = $true)]
        [int]
        $StatusCode
    )

    begin {}

    process {
        switch -Regex ( $statusCode ) {
            '2\d\d' {
                $true
            }
            302 {
                Write-Warning "$application responded with $statusCode when executing $functionName function"
                throw "Server responded with `"Redirect`" for $application. Are you missing the URL base?"
            }
            400 {
                Write-Warning "$application responded with $statusCode when executing $functionName function"
                throw "Server responded with `"Bad Request`" for $application. Please check your configuration"
            }
            401 {
                Write-Warning "$application responded with $statusCode when executing $functionName function"
                throw "Server responded with `"Unauthorized`" for $application. Please check your API key"
            }
            404 {
                Write-Warning "$application responded with $statusCode when executing $functionName function"
                throw "Server responded with `"Not Found`" for $application. Please check your configuration"
            }
            409 {
                Write-Warning "$application responded with $statusCode when executing $functionName function"
                throw "Server responded with `"Conflict`" for $application. Please check your configuration"
            }
            500 {
                Write-Warning "$application responded with $statusCode when executing $functionName function"
                throw "Server responded with `"Internal Server Error`" for $application. Please check your configuration"
            }
            default {
                Write-Warning "$application responded with $statusCode when executing $functionName"
                throw "Server responded with an unexpected HTTP status code $statusCode for $application. Please open a GitHub issue at https://github.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/issues"
            }
        }
    }

    end {}
}

function Get-StarrApiVersion {
    <#
    .SYNOPSIS
        Retrieves the current API version from a Starr application.

    .DESCRIPTION
        The Get-StarrApiVersion function makes a GET request to a Starr application's API
        endpoint to retrieve the current API version. Supports Radarr, Sonarr, and Lidarr.

    .PARAMETER ApiKey
        The API key required to authenticate with the Starr application.

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr/Lidarr).

    .PARAMETER Url
        The base URL of the Starr application (e.g., http://localhost:7878).

    .EXAMPLE
        Get-StarrApiVersion -ApiKey "1234..." -Application "Radarr" -Url "http://localhost:7878"
        # Returns the current API version number (e.g., "v3")

    .OUTPUTS
        [String]
        Returns the current API version of the specified Starr application.

    .NOTES
        Requires valid API key and accessible application URL.
        Uses Confirm-StarrApiResponse for error handling.
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true)]
        [string]
        $Application,

        [Parameter(Mandatory = $true)]
        [string]
        $Url
    )

    begin {
        # Create a splat for Invoke-RestMethod
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
        # Make the API call to get the API version
        $apiInfo = Invoke-RestMethod @params
    }

    end {
        # Check the response status code and return the API version if successful
        if (Confirm-StarrApiResponse -Application $application -Function $MyInvocation.MyCommand -StatusCode $statusCode) {
            $apiInfo.Current
        }
    }
}

function Get-StarrItemId {
    <#
    .SYNOPSIS
        Retrieves ID for a tag or quality profile from a Starr application.

    .DESCRIPTION
        Gets the ID of a tag or quality profile from a Starr application (Radarr/Sonarr/Lidarr).
        For tags, creates a new tag if it doesn't exist.
        For quality profiles, throws an error if the profile doesn't exist.

    .PARAMETER ApiKey
        The API key for the Starr application.

    .PARAMETER ApiVersion
        The API version of the Starr application (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr/Lidarr).

    .PARAMETER TagName
        The name of the tag to find or create. Part of 'Tag' parameter set.

    .PARAMETER QualityProfileName
        The name of the quality profile to find. Part of 'QualityProfile' parameter set.

    .PARAMETER Url
        The base URL of the Starr application (e.g., http://localhost:7878).

    .EXAMPLE
        Get-StarrItemId -ApiKey "1234..." -ApiVersion "v3" -Application "Radarr" -TagName "upgrade" -Url "http://localhost:7878"
        # Returns tag ID, creates tag if it doesn't exist

    .EXAMPLE
        Get-StarrItemId -ApiKey "1234..." -ApiVersion "v3" -Application "Radarr" -QualityProfileName "HD-1080p" -Url "http://localhost:7878"
        # Returns quality profile ID, throws error if profile doesn't exist

    .OUTPUTS
        [Int]
        Returns the ID of the requested tag or quality profile.

    .NOTES
        - Tags will be created automatically if they don't exist
        - Quality profiles must exist before calling this function
        - Uses Confirm-StarrApiResponse for error handling
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]
        $Application,

        [Parameter(Mandatory = $true, ParameterSetName = 'Tag')]
        [string]
        $TagName,

        [Parameter(Mandatory = $true, ParameterSetName = 'QualityProfile')]
        [string]
        $QualityProfileName,

        [Parameter(Mandatory = $true)]
        [string]
        $Url
    )

    begin {
        # Determine the API endpoint based on the parameter set
        if ($PSBoundParameters.ContainsKey('TagName')) {
            $uri = "$url/api/$apiVersion/tag"
        }

        if ($PSBoundParameters.ContainsKey('QualityProfileName')) {
            $uri = "$url/api/$apiVersion/qualityprofile"
        }

        # Create a splat for Invoke-RestMethod
        $params = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Get'
            Uri                = $uri
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            ContentType        = 'application/json'
        }
    }

    process {
        # If the TagName parameter is present, get the tag list and create the tag if it doesn't exist
        if ($PSBoundParameters.ContainsKey('TagName')) {
            $tagList = Invoke-RestMethod @params
            if (Confirm-StarrApiResponse -Application $application -Function $MyInvocation.MyCommand -StatusCode $statusCode) {
                $itemId = $tagList | Where-Object { $_.label -eq $tagName } | Select-Object -ExpandProperty id

                if ($null -eq $itemId) {
                    Write-Warning "Tag `"$tagName`" does not exist in $application, creating it now"

                    $itemId = New-StarrTag -ApiKey $apiKey -ApiVersion $apiVersion -Application $application -TagName $tagName -Url $url
                }
            }
        }

        # If the QualityProfileName parameter is present, get the quality profile list and return the ID if it exists. Throw an error if it doesn't.
        if ($PSBoundParameters.ContainsKey('QualityProfileName')) {
            $qualityProfileList = Invoke-RestMethod @params

            if (Confirm-StarrApiResponse -Application $application -Function $MyInvocation.MyCommand -StatusCode $statusCode) {
                $qualityProfileId = $qualityProfileList | Where-Object { $_.name -eq $qualityProfileName } | Select-Object -ExpandProperty id

                if ($null -eq $qualityProfileId) {
                    throw "Quality Profile `"$qualityProfileName`" does not exist in $application, please create it first"
                }

                $itemId = $qualityProfileList | Where-Object { $_.name -eq $qualityProfileName } | Select-Object -ExpandProperty id
            }
        }
    }

    end {
        $itemId
    }
}

function Get-StarrMedia {
    <#
    .SYNOPSIS
        Retrieves all media items from a Starr application.

    .DESCRIPTION
        Fetches all media items (movies/series/artists) from a Starr application's API.
        - Radarr: Returns all movies
        - Sonarr: Returns all series
        - Lidarr: Returns all artists

    .PARAMETER ApiKey
        The API key for the Starr application.

    .PARAMETER ApiVersion
        The API version of the Starr application (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr/Lidarr).

    .PARAMETER Url
        The base URL of the Starr application (e.g., http://localhost:7878).

    .EXAMPLE
        Get-StarrMedia -ApiKey "1234..." -ApiVersion "v3" -Application "Radarr" -Url "http://localhost:7878"
        # Returns all movies from Radarr

    .EXAMPLE
        Get-StarrMedia -ApiKey "1234..." -ApiVersion "v3" -Application "Sonarr" -Url "http://localhost:8989"
        # Returns all series from Sonarr

    .EXAMPLE
        Get-StarrMedia -ApiKey "1234..." -ApiVersion "v3" -Application "Lidarr" -Url "http://localhost:8686"
        # Returns all artists from Lidarr

    .OUTPUTS
        [System.Object[]]
        Returns an array of media objects specific to the application type:
        - Radarr: Movie objects
        - Sonarr: Series objects
        - Lidarr: Artist objects

    .NOTES
        - Requires valid API key and accessible application URL
        - Uses Confirm-StarrApiResponse for error handling
        - Returns all media items in a single request
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]
        $Application,

        [Parameter(Mandatory = $true)]
        [string]
        $Url
    )

    begin {
        # Determine the API endpoint based on the application
        switch -Regex ($application) {
            "radarr" {
                $apiEndpoint = 'movie'
            }
            "sonarr" {
                $apiEndpoint = 'series'
            }
            "lidarr" {
                $apiEndpoint = 'artist'
            }
        }

        # Create a splat for Invoke-RestMethod
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
        # Make the API call to get all media items
        $apiResponse = Invoke-RestMethod @params
    }

    end {
        # Check the response status code and return the media items if successful
        if (Confirm-StarrApiResponse -Application $application -Function $MyInvocation.MyCommand -StatusCode $statusCode) {
            $apiResponse
        }
    }
}

function New-StarrTag {
    <#
    .SYNOPSIS
        Creates a new tag in a Starr application.

    .DESCRIPTION
        Creates a new tag in a Starr application (Radarr/Sonarr/Lidarr) using the API.
        Returns the ID of the newly created tag.

    .PARAMETER ApiKey
        The API key for the Starr application.

    .PARAMETER ApiVersion
        The API version of the Starr application (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr/Lidarr).

    .PARAMETER TagName
        The name of the tag to create.

    .PARAMETER Url
        The base URL of the Starr application (e.g., http://localhost:7878).

    .EXAMPLE
        New-StarrTag -ApiKey "1234..." -ApiVersion "v3" -Application "Radarr" -TagName "upgrade" -Url "http://localhost:7878"
        # Creates a new tag named "upgrade" and returns its ID

    .OUTPUTS
        [Int]
        Returns the ID of the newly created tag.

    .NOTES
        - Requires valid API key and accessible application URL
        - Uses Confirm-StarrApiResponse for error handling
        - Returns tag ID only if creation is successful
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]
        $Application,

        [Parameter(Mandatory = $true)]
        [string]
        $TagName,

        [Parameter(Mandatory = $true)]
        [string]
        $Url
    )

    begin {
        # Create a splat for Invoke-RestMethod
        $params = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Post'
            Uri                = "$url/api/$apiVersion/tag"
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            ContentType        = 'application/json'
            Body               = @{
                label = $tagName
            } | ConvertTo-Json
        }
    }

    process {
        # Make the API call to create the tag
        $tagCreation = Invoke-RestMethod @params
    }

    end {
        # Check the response status code and return the tag ID if successful
        if (Confirm-StarrApiResponse -Application $application -Function $MyInvocation.MyCommand -StatusCode $statusCode) {
            $tagCreation.id
        }
    }
}

function Read-ConfigurationFile {
    <#
    .SYNOPSIS
        Reads and parses an INI configuration file into a PowerShell custom object.

    .DESCRIPTION
        The Read-ConfigurationFile function reads an INI-style configuration file and converts it into
        a structured PowerShell custom object. It supports sections denoted by [SectionName] and
        key-value pairs in the format key=value. Comments starting with semicolon (;) are ignored.

    .PARAMETER File
        The path to the INI configuration file to be parsed. The file must exist.

    .EXAMPLE
        $config = Read-ConfigurationFile -File "C:\config.ini"

        # Example config.ini content:
        # [Database]
        # Server = localhost
        # Port = 1433

        # Accessing the parsed config:
        # $config.Database.Server    # Returns "localhost"
        # $config.Database.Port      # Returns "1433"

    .OUTPUTS
        [PSCustomObject]
        Returns a custom object where each section of the INI file becomes a property containing
        a hashtable of the key-value pairs in that section.

    .NOTES
        The function validates that the specified file exists before processing.
        Semi-colon prefixed lines are treated as comments and ignored.
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

function Remove-StarrMediaTag {
    <#
    .SYNOPSIS
        Removes specified tag from media items in a Starr application.

    .DESCRIPTION
        Removes a tag from specified media items in Radarr, Sonarr, or Lidarr using their respective APIs.
        Handles different media types (movies/series/artists) appropriately per application.

    .PARAMETER ApiKey
        The API key for the Starr application.

    .PARAMETER ApiVersion
        The API version of the Starr application (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr/Lidarr).

    .PARAMETER Media
        Array of media objects to remove the tag from.

    .PARAMETER TagId
        The ID of the tag to remove.

    .PARAMETER Url
        The base URL of the Starr application (e.g., http://localhost:7878).

    .EXAMPLE
        Remove-StarrMediaTag -ApiKey "1234..." -ApiVersion "v3" -Application "Radarr" -Media $mediaArray -TagId 1 -Url "http://localhost:7878"
        # Removes tag ID 1 from specified movies in Radarr

    .OUTPUTS
        None. Displays success message when tag is removed.

    .NOTES
        - Requires valid API key and accessible application URL
        - Uses Confirm-StarrApiResponse for error handling
        - Supports batch operations via media array
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]
        $Application,

        [Parameter(Mandatory = $true)]
        [System.Object[]]
        $Media,

        [Parameter(Mandatory = $true)]
        [int]
        $TagId,

        [Parameter(Mandatory = $true)]
        [string]
        $Url
    )

    begin {
        # Join media IDs into a comma-separated string
        $mediaId = $media.id -join ','

        # Determine the API endpoint and body based on the application
        switch -Regex ($application) {
            "radarr" {
                $body = "{`"movieIds`":[$mediaId],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}"
                $apiEndpoint = 'movie/editor'
            }
            "sonarr" {
                $body = "{`"seriesIds`":[$mediaId],`"tags`":[$tagId], `"applyTags`":`"remove`"}"
                $apiEndpoint = 'series/editor'

            }
            "lidarr" {
                $body = "{`"artistIds`":[$mediaId],`"tags`":[$tagId], `"applyTags`":`"remove`"}"
                $apiEndpoint = 'artist/editor'
            }
        }

        # Create a splat for Invoke-RestMethod
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
        # Make the API call to remove the tag from media items
        $apiResponse = Invoke-RestMethod @params
    }

    end {
        # Check the response status code and display success message if successful
        if (Confirm-StarrApiResponse -Application $application -Function $MyInvocation.MyCommand -StatusCode $statusCode) {
            Write-Host "Tag removed from $($media.Count) media items in $application" -ForegroundColor Magenta
        }
    }
}

function Select-StarrMedia {
    <#
    .SYNOPSIS
        Filters media items from Starr applications based on specified criteria.

    .DESCRIPTION
        Filters an array of media items based on monitoring status, tags, quality profiles,
        and status conditions. Supports both attended and unattended filtering modes.

    .PARAMETER ApplicationConfiguration
        Hashtable containing configuration settings including:
        - TagName: Name of the tag to filter by
        - TagId: ID of the tag to filter by
        - Monitored: Boolean indicating monitored status
        - Status: (Optional) Status to filter by
        - QualityProfileId: (Optional) Quality profile ID to filter by
        - IgnoreTagId: (Optional) Tag ID to exclude from results

    .PARAMETER Media
        Array of media objects from a Starr application to be filtered.

    .PARAMETER Unattended
        Switch parameter to enable unattended mode filtering.
        When enabled, only returns media with specified tag.
        When disabled, returns media without specified tag and applies additional filters.

    .EXAMPLE
        $config = @{
            TagName = "upgrade"
            TagId = 1
            Monitored = $true
        }
        Select-StarrMedia -ApplicationConfiguration $config -Media $mediaArray
        # Returns monitored media without the "upgrade" tag

    .EXAMPLE
        Select-StarrMedia -ApplicationConfiguration $config -Media $mediaArray -Unattended
        # Returns only monitored media with the "upgrade" tag

    .OUTPUTS
        [System.Object[]]
        Returns filtered array of media objects matching specified criteria.

    .NOTES
        - Requires valid application configuration with TagName and TagId
        - Different filtering logic applies in attended vs unattended mode
        - Optional filters only apply in attended mode
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [hashtable]
        $ApplicationConfiguration,

        [Parameter(Mandatory = $true)]
        [System.Object[]]
        $Media,

        [Parameter(Mandatory = $false)]
        [switch]
        $Unattended
    )

    begin {

    }

    process {
        # Filter media based on attended or unattended mode
        if ($PSBoundParameters.ContainsKey('Unattended')) {
            Write-Verbose "Filtering media to only include media with the tag `"$($applicationConfiguration.TagName)`""

            # Filter media to only include media with the specified tag
            $filteredMedia = $media | Where-Object { $_.monitored -eq $applicationConfiguration.Monitored -and $_.tags -contains $applicationConfiguration.TagId }
        }

        else {
            Write-Verbose "Filtering media to only include media without the tag `"$($applicationConfiguration.TagName)`" and that are monitored"

            # Filter media to only include media without the specified tag
            $filteredMedia = $media | Where-Object { $_.monitored -eq $applicationConfiguration.Monitored -and $_.tags -notcontains $applicationConfiguration.TagId }

            # If "Status" is specified, filter media based on status
            if ($null -ne $applicationConfiguration.Status) {
                Write-Verbose "Filtering media based on Status: $($applicationConfiguration.Status)"
                $filteredMedia = $filteredMedia | Where-Object { $_.status -eq $applicationConfiguration.Status }
            }

            # If "QualityProfileId" is specified, filter media based on quality profile ID
            if ($null -ne $applicationConfiguration.QualityProfileId) {
                Write-Verbose "Filtering media based on Quality Profile ID: $($applicationConfiguration.QualityProfileId)"
                $filteredMedia = $filteredMedia | Where-Object { $_.qualityProfileId -eq $applicationConfiguration.QualityProfileId }
            }

            # If "IgnoreTagId" is specified, filter media to exclude media with the specified tag
            if ($null -ne $applicationConfiguration.IgnoreTagId) {
                Write-Verbose "Filtering media based on Ignore Tag Name: `"$($applicationConfiguration.IgnoreTag)`" with Id: $($applicationConfiguration.IgnoreTagId)"
                $filteredMedia = $filteredMedia | Where-Object { $_.tags -notcontains $applicationConfiguration.IgnoreTagId }
            }
        }
    }

    end {
        # Return the filtered media array
        $filteredMedia
    }
}

function Send-DiscordMessage {
    <#
    .SYNOPSIS
        Sends formatted messages to Discord via webhooks.

    .DESCRIPTION
        Creates and sends embedded messages to Discord channels using webhooks. This is a very basic function that **does not take full advantage** of all the structures available in Discord's webhooks.

        Supports customization of:
        - Message title and description
        - Avatar and thumbnail URLs
        - Embed color
        - Webhook username

    .PARAMETER AvatarUrl
        Optional. URL for the webhook's avatar image.

    .PARAMETER MessageTitle
        Required. Title of the embedded message.

    .PARAMETER MessageDescription
        Required. Main content of the embedded message.

    .PARAMETER Color
        Optional. Decimal color code for the embed's side bar.

    .PARAMETER ThumbnailUrl
        Optional. URL for the embed's thumbnail image.

    .PARAMETER WebhookUrl
        Required. Discord webhook URL for message delivery.

    .PARAMETER WebhookUsername
        Optional. Username shown for the webhook. Defaults to 'Upgradinatorr'.

    .EXAMPLE
        Send-DiscordMessage -WebhookUrl "https://discord.com/api/webhooks/..." -MessageTitle "Test" -MessageDescription "Hello World"
        # Sends basic message with title and description

    .EXAMPLE
        Send-DiscordMessage -WebhookUrl "https://discord.com/api/webhooks/..." `
                            -MessageTitle "Update" `
                            -MessageDescription "Content updated" `
                            -Color 65280 `
                            -ThumbnailUrl "https://example.com/image.png" `
                            -AvatarUrl "https://example.com/avatar.png" `
                            -WebhookUsername "CustomBot"
        # Sends fully customized embedded message

    .OUTPUTS
        None. Writes verbose success message or warning on failure.

    .NOTES
        - Requires valid Discord webhook URL
        - Color parameter uses decimal color codes
        - Returns response body on error for troubleshooting
        - Supports webhook customization via username and avatar
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]
        $AvatarUrl,

        [Parameter(Mandatory = $true)]
        [string]
        $MessageTitle,

        [Parameter(Mandatory = $true)]
        [string]
        $MessageDescription,

        [Parameter(Mandatory = $false)]
        [int64]
        $Color,

        [Parameter(Mandatory = $false)]
        [string]
        $ThumbnailUrl,

        [Parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string]
        $WebhookUrl,

        [Parameter(Mandatory = $false)]
        [string]
        $WebhookUsername = 'Upgradinatorr'
    )

    begin {
        $discordWebhook = [PSCustomObject]@{
            username   = $webhookUsername
            avatar_url = $avatarUrl
            embeds     = @(
                @{
                    title       = $messageTitle
                    description = $messageDescription
                    color       = $color
                    thumbnail   = @{
                        url = $thumbnailUrl
                    }
                }
            )
        } | ConvertTo-Json -Depth 20
    }

    process {
        $discordMessage = Invoke-RestMethod -Uri $webhookUrl -Body $discordWebhook -Method Post -ContentType 'application/json' -SkipHttpErrorCheck -StatusCodeVariable statusCode
    }

    end {
        if ($statusCode -match '2\d\d') {
            Write-Verbose "Discord message sent successfully"
        }
        else {
            Write-Warning "There was an error sending the Discord message. Status code: $statusCode"
            $discordMessage
        }
    }
}

function Send-NotifiarrPassThroughNotification {
    <#
    .SYNOPSIS
        Sends a notification through Notifiarr's Discord Passthrough Integration.

    .DESCRIPTION
        The Send-NotifiarrPassThroughNotification function sends customized notifications via Notifiarr's Discord integration.
        It supports rich message formatting including:
        - Custom application name and event types
        - Discord message formatting (colors, pings, images)
        - Customizable content fields and footers
        - Channel-specific targeting

    .PARAMETER NotifiarrPassthroughApplicationName
        The name of the application sending the notification. Required.

    .PARAMETER NotifiarrPassthroughUpdate
        Boolean used to update an existing message with the same ID.

    .PARAMETER NotifiarrPassthroughEvent
        Used to pass a unique ID for this notification if necessary.

    .PARAMETER NotifiarrPassthroughColor
        The color you want to use for the notification, 6 digit HTML color code.

    .PARAMETER NotifiarrPassthroughPingUser
        Discord user ID to ping.

    .PARAMETER NotifiarrPassthroughPingRole
        Discord role ID to ping.

    .PARAMETER NotifiarrPassthroughThumbnail
        URL of thumbnail image to display.

    .PARAMETER NotifiarrPassthroughImage
        URL to an image that will be on the bottom of the notification.

    .PARAMETER NotifiarrPassthroughTitle
        Title of the notification.

    .PARAMETER NotifiarrPassthroughIcon
        URL of icon to display.

    .PARAMETER NotifiarrPassthroughContent
        This text goes above the embed and is what is seen in toast notifications and wearables.

    .PARAMETER NotifiarrPassthroughDescription
        This text goes between the title and the embeds.

    .PARAMETER NotifiarrPassthroughFields
        Custom fields as PSCustomObject. This is a list of items to put in the notification

    .PARAMETER NotifiarrPassthroughFooter
        Footer text for the notification.

    .PARAMETER NotifiarrPassthroughDiscordChannelId
        Discord channel ID. Required.

    .PARAMETER NotifiarrPassthroughWebhook
        Notifiarr webhook URL. Required.

    .EXAMPLE
        PS> Send-NotifiarrPassThroughNotification -NotifiarrPassthroughApplicationName "MyApp" `
            -NotifiarrPassthroughTitle "Update Available" `
            -NotifiarrPassthroughContent "Version 2.0 is ready to install" `
            -NotifiarrPassthroughWebhook "https://notifiarr.com/api/v1/notification/..."

    .EXAMPLE
        PS> $notificationParams = @{
            NotifiarrPassthroughApplicationName = "HomeAutomation"
            NotifiarrPassthroughUpdate = $true
            NotifiarrPassthroughTitle = "Sensor Update"
            NotifiarrPassthroughContent = "Temperature sensor offline"
            NotifiarrPassthroughColor = "#FF0000"
            NotifiarrPassthroughWebhook = $webhookUrl
        }
        PS> Send-NotifiarrPassThroughNotification @notificationParams

    .OUTPUTS
        None. Displays success/failure messages to console.

    .LINK
        https://notifiarr.wiki/en/Website/Integrations/Passthrough
    #>

    [CmdletBinding(SupportsShouldProcess)]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $NotifiarrPassthroughApplicationName,

        [Parameter(Mandatory = $false)]
        [bool]
        $NotifiarrPassthroughUpdate,

        [Parameter(Mandatory = $false)]
        [string]
        $NotifiarrPassthroughEvent,

        [Parameter(Mandatory = $false)]
        [string]
        $NotifiarrPassthroughColor,

        [Parameter(Mandatory = $false)]
        [int]
        $NotifiarrPassthroughPingUser,

        [Parameter(Mandatory = $false)]
        [int]
        $NotifiarrPassthroughPingRole,

        [Parameter(Mandatory = $false)]
        [string]
        $NotifiarrPassthroughThumbnail,

        [Parameter(Mandatory = $false)]
        [string]
        $NotifiarrPassthroughImage,

        [Parameter(Mandatory = $false)]
        [string]
        $NotifiarrPassthroughTitle,

        [Parameter(Mandatory = $false)]
        [string]
        $NotifiarrPassthroughIcon,

        [Parameter(Mandatory = $false)]
        [string]
        $NotifiarrPassthroughContent,

        [Parameter(Mandatory = $false)]
        [string]
        $NotifiarrPassthroughDescription,

        [Parameter(Mandatory = $false)]
        [PSCustomObject]
        $NotifiarrPassthroughFields,

        [Parameter(Mandatory = $false)]
        [string]
        $NotifiarrPassthroughFooter,

        [Parameter(Mandatory = $true)]
        [int64]
        $NotifiarrPassthroughDiscordChannelId,

        [Parameter(Mandatory = $true)]
        [string]
        $NotifiarrPassthroughWebhook
    )

    begin {
        $notifiarrPayload = @{
            notification = @{
                name   = $notifiarrPassthroughApplicationName
                update = $notifiarrPassthroughUpdate
                event  = $notifiarrPassthroughEvent
            }
            discord      = @{
                color  = $notifiarrPassthroughColor
                ping   = @{
                    pingUser = $notifiarrPassthroughPingUser
                    pingRole = $notifiarrPassthroughPingRole
                }
                images = @{
                    thumbnail = $notifiarrPassthroughThumbnail
                    image     = $notifiarrPassthroughImage
                }
                text   = @{
                    title       = $notifiarrPassthroughTitle
                    icon        = $notifiarrPassthroughIcon
                    content     = $notifiarrPassthroughContent
                    description = $NotifiarrPassthroughDescription
                    fields      = $notifiarrPassthroughFields
                    footer      = $notifiarrPassthroughFooter
                }
                ids    = @{
                    channel = $notifiarrPassthroughDiscordChannelId
                }
            }
        } | ConvertTo-Json -Depth 20
    }

    process {
        if ($PSCmdlet.ShouldProcess($notifiarrPassthroughApplicationName, 'Sending notification to Notifiarr Passthrough Integration')) {
            $notifiarrParams = @{
                Uri                = $notifiarrPassthroughWebhook
                Method             = 'Post'
                Body               = $notifiarrPayload
                ContentType        = 'application/json'
                Headers            = @{
                    'Accept' = 'text/plain'
                }
                StatusCodeVariable = 'statusCode'
                SkipHttpErrorCheck = $true
                ErrorAction        = 'Stop'
            }

            try {
                $notifiarrResponse = Invoke-RestMethod @notifiarrParams

                if ($notifiarrResponse.result -eq 'success') {
                    Write-Verbose "Notification successfully sent to Notifiarr"
                }
                else {
                    Write-Warning 'Failed to send notification to Notifiarr'
                    throw "Server responded with status code:`r`n$notifiarrResponse"
                }
            }
            catch {
                Write-Warning 'Unexpected error occurred while sending notification to Notifiarr'
                throw $_.Exception.Message
            }
        }
    }

    end {}
}

function Start-StarrMediaSearch {
    <#
    .SYNOPSIS
        Initiates a search for media items in Starr applications.

    .DESCRIPTION
        Triggers a search operation for specified media items in Radarr, Sonarr, or Lidarr.
        Handles different media types appropriately:
        - Radarr: Movies search
        - Sonarr: Series search
        - Lidarr: Artist search

    .PARAMETER ApiKey
        The API key for the Starr application.

    .PARAMETER ApiVersion
        The API version of the Starr application (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr/Lidarr).

    .PARAMETER Media
        Array of media objects to search for.

    .PARAMETER Url
        The base URL of the Starr application (e.g., http://localhost:7878).

    .EXAMPLE
        Start-StarrMediaSearch -ApiKey "1234..." -ApiVersion "v3" -Application "Radarr" -Media $movieArray -Url "http://localhost:7878"
        # Initiates search for specified movies in Radarr

    .EXAMPLE
        Start-StarrMediaSearch -ApiKey "1234..." -ApiVersion "v3" -Application "Sonarr" -Media $seriesArray -Url "http://localhost:8989"
        # Initiates search for specified series in Sonarr

    .OUTPUTS
        None. Displays verbose message when search is initiated.

    .NOTES
        - Requires valid API key and accessible application URL
        - Uses Confirm-StarrApiResponse for error handling
        - Supports batch operations via media array
        - Search commands are processed asynchronously by the applications
    #>

    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $ApiKey,

        [Parameter(Mandatory = $true)]
        [string]
        $ApiVersion,

        [Parameter(Mandatory = $true)]
        [string]
        $Application,

        [Parameter(Mandatory = $true)]
        [System.Object[]]
        $Media,

        [Parameter(Mandatory = $true)]
        [string]
        $Url
    )

    begin {
        # Join media IDs into a comma-separated string
        $mediaId = $media.id -join ','

        # Determine the API endpoint and body based on the application
        switch -Regex ($application) {
            "radarr" {
                $body = "{`"name`":`"MoviesSearch`", `"movieIds`":[$mediaId]}"
            }
            "sonarr" {
                $body = "{`"name`":`"SeriesSearch`", `"seriesId`":$mediaId}"
            }
            "lidarr" {
                $body = "{`"name`":`"ArtistSearch`", `"artistId`":$mediaId}"
            }
        }

        # Create a splat for Invoke-RestMethod
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
        # Make the API call to start the search operation
        $apiResponse = Invoke-RestMethod @params
    }

    end {
        # Check the response status code and display verbose message if successful
        if (Confirm-StarrApiResponse -Application $application -Function $MyInvocation.MyCommand -StatusCode $statusCode) {
            Write-Verbose "Search started for $($media.Count) media items in $application"
        }
    }
}

# Read the configuration file
if ($PSCmdlet.ShouldProcess($configurationFile, 'Reading configuration file')) {
    $configuration = Read-ConfigurationFile -File $configurationFile
}

# Validate the overall configuration file to make sure there are no quotes in the configuration values
if ($PSCmdlet.ShouldProcess($configurationFile, "Checking that no quotes are present in the configuration file")) {
    $confirmAllSections = Confirm-Configuration -Configuration $configuration -Section 'Quotes'

    if (-Not ($confirmAllSections)) {
        throw "One or more configuration sections are not configured correctly, please correct any warnings and try again"
    }
}

# Validate the "Notifications" section of the configuration file
if ($PSCmdlet.ShouldProcess($configurationFile, "Validating `"Notifications`" section")) {
    $confirmNotificationsSection = Confirm-Configuration -Configuration $configuration -Section 'Notifications'

    if (-Not ($confirmNotificationsSection)) {
        throw "Notifications section is not configured correctly, please correct any warnings and try again"
    }

    if (-Not [string]::IsNullOrWhiteSpace($configuration.Notifications.DiscordWebhook)) {
        $sendDiscordNotification = $true
        $discordWebhookUrl = $configuration.Notifications.DiscordWebhook
    }

    if (-Not [string]::IsNullOrWhiteSpace($configuration.Notifications.NotifiarrPassthroughWebhook)) {
        $sendNotifiarrNotification = $true
        $notifiarrWebhookUrl = $configuration.Notifications.NotifiarrPassthroughWebhook
        $notifiarrChannelId = $configuration.Notifications.NotifiarrPassthroughDiscordChannelId
    }
}

<#
When calling the script from the command line such as
"pwsh.exe -File \\path\to\script.ps1 -ApplicationList 'app1, app2, app3'"
due to limitations, arrays are passed as strings.
This is why we need to split the string and trim the values https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pwsh?view=powershell-7.4#-file---f
#>
$applicationList = ($applicationList -split ',').Trim()

# Loop through each application in the application list
foreach ($application in $applicationList) {
    # Convert the application name to title case so it is pretty
    $applicationName = (Get-Culture).TextInfo.ToTitleCase($application)

    # Validate the application being processed
    if ($PSCmdlet.ShouldProcess($applicationName, "Validating application")) {
        Confirm-Application -Application $applicationName
    }

    # Validate the application configuration
    if ($PSCmdlet.ShouldProcess($configurationFile, "Validating `"$applicationName`" section")) {
        $confirmApplicationConfiguration = Confirm-Configuration -Configuration $configuration -Section $applicationName

        if (-Not ($confirmApplicationConfiguration)) {
            throw "$applicationName is not configured correctly, please correct any warnings and try again"
        }

        else {
            Write-Verbose "$applicationName settings are configured correctly"
        }

        # Create a hashtable to store the application configuration
        $applicationConfiguration = @{
            ApiKey         = $configuration.$application.ApiKey
            Count          = $configuration.$application.Count
            IgnoreTag      = if ([string]::IsNullOrWhiteSpace($configuration.$application.IgnoreTag)) { $null } else { $configuration.$application.IgnoreTag }
            Monitored      = [System.Convert]::ToBoolean($configuration.$application.Monitored)
            Status         = switch -Regex ($application) {
                "radarr" { if ([string]::IsNullOrWhiteSpace($configuration.$application.MovieStatus)) { $null } else { $configuration.$application.MovieStatus } }
                "sonarr" { if ([string]::IsNullOrWhiteSpace($configuration.$application.SeriesStatus)) { $null } else { $configuration.$application.SeriesStatus } }
                "lidarr" { if ([string]::IsNullOrWhiteSpace($configuration.$application.ArtistStatus)) { $null } else { $configuration.$application.ArtistStatus } }
            }
            QualityProfile = if ([string]::IsNullOrWhiteSpace($configuration.$application.QualityProfileName)) { $null } else { $configuration.$application.QualityProfileName }
            TagName        = $configuration.$application.TagName
            Unattended     = [System.Convert]::ToBoolean($configuration.$application.Unattended)
            Url            = ($configuration.$application.Url).TrimEnd('/')
        }
    }

    Write-Host "$applicationName is a valid application and its configuration has been validated" -ForegroundColor Green

    # Retrieve the API version
    if ($PSCmdlet.ShouldProcess($applicationName, "Retrieving API version")) {
        $applicationConfiguration["ApiVersion"] = Get-StarrApiVersion -ApiKey $applicationConfiguration.ApiKey -Application $applicationName -Url $applicationConfiguration.Url
    }

    # Retrieve the Tag Id based on the tag name
    if ($PSCmdlet.ShouldProcess($applicationName, "Retrieving Tag ID")) {
        $applicationConfiguration["TagId"] = Get-StarrItemId -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -TagName $applicationConfiguration.TagName -Url $applicationConfiguration.Url
    }

    # Retrieve the Tag Id to ignore based on the tag name
    if ($PSCmdlet.ShouldProcess($applicationName, "Retrieving Tag ID to ignore")) {
        if (-Not [string]::IsNullOrWhiteSpace($applicationConfiguration.IgnoreTag)) {
            $applicationConfiguration["IgnoreTagId"] = Get-StarrItemId -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -TagName $applicationConfiguration.IgnoreTag -Url $applicationConfiguration.Url

            if ($applicationConfiguration.TagId -eq $applicationConfiguration.IgnoreTagId) {
                throw "Tag ID for `"$($applicationConfiguration.TagName)`" and `"$($applicationConfiguration.IgnoreTag)`" are the same, please correct this in the configuration file"
            }
        }
    }

    # Retrieve the Quality Profile Id based on the quality profile name
    if ($PSCmdlet.ShouldProcess($applicationName, "Retrieving Quality Profile ID")) {
        if (-Not [string]::IsNullOrWhiteSpace($applicationConfiguration.QualityProfile)) {
            $applicationConfiguration["QualityProfileId"] = Get-StarrItemId -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -QualityProfileName $applicationConfiguration.QualityProfile -Url $applicationConfiguration.Url
        }
    }

    # Retrieve all media items
    if ($PSCmdlet.ShouldProcess($applicationName, "Retrieving all media")) {
        $allMedia = Get-StarrMedia -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Url $applicationConfiguration.Url

        Write-Verbose "Retrieved a total of $($allMedia.Count) media items from $applicationName"
    }

    # Filter media based on configuration values
    if ($PSCmdlet.ShouldProcess($applicationName, "Filtering media based on configuration values")) {
        $filteredMedia = Select-StarrMedia -Media $allMedia -ApplicationConfiguration $applicationConfiguration

        # If the initial filtering yields no results, check if the script is running in unattended mode
        if ($filteredMedia.Count -eq 0) {
            # If the script is running in unattended mode, remove the tag from all media items and retrieve all media again to re-filter based on configuration values
            if ($applicationConfiguration.Unattended) {
                Write-Host "Script is running in unattended mode. No media left to process based on configuration values. The script will now remove tag `"$($applicationConfiguration.TagName)`" from all media in $applicationName" -ForegroundColor Cyan

                $mediaToRemoveTagFrom = Select-StarrMedia -ApplicationConfiguration $applicationConfiguration -Media $allMedia -Unattended

                # If running in unattended mode and the filtered media to remove the tag from is empty, display a warning and go to the next application. This is triggered likely due to a user misconfiguration
                if ($mediaToRemoveTagFrom.Count -eq 0) {
                    Write-Warning "If you triggered this warning, please open a GitHub issue at https://github.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/issues with your configuration for $applicationName`n"
                    continue
                }

                Remove-StarrMediaTag -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Media $mediaToRemoveTagFrom -TagId $applicationConfiguration.TagId -Url $applicationConfiguration.Url

                Write-Verbose "Retrieving all media after removing tag `"$($applicationConfiguration.TagName)`" from all media items"

                $allMedia = Get-StarrMedia -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Url $applicationConfiguration.Url

                $filteredMedia = Select-StarrMedia -Media $allMedia -ApplicationConfiguration $applicationConfiguration
            }

            # If the script is not running in unattended mode, send a notification to the enabled services and exit the go to the next application
            else {
                # Set the embed color and thumbnail based on the application
                switch -Regex ($application) {
                    "radarr" {
                        $thumbnail = 'https://gh.notifiarr.com/images/icons/radarr.png'
                        $color = @{
                            Html    = 'FFC230'
                            Decimal = '16761392'
                        }
                    }
                    "sonarr" {
                        $thumbnail = 'https://gh.notifiarr.com/images/icons/sonarr.png'
                        $color = @{
                            Html    = '00CCFF'
                            Decimal = '52479'
                        }
                    }
                    "lidarr" {
                        $thumbnail = 'https://gh.notifiarr.com/images/icons/lidarr.png'
                        $color = @{
                            Html    = '009252'
                            Decimal = '37458'
                        }
                    }
                    default {
                        $thumbnail = 'https://gh.notifiarr.com/images/icons/shell.png'
                        $color = @{
                            Html    = 'FF0000'
                            Decimal = '16711680'
                        }
                    }
                }

                if ($sendDiscordNotification) {
                    $params = @{
                        AvatarUrl          = 'https://gh.notifiarr.com/images/icons/powershell.png'
                        MessageTitle       = "Upgradinatorr - $applicationName"
                        MessageDescription = "No media left to search for $applicationName"
                        Color              = $color.Decimal
                        ThumbnailUrl       = $thumbnail
                        WebhookUrl         = $discordWebhookUrl
                    }
                    Send-DiscordMessage @params
                }

                if ($sendNotifiarrNotification) {
                    $params = @{
                        NotifiarrPassthroughApplicationName  = "Upgradinatorr - $applicationName"
                        NotifiarrPassthroughColor            = $color.Html
                        NotifiarrPassthroughThumbnail        = $thumbnail
                        NotifiarrPassthroughDescription      = "No media left to search for $applicationName"
                        NotifiarrPassthroughDiscordChannelId = $notifiarrChannelId
                        NotifiarrPassthroughWebhook          = $notifiarrWebhookUrl
                    }

                    Send-NotifiarrPassThroughNotification @params
                }

                Write-Warning "Script is not running in unattended mode. No media left to process based on configuration values. Script will now exit`n"
                continue
            }
        }

        Write-Verbose "Filtered media based on configuration values, found $($filteredMedia.Count) media items to process for $applicationName"
    }

    # Select random media to search based on the value of the count configuration
    if ($PSCmdlet.ShouldProcess($applicationName, "Selecting media to search based on count")) {
        if ($applicationConfiguration.Count -eq 'max') {
            Write-Verbose "No count specified, returning all filtered media"
            $mediaToSearch = $filteredMedia
        }
        else {
            Write-Verbose "Filtering media based on count: $($applicationConfiguration.Count)"
            $mediaToSearch = Get-Random -InputObject $filteredMedia -Count $applicationConfiguration.Count
        }
    }

    # Start the search for media items
    if ($PSCmdlet.ShouldProcess($applicationName, "Starting search for media items")) {
        # Sonarr's API only supports searching one series at a time, so we need to loop through each media item in $mediaToSearch
        if ($applicationName -match 'sonarr|lidarr') {
            foreach ($mediaItem in $mediaToSearch) {
                Start-StarrMediaSearch -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Media $mediaItem -Url $applicationConfiguration.Url
            }
        }
        else {
            Start-StarrMediaSearch -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Media $mediaToSearch -Url $applicationConfiguration.Url
        }
    }

    # Add the tag to the media items that were searched
    if ($PSCmdlet.ShouldProcess($applicationName, "Adding tag to media items")) {
        Add-StarrMediaTag -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Media $mediaToSearch -TagId $applicationConfiguration.TagId -Url $applicationConfiguration.Url
    }

    # Send a notification to the enabled services
    if ($PSCmdlet.ShouldProcess($applicationName, "Sending notification to enabled services")) {
        switch -Regex ($application) {
            "radarr" {
                $thumbnail = 'https://gh.notifiarr.com/images/icons/radarr.png'
                $color = @{
                    Html    = 'FFC230'
                    Decimal = '16761392'
                }
            }
            "sonarr" {
                $thumbnail = 'https://gh.notifiarr.com/images/icons/sonarr.png'
                $color = @{
                    Html    = '00CCFF'
                    Decimal = '52479'
                }
            }
            "lidarr" {
                $thumbnail = 'https://gh.notifiarr.com/images/icons/lidarr.png'
                $color = @{
                    Html    = '009252'
                    Decimal = '37458'
                }
            }
            default {
                $thumbnail = 'https://gh.notifiarr.com/images/icons/shell.png'
                $color = @{
                    Html    = 'FF0000'
                    Decimal = '16711680'
                }
            }
        }

        $descriptionField = @"
            Search started for $($mediaToSearch.Count) media items in $applicationName`:
"@
        foreach ($media in $mediaToSearch) {
            $descriptionField += "`r`n- $($media.title)"
        }

        if ($descriptionField.Length -gt 4096) {
            $descriptionField = "Search started for $($mediaToSearch.Count) media items in $applicationName.`r`n`n- *The list of media items is too long to display here due to Discord's character limit.*"
        }

        if ($sendDiscordNotification) {
            $params = @{
                AvatarUrl          = 'https://gh.notifiarr.com/images/icons/powershell.png'
                MessageTitle       = "Upgradinatorr - $applicationName"
                MessageDescription = $descriptionField
                Color              = $color.Decimal
                ThumbnailUrl       = $thumbnail
                WebhookUrl         = $discordWebhookUrl
            }
            Send-DiscordMessage @params
        }

        if ($sendNotifiarrNotification) {
            $params = @{
                NotifiarrPassthroughApplicationName  = "Upgradinatorr - $applicationName"
                NotifiarrPassthroughColor            = $color.Html
                NotifiarrPassthroughThumbnail        = $thumbnail
                NotifiarrPassthroughDescription      = $descriptionField
                NotifiarrPassthroughDiscordChannelId = $notifiarrChannelId
                NotifiarrPassthroughWebhook          = $notifiarrWebhookUrl
            }

            Send-NotifiarrPassThroughNotification @params
        }

        $titleList = [System.Collections.Generic.List[string]]::new()

        foreach ($media in $mediaToSearch) {
            $titleList.Add("`n- $($media.title)")
        }
        Write-Host "Search started for $($mediaToSearch.Count) media items in $applicationName`:$titleList`n" -ForegroundColor Green
    }
}
