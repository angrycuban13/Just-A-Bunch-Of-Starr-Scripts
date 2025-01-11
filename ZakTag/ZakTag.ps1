<#
.SYNOPSIS
    Automatically tags movies in Radarr with their release group.

.DESCRIPTION
    The ZakTag.ps1 script automatically tags movies in Radarr with their release group. The script retrieves all movies from Radarr, filters the results to only movies with existing files, and then retrieves all existing tags. The script then creates missing tags for each release group, filters the tags to only release group tags, and tags movies with their corresponding release group tag. If the movie has the wrong tag, the script will remove it and apply the correct tag.

.NOTES
    Author      : angrycuban13
    Dependencies: None
    Requires    : PowerShell 7+
    Version     : 3.0
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
    $ConfigurationFile = (Join-Path -Path $PSScriptRoot -ChildPath 'zaktag.conf')
)

function Add-StarrMediaTag {
    <#
    .SYNOPSIS
        Adds specified tag to media items in a Starr application.

    .DESCRIPTION
        Adds a tag to specified media items in Radarr or Sonarr using their respective APIs.
        Handles different media types appropriately:
        - Radarr: Movies tagging
        - Sonarr: Series tagging

    .PARAMETER ApiKey
        The API key for the Starr application.

    .PARAMETER ApiVersion
        The API version of the Starr application (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr).

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
            'radarr' {
                $body = "{`"movieIds`":[$mediaId],`"tags`":[$($tagId)],`"applyTags`":`"add`"}"
                $apiEndpoint = 'movie/editor'
            }
            'sonarr' {
                $body = "{`"seriesIds`":[$mediaId],`"tags`":[$tagId],`"applyTags`":`"add`"}"
                $apiEndpoint = 'series/editor'

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
        is one of the supported Starr applications (Radarr or Sonarr).
        It performs a case-insensitive validation using regex pattern matching.

    .PARAMETER Application
        The name of the application to validate. Must be one of: radarr, sonarr.
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
            'radarr' {
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
        Validates configuration settings for Starr applications (Radarr/Sonarr) and notification services.

    .DESCRIPTION
        The Confirm-Configuration function performs comprehensive validation of configuration settings for *arr applications and notification services. It checks:
        - API key format and length
        - URL formatting

    .PARAMETER Configuration
        PSCustomObject containing the configuration settings to validate. Should include sections for each application
        and notifications with their respective settings.

    .PARAMETER Section
        String specifying which section to validate. Can be 'Quotes', or an application name (e.g., 'Radarr').

    .EXAMPLE
        $config  = Read-ConfigurationFile -File "config.ini"
        $isValid = Confirm-Configuration -Configuration $config -Section "Quotes"
        # Validates entire configuration including quote checks

    .EXAMPLE
        $isValid = Confirm-Configuration -Configuration $config -Section "Radarr"
        # Validates Radarr-specific settings including API key, URL, and movie status

    .OUTPUTS
        [Boolean]
        Returns $true if all validations pass, $false if any validation fails.

    .NOTES
        Validation Rules:
        - API Keys must be 32 characters
        - URLs must start with http: // or https://
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
    }

    process {
        # Add quote validation before other checks
        if ($section -eq 'Quotes') {
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

            # Validate TagName
            Write-Verbose "Validating `"TagNamePrefix`" for `"$applicationName`""
            if ([string]::IsNullOrWhiteSpace($applicationConfig.TagNamePrefix)) {
                Write-Warning "A tag name prefix must be specified for `"$applicationName`""
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
        } else {
            $true
        }
    }
}

function Confirm-StarrApiResponse {
    <#
    .SYNOPSIS
        Validates HTTP response codes from Starr application API calls.

    .DESCRIPTION
        Validates HTTP status codes returned from Starr applications (Radarr/Sonarr).
        Throws descriptive errors for common HTTP error codes and provides guidance for resolution.
        Returns true for successful (2xx) responses.

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr) making the API call.

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
        endpoint to retrieve the current API version. Supports Radarr, and Sonarr.

    .PARAMETER ApiKey
        The API key required to authenticate with the Starr application.

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr).

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

function Get-StarrMedia {
    <#
    .SYNOPSIS
        Retrieves all media items from a Starr application.

    .DESCRIPTION
        Fetches all media items (movies/series/artists) from a Starr application's API.
        - Radarr: Returns all movies
        - Sonarr: Returns all series

    .PARAMETER ApiKey
        The API key for the Starr application.

    .PARAMETER ApiVersion
        The API version of the Starr application (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr).

    .PARAMETER Url
        The base URL of the Starr application (e.g., http://localhost:7878).

    .EXAMPLE
        Get-StarrMedia -ApiKey "1234..." -ApiVersion "v3" -Application "Radarr" -Url "http://localhost:7878"
        # Returns all movies from Radarr

    .EXAMPLE
        Get-StarrMedia -ApiKey "1234..." -ApiVersion "v3" -Application "Sonarr" -Url "http://localhost:8989"
        # Returns all series from Sonarr

    .OUTPUTS
        [System.Object[]]
        Returns an array of media objects specific to the application type:
        - Radarr: Movie objects
        - Sonarr: Series objects

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
            'radarr' {
                $apiEndpoint = 'movie'
            }
            'sonarr' {
                $apiEndpoint = 'series'
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

function Get-StarrMediaTags {
    <#
    .SYNOPSIS
        Retrieves all tags from a Starr application.

    .DESCRIPTION
        The Get-StarrMediaTags function retrieves all configured tags from a Starr application
        (Radarr/Sonarr) using its API. The function makes a GET request to the /api/tag
        endpoint and returns the complete list of tags.

    .PARAMETER ApiKey
        The API key required to authenticate with the Starr application.

    .PARAMETER ApiVersion
        The version of the API to use (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr).

    .PARAMETER Url
        The base URL of the Starr application (e.g., http://localhost:7878).

    .EXAMPLE
        Get-StarrMediaTags -ApiKey "1234..." -ApiVersion "v3" -Application "Radarr" -Url "http://localhost:7878"
        # Returns all tags configured in Radarr

    .EXAMPLE
        Get-StarrMediaTags -ApiKey "5678..." -ApiVersion "v3" -Application "Sonarr" -Url "http://localhost:8989"
        # Returns all tags configured in Sonarr

    .OUTPUTS
        [System.Object[]]
        Returns an array of tag objects containing:
        - Id: The unique identifier of the tag
        - Label: The display name of the tag
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
            Uri                = "$url/api/$apiVersion/tag"
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

function New-StarrTag {
    <#
    .SYNOPSIS
        Creates a new tag in a Starr application.

    .DESCRIPTION
        Creates a new tag in a Starr application (Radarr/Sonarr) using the API.
        Returns the ID of the newly created tag.

    .PARAMETER ApiKey
        The API key for the Starr application.

    .PARAMETER ApiVersion
        The API version of the Starr application (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr).

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
            Write-Host "Created tag '$tagName' with ID $($tagCreation.id)"
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
        key-value pairs in the format key = value. Comments starting with semicolon (;) are ignored.

    .PARAMETER File
        The path to the INI configuration file to be parsed. The file must exist.

    .EXAMPLE
        $config = Read-ConfigurationFile -File "C:\config.ini"

        # Example config.ini content:
        # [Database]
        # Server = localhost
        # Port   = 1433

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
                } else {
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
        Removes a tag from specified media items in Radarr or Sonarr using their respective APIs.
        Handles different media types (movies/series/artists) appropriately per application.

    .PARAMETER ApiKey
        The API key for the Starr application.

    .PARAMETER ApiVersion
        The API version of the Starr application (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr).

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
            'radarr' {
                $body = "{`"movieIds`":[$mediaId],`"tags`":[$($tagId)],`"applyTags`":`"remove`"}"
                $apiEndpoint = 'movie/editor'
            }
            'sonarr' {
                $body = "{`"seriesIds`":[$mediaId],`"tags`":[$tagId], `"applyTags`":`"remove`"}"
                $apiEndpoint = 'series/editor'

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


if ($PSCmdlet.ShouldProcess($configurationFile, 'Reading configuration file')) {
    $configuration = Read-ConfigurationFile -File $configurationFile
}

# Validate the overall configuration file to make sure there are no quotes in the configuration values
if ($PSCmdlet.ShouldProcess($configurationFile, 'Checking that no quotes are present in the configuration file')) {
    $confirmAllSections = Confirm-Configuration -Configuration $configuration -Section 'Quotes'

    if (-Not ($confirmAllSections)) {
        throw 'One or more configuration sections are not configured correctly, please correct any warnings and try again'
    }
}

<#
When calling the script from the command line such as
"pwsh.exe -File \\path\to\script.ps1 -ApplicationList 'app1, app2, app3'"
due to limitations, arrays are passed as strings.
This is why we need to split the string and trim the values https://learn.microsoft.com/en-us/powershell/module/microsoft.powershell.core/about/about_pwsh?view=powershell-7.4#-file---f
#>
$applicationList = ($applicationList -split ',').Trim()

foreach ($application in $applicationList) {
    $applicationName = (Get-Culture).TextInfo.ToTitleCase($application)
    $releaseGroupsList = [System.Collections.Generic.List[string]]::new()

    # Validate the application being processed
    if ($PSCmdlet.ShouldProcess($applicationName, 'Validating application')) {
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
            ApiKey        = $configuration.$application.ApiKey
            TagNamePrefix = $configuration.$application.TagNamePrefix
            Url           = ($configuration.$application.Url).TrimEnd('/')
        }
    }

    Write-Host "$applicationName is a valid application and its configuration has been validated" -ForegroundColor Green

    # Retrieve the API version
    if ($PSCmdlet.ShouldProcess($applicationName, 'Retrieving API version')) {
        $applicationConfiguration['ApiVersion'] = Get-StarrApiVersion -ApiKey $applicationConfiguration.ApiKey -Application $applicationName -Url $applicationConfiguration.Url
    }

    if ($PSCmdlet.ShouldProcess($applicationName, 'Retrieving all movies')) {
        $allMovies = Get-StarrMedia -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Url $applicationConfiguration.Url
    }

    if ($PSCmdlet.ShouldProcess($applicationName, 'Retrieving all existing tags')) {
        $allExistingTags = Get-StarrMediaTags -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Url $applicationConfiguration.Url
    }

    if ($PSCmdlet.ShouldProcess($applicationName, 'Filtering results to only movies with existing files')) {
        $allMoviesWithFiles = $allMovies | Where-Object { $_.hasFile -eq $true }
    }

    if ($PSCmdlet.ShouldProcess($applicationName, 'Processing existing release groups')) {
        $uniqueReleaseGroups = $allMoviesWithFiles.movieFile.releaseGroup | Sort-Object -Unique

        foreach ($releaseGroup in $uniqueReleaseGroups) {
            $tagName = "$($applicationConfiguration.TagNamePrefix) $releaseGroup"
            $releaseGroupsList.Add($tagName)
        }
    }

    if ($PSCmdlet.ShouldProcess($applicationName, 'Creating missing tags')) {
        # Loop through each release group and check if the tag exists in Radarr, if not create it
        foreach ($releaseGroup in $releaseGroupsList) {
            if ($allExistingTags.label -notcontains $releaseGroup) {
                New-StarrTag -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -TagName $releaseGroup -Url $applicationConfiguration.Url
            }
        }

        # Retrieve tags again so it includes the newly added release group tags
        $allExistingTags = Get-StarrMediaTags -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Url $applicationConfiguration.Url
    }

    if ($PSCmdlet.ShouldProcess($applicationName, 'Filtering tags to only release group tags')) {
        # Loop through each existing tag and select release groups tags only to avoid including previously defined tags
        $releaseGroupTagsOnly = $allExistingTags | Where-Object { $_.label -like "$($applicationConfiguration.TagNamePrefix)*" }
    }

    if ($PSCmdlet.ShouldProcess($applicationName, 'Tagging movies with their corresponding release group tag')) {
        # Loop through each movie
        foreach ($movie in $allMoviesWithFiles) {
            $existingReleaseGroupTags = $releaseGroupTagsOnly | Where-Object { $movie.tags -contains $_.id }
            $tagToApply = $releaseGroupTagsOnly | Where-Object { $_.label -eq "$($applicationConfiguration.TagNamePrefix) $($movie.movieFile.releaseGroup)" }

            if ($movie.tags -contains $tagToApply.id) {
                Write-Verbose "Movie `"$($movie.title)`" already has tag: `"$($tagToApply.label)`""
                continue
            }

            if ($null -ne $existingReleaseGroupTags) {
                Write-Warning "Removing tag `"$($existingReleaseGroupTags.label)`" from `"$($movie.title)`""

                Remove-StarrMediaTag -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Media $movie -TagId $existingReleaseGroupTags.id -Url $applicationConfiguration.Url
            }

            Add-StarrMediaTag -ApiKey $applicationConfiguration.ApiKey -ApiVersion $applicationConfiguration.ApiVersion -Application $applicationName -Media $movie -TagId $tagToApply.id -Url $applicationConfiguration.Url

            Write-Host "Added tag `"$($tagToApply.label)`" to `"$($movie.title)`"" -ForegroundColor Cyan
        }
    }
}