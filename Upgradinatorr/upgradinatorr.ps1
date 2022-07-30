<#
.SYNOPSIS
This script will kick off manual search on a random number of movies in Radarr and add a specific tag to those movies so they aren't searched again

Thanks @Roxedus for the cleanup and general pointers

.LINK
https://radarr.video/docs/api/#/

#>

[CmdletBinding(SupportsShouldProcess,DefaultParameterSetName="configFile")]
param (
    # Define app
    [Parameter(ParameterSetName='configfile')]
    [Parameter(ParameterSetName='cmdline')]
    [string[]]
    $app,
    # Define the API key
    [Parameter(ParameterSetName='cmdline')]
    [string]
    $radarrApiKey,
    # Define the application URL
    [Parameter(ParameterSetName='cmdline')]
    [string]
    [ValidateScript({
        if ($_ -match "https?:\/\/" -and -Not $_.EndsWith("/")){
            return $true
        }
        elseif ($_.EndsWith("/")){
            throw "Url should not end with /"
        }
        else{
            throw "Your Radarr URL did not start with http(s)://"
        }
    })]
    $radarrUrl,
    # Define the name of the tag to be applied
    [Parameter(ParameterSetName='cmdline')]
    [string]
    $tagName,
    # Define number of movies to search
    [Parameter(ParameterSetName='cmdline')]
    [ValidateRange("Positive")]
    [Int]
    $count,
    # Define monitored status
    [Parameter(ParameterSetName='cmdline')]
    [Bool]
    $monitored,
    # Define movie status
    [Parameter(ParameterSetName='cmdline')]
    [String]
    $movieStatus,
    # Define a configuration file.
    [Parameter(ParameterSetName='configfile')]
    [string]
    $configFile
)

if ($PSVersionTable.PSVersion -notlike "7.*") {
    throw "You need Powershell 7 to run this script"
}

#if using a configuration file.
if ($PSCmdlet.ParameterSetName -eq 'configfile') {
    $configFile = Join-Path -Path $PSScriptRoot -ChildPath config.ini
}

#if a configuration file was specified the read the parameters from the file.
if ($configFile){
    #Resolve the path if it's relative.s
    try {
        $configFilePath = Resolve-Path ($configFile) -ErrorAction Stop
        Write-Verbose "Configuration File: $configFilePath"
        $configFile=$configFilePath
    }
    catch {
        Write-Error "Could not resolve the the path to the configuration file '$configFile'"
        Exit
    }

    if (Test-Path  $configFile -PathType Leaf) {
        #try loading the configuration file content.
        try{
            $fileContent = Get-Content $configFile
        }
        catch {
            Write-Error "The configuration file '$configFile' cannot be read."
            Exit
        }

        #Loop through each line splitting on the first equal sign.
        foreach ($line in $fileContent) {
            #Skip lines that are empty, INI comments, or INI sections.
            if ([string]::IsNullOrEmpty($Line) -or (@('[',';',' ') -contains $Line[0])){
                continue
            }

            #Split the line on the first equal sign and clean up the name.
            $data = $line.Split("=")
            $data[0]=$data[0].Trim()

            #if there's no value then treat it like a switch.  Otherwise, process the value.
            if($Data.Count -eq 2){
                #Try to evaluate the value as an expression otherwise use the value as-is.
                Write-Verbose -Message "trying to Set Variable [$($Data[0])] to [$($Data[1])]"
                try {
                    if ($Data[0] -eq 'monitored') {
                        Set-Variable -Name $Data[0] -Value ($Data[1] -as [Bool])
                    }
                    elseif ($Data[0] -eq 'count') {
                        Set-Variable -Name $Data[0] -Value ($Data[1] -as [Int64]) -Force -Whatif:$False
                    }
                    else {
                        Set-Variable -Name $Data[0] -Value ($Data[1] -as [string]) -Force -Whatif:$False
                    }
                }
                catch {
                    Set-Variable -Name $Data[0] -Value $Data[1] -Force -Whatif:$False
                }
            }
            elseif ($Data.Count -eq 1) {
                Set-Variable -Name $Data[0] -Value $True -Force -Whatif:$False
            }
            Write-Verbose "Parameter $((Get-Variable $Data[0]).Name) is set to $((Get-Variable $Data[0]).Value) and is of [$($((Get-Variable $Data[0]).Value.GetType()))] type."
        }
    }
    else {
        Write-Error "The configuration file '$configFile' cannot be found."
        exit
    } #Config file exists.
} #if config file was passed.

if ($app -eq "radarr"){
    $webHeaders = @{
        "x-api-key" = $radarrApiKey
    }

    Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/system/status" -Method Get -StatusCodeVariable apiStatusCode -Headers $webHeaders | Out-Null

    if ($apiStatusCode -notmatch "2\d\d"){
        throw "Radarr returned $apiStatusCode"
    }

    $tagList = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/tag" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode
    $tagId = $taglist | Where-Object {$_.label -contains $radarrTagName} | Select-Object -ExpandProperty id

    if ($apiStatusCode -notmatch "2\d\d"){
        throw "Failed to get tag list"
    }

    if ($tagList.label -notcontains $radarrTagName){
        throw "$radarrTagName doesn't exist in Radarr"
    }

    $allMovies = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/movie" -Headers $webHeaders -Method Get -StatusCodeVariable apiStatusCode

    if ($apiStatusCode -notmatch "2\d\d"){
        throw "Failed to get movie list"
    }

    $movies = $allMovies | Where-Object { $_.tags -notcontains $tagId -and $_.monitored -eq $monitored -and $_.status -eq $movieStatus }

    if ($movies.Count -eq 0){
        throw "No movies left to search"
    }

    else {
        $randomMovies = Get-Random -InputObject $movies -Count $count
        $movieCounter = 0

        foreach ($movie in $randomMovies) {
            $movieCounter++
            Write-Progress -Activity "Search in Progress" -PercentComplete (($movieCounter / $count) * 100)
            if ($PSCmdlet.ShouldProcess($movie.title, "Searching for movie")){
                $addTag = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/movie/editor" -Headers $webHeaders -Method Put -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"movieIds`":[$($movie.ID)],`"tags`":[$tagId],`"applyTags`":`"add`"}"

                if ($apiStatusCode -notmatch "2\d\d"){
                    throw "Failed to add tag to $($movie.title) with statuscode $apiStatusCode\n content: $addTag"
                }

                $searchMovies = Invoke-RestMethod -Uri "$($radarrUrl)/api/v3/command" -Headers $webHeaders -Method Post -StatusCodeVariable apiStatusCode -ContentType "application/json" -Body "{`"name`":`"MoviesSearch`",`"movieIds`":[$($movie.ID)]}"

                if ($apiStatusCode -notmatch "2\d\d"){
                    throw "Failed to search for $($movie.title) with statuscode $apiStatusCode\n content: $searchMovies"
                }
                Write-Host "Manual search kicked off for" $movie.title
            }
        }
    }
}

if ($app -eq "sonarr"){
    throw "You are getting ahead of yourself..."
}

if ($app -eq "lidarr"){
    throw "Definitely not doing Lidarr, sorry"
}

if ($app -eq "whisparr"){
    throw "naughty boy"
}

if ($app -eq "prowlarr"){
    throw "Is your name Orange?"
}
#>
