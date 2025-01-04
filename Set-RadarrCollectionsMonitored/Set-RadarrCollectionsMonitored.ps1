<#
.SYNOPSIS
    PowerShell script for managing collection monitoring in Radarr.

.DESCRIPTION
    Automates the process of enabling monitoring for movie collections in Radarr.
    Includes configuration validation and API interaction functions.
    Supports Discord and Notifiarr webhook notifications.

.PARAMETER ApplicationList
    Array of Starr applications to process (currently only Radarr supported).
    Aliases: Apps, AppsList
    Required: True

.PARAMETER ConfigurationFile
    Path to configuration file. Defaults to config.conf in script directory.
    Aliases: Config, ConfigFile
    Required: False

.EXAMPLE
    .\Set-RadarrCollectionsMonitored.ps1 -ApplicationList "Radarr"
    # Process Radarr using default config

.EXAMPLE
    .\Set-RadarrCollectionsMonitored.ps1 -Apps "Radarr" -Config "C:\config\custom.conf"
    # Process Radarr using custom config file

.NOTES
    Version      : 1.0
    Author       : angrycuban13
    Requires     : PowerShell 7+
    Dependencies : None

.LINK
    https://github.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts
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
    $ConfigurationFile = (Join-Path -Path $PSScriptRoot -ChildPath "config.conf")
)

$ErrorActionPreference = 'Stop'

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
            "radarr" {
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
            if (-Not [string]::IsNullOrWhiteSpace($configuration.Notifications.DiscordWebhook)) {
                Write-Verbose "Discord Webhook has been specified, verifying it is formatted correctly"

                # Validate the Discord Webhook URL is formatted correctly
                if ($configuration.Notifications.DiscordWebhook -notmatch $webhookRegexMatchDiscord) {
                    Write-Warning "Discord Webhook is not formatted correctly, it should look like `"https:   //discord.com/api/webhooks/Id123/Token123`""
                    $errorCount++
                }
            }

            # Check if the Notifiarr Passthrough Webhook has been specified
            if (-Not [string]::IsNullOrWhiteSpace($configuration.Notifications.NotifiarrPassthroughWebhook)) {
                Write-Verbose "Notifiarr Passthrough Webhook has been specified, verifying it is formatted correctly"

                # Validate the Notifiarr Passthrough Webhook URL is formatted correctly
                if ($configuration.Notifications.NotifiarrPassthroughWebhook -notmatch $webhookRegexMatchNotifiarrPassthrough) {
                    Write-Warning "Notifiarr Passthrough Webhook is not formatted correctly, it should look like `"https:   //notifiarr\.com/api/v1/notification/passthrough/uuid-uuid-uuid-uuid-uuid`""
                    $errorCount++
                }

                if ($configuration.Notifications.NotifiarrPassthroughDiscordChannelId -notmatch '^\d{17,19}$') {
                    Write-Warning "Notifiarr Passthrough Discord Channel ID is not formatted correctly, it should be a 17-19 digit number"
                    $errorCount++
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

function Get-StarrCollections {
    <#
    .SYNOPSIS
        Retrieves collections from Starr applications.

    .DESCRIPTION
        Gets all collections from a Starr application (Radarr) using its API.
        Validates the API response and returns collection data.

    .PARAMETER ApiKey
        The API key for authentication with the Starr application.

    .PARAMETER ApiVersion
        The version of the API to use (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (e.g., 'radarr').

    .PARAMETER Url
        The base URL of the Starr application (e.g., 'http://localhost:7878').

    .EXAMPLE
        Get-StarrCollections -ApiKey "your-api-key" -ApiVersion "v3" -Application "radarr" -Url "http://localhost:7878"
        # Retrieves all collections from Radarr

    .OUTPUTS
        [System.Object[]]
        Returns an array of collection objects containing:
        - id
        - name
        - movieIds
        - qualityProfileId
        - monitored
        - rootFolderPath
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
        $params = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Get'
            Uri                = "$url/api/$apiVersion/collection"
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            ContentType        = 'application/json'
        }
    }

    process {
        $apiResponse = Invoke-RestMethod @params
    }

    end {
        if (Confirm-StarrApiResponse -Application $application -Function $MyInvocation.MyCommand -StatusCode $statusCode) {
            $apiResponse
        }
    }
}

function Set-StarrCollectionMonitored {
    <#
    .SYNOPSIS
        Sets monitoring state for collections in Starr applications.

    .DESCRIPTION
        Enables monitoring for specified collections in Radarr using the collections API endpoint.
        Updates the monitoring status for one or more collection IDs.

    .PARAMETER ApiKey
        The API key for authentication with the Starr application.

    .PARAMETER ApiVersion
        The version of the API to use (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (e.g., 'radarr').

    .PARAMETER CollectionId
        Array of collection IDs to set as monitored.

    .PARAMETER Url
        The base URL of the Starr application (e.g., 'http://localhost:7878').

    .EXAMPLE
        Set-StarrCollectionMonitored -ApiKey "your-api-key" -ApiVersion "v3" -Application "radarr" -CollectionId 1,2,3 -Url "http://localhost:7878"
        # Enables monitoring for collections with IDs 1, 2, and 3

    .OUTPUTS
        None. Uses Write-Verbose for operation status.
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
        [int[]]
        $CollectionId,

        [Parameter(Mandatory = $true)]
        [string]
        $Url
    )

    begin {
        $params = @{
            Headers            = @{
                'X-Api-Key' = $apiKey
            }
            Method             = 'Put'
            Uri                = "$url/api/$apiVersion/collection"
            StatusCodeVariable = 'statusCode'
            SkipHttpErrorCheck = $true
            ContentType        = 'application/json'
            Body               = @{
                collectionIds = $collectionId
                monitored     = $true
            } | ConvertTo-Json
        }
    }

    process {
        $apiResponse = Invoke-RestMethod @params
    }

    end {
        if (Confirm-StarrApiResponse -Application $application -Function $MyInvocation.MyCommand -StatusCode $statusCode) {
            Write-Verbose "Collection(s) set to monitored in $application"
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
            ApiKey              = $configuration.$application.ApiKey
            Monitored           = [System.Convert]::ToBoolean($configuration.$application.Monitored)
            Url                 = ($configuration.$application.Url).TrimEnd('/')
            CollectionsToIgnore = @($configuration.$application.CollectionsToIgnore -split ',').Trim()
        }
    }

    Write-Host "$applicationName is a valid application and its configuration has been validated" -ForegroundColor Green

    # Retrieve the API version
    if ($PSCmdlet.ShouldProcess($applicationName, "Retrieving API version")) {
        $applicationConfiguration["ApiVersion"] = Get-StarrApiVersion -ApiKey $applicationConfiguration.ApiKey -Application $applicationName -Url $applicationConfiguration.Url
    }

    if ($PSCmdlet.ShouldProcess($applicationName, "Retrieving all collections")) {
        $allCollections = Get-StarrCollections -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Url $applicationConfiguration.Url

        $allUnmonitoredCollections = $allCollections | Where-Object { $_.monitored -eq $false -and $_.title -notin $applicationConfiguration.CollectionsToIgnore }
    }

    if ($PSCmdlet.ShouldProcess($applicationName, "Setting unmonitored collections to monitored")) {
        if ($allUnmonitoredCollections.Count -gt 0) {
            Write-Host "Found $($allUnmonitoredCollections.Count) unmonitored collection(s) in $applicationName that are not in the ignore list" -ForegroundColor Green

            Set-StarrCollectionMonitored -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -CollectionId $allUnmonitoredCollections.id -Url $applicationConfiguration.Url

            $descriptionField = @"
    The following collection(s) have been set to monitored in $applicationName`:
"@

            foreach ($collection in $allUnmonitoredCollections) {
                $descriptionField += "`r`n- $($collection.title)"
            }

            if ($sendDiscordNotification) {
                $params = @{
                    AvatarUrl          = 'https://gh.notifiarr.com/images/icons/powershell.png'
                    MessageTitle       = "Automatic Collection Monitoring - $applicationName"
                    MessageDescription = $descriptionField
                    Color              = '16761392'
                    ThumbnailUrl       = 'https://gh.notifiarr.com/images/radarr.png'
                    WebhookUrl         = $discordWebhookUrl
                }
                Send-DiscordMessage @params
            }

            if ($sendNotifiarrNotification) {
                $params = @{
                    NotifiarrPassthroughApplicationName  = "Automatic Collection Monitoring - $applicationName"
                    NotifiarrPassthroughColor            = 'FFC230'
                    NotifiarrPassthroughThumbnail        = 'https://gh.notifiarr.com/images/radarr.png'
                    NotifiarrPassthroughDescription      = $descriptionField
                    NotifiarrPassthroughDiscordChannelId = $notifiarrChannelId
                    NotifiarrPassthroughWebhook          = $notifiarrWebhookUrl
                }

                Send-NotifiarrPassThroughNotification @params
            }

            Write-Host "The following collection(s) have been set to monitored in $applicationName`:" -ForegroundColor Green
            $allUnmonitoredCollections | ForEach-Object { Write-Host "- $($_.title)" -ForegroundColor Green }
        }

        else {
            Write-Host "No unmonitored collection(s) found in $applicationName" -ForegroundColor Green
        }
    }

}
