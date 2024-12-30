<#
.SYNOPSIS
    Automatically tags movies in Radarr with their release group.

.DESCRIPTION
    The ZakTag.ps1 script automatically tags movies in Radarr with their release group. The script retrieves all movies from Radarr, filters the results to only movies with existing files, and then retrieves all existing tags. The script then creates missing tags for each release group, filters the tags to only release group tags, and tags movies with their corresponding release group tag. If the movie has the wrong tag, the script will remove it and apply the correct tag.

.NOTES
    Author: AngryCuban13
    Version: 2.0
#>

#Requires -Version 7

[CmdletBinding(SupportsShouldProcess)]
param ()

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
        [Array]
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

function Get-StarrMediaTags {
    <#
    .SYNOPSIS
        Retrieves all tags from a Starr application.

    .DESCRIPTION
        The Get-StarrMediaTags function retrieves all configured tags from a Starr application
        (Radarr/Sonarr/Lidarr) using its API. The function makes a GET request to the /api/tag
        endpoint and returns the complete list of tags.

    .PARAMETER ApiKey
        The API key required to authenticate with the Starr application.

    .PARAMETER ApiVersion
        The version of the API to use (e.g., 'v3').

    .PARAMETER Application
        The name of the Starr application (Radarr/Sonarr/Lidarr).

    .PARAMETER Url
        The base URL of the Starr application (e.g., http://localhost:7878).

    .EXAMPLE
        Get-StarrMediaTags -ApiKey "1234..." -ApiVersion "v3" -Application "Radarr" -Url "http://localhost:7878"
        # Returns all tags configured in Radarr

    .EXAMPLE
        Get-StarrMediaTags -ApiKey "5678..." -ApiVersion "v3" -Application "Sonarr" -Url "http://localhost:8989"
        # Returns all tags configured in Sonarr

    .OUTPUTS
        [Array]
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
            Write-Host "Created tag '$tagName' with ID $($tagCreation.id)"
        }
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
        [array]
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
        [array]
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


#------------- DEFINE VARIABLES -------------#

$radarrApiKey = "8d6fca8d8e8342599fcd9397e859da8b"
$radarrUrl = "http://blackbox.lan:7878/radarr"
$tagNamePrefix = "ZakTag -"
$releaseGroupsList = [System.Collections.Generic.List[string]]::new()

#------------- SCRIPT STARTS -------------#

if ($PSCmdlet.ShouldProcess("Radarr", "Retrieving all movies")) {
    $apiVersion = Get-StarrApiVersion -ApiKey $radarrApiKey -Application "Radarr" -Url $radarrUrl
}

if ($PSCmdlet.ShouldProcess("Radarr", "Retrieving all movies")) {
    $allMovies = Get-StarrMedia -ApiKey $radarrApiKey -ApiVersion $apiVersion -Application "Radarr" -Url $radarrUrl
}

if ($PSCmdlet.ShouldProcess("Radarr", "Filtering results to only movies with existing files")) {
    $allMoviesWithFiles = $allMovies | Where-Object { $_.hasFile -eq $true }
    $uniqueReleaseGroups = $allMoviesWithFiles.movieFile.releaseGroup | Sort-Object -Unique
    foreach ($releaseGroup in $uniqueReleaseGroups) {
        $tagName = "$tagNamePrefix $releaseGroup"
        $releaseGroupsList.Add($tagName)
    }
}

if ($PSCmdlet.ShouldProcess("Radarr", "Retrieving all existing tags")) {
    $allExistingTags = Get-StarrMediaTags -ApiKey $radarrApiKey -ApiVersion $apiVersion -Application "Radarr" -Url $radarrUrl
}

if ($PSCmdlet.ShouldProcess("Radarr", "Creating missing tags")) {
    # Loop through each release group and check if the tag exists in Radarr, if not create it
    foreach ($releaseGroup in $releaseGroupsList) {
        if ($allExistingTags.label -notcontains $releaseGroup) {
            New-StarrTag -ApiKey $radarrApiKey -ApiVersion $apiVersion -Application "Radarr" -TagName $releaseGroup -Url $radarrUrl
        }
    }

    # Retrieve tags again so it includes the newly added release group tags
    $allExistingTags = Get-StarrMediaTags -ApiKey $radarrApiKey -ApiVersion $apiVersion -Application "Radarr" -Url $radarrUrl
}

if ($PSCmdlet.ShouldProcess("Radarr", "Filtering tags to only release group tags")) {
    # Loop through each existing tag and select release groups tags only to avoid including previously defined tags
    $releaseGroupTagsOnly = $allExistingTags | Where-Object { $_.label -like "$tagNamePrefix*" }
}

if ($PSCmdlet.ShouldProcess("Radarr", "Tagging movies with their corresponding release group tag")) {
    # Loop through each movie
    foreach ($movie in $allMoviesWithFiles) {
        $existingReleaseGroupTags = $releaseGroupTagsOnly | Where-Object { $movie.tags -contains $_.id }
        $tagToApply = $releaseGroupTagsOnly | Where-Object { $_.label -eq "$tagNamePrefix $($movie.movieFile.releaseGroup)" }

        if ($movie.tags -contains $tagToApply.id) {
            Write-Host "Movie `"$($movie.title)`" already has tag: `"$($tagToApply.label)`"" -ForegroundColor Green
            continue
        }

        if ($null -ne $existingReleaseGroupTags) {
            Write-Warning "Removing tag `"$($existingReleaseGroupTags.label)`" from `"$($movie.title)`""
            Remove-StarrMediaTag -ApiKey $radarrApiKey -ApiVersion $apiVersion -Application "Radarr" -Media $movie -TagId $existingReleaseGroupTags.id -Url $radarrUrl
        }

        Add-StarrMediaTag -ApiKey $radarrApiKey -ApiVersion $apiVersion -Application "Radarr" -Media $movie -TagId $tagToApply.id -Url $radarrUrl

        Write-Host "Added tag `"$($tagToApply.label)`" to `"$($movie.title)`"" -ForegroundColor Cyan
    }
}
