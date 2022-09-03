[CmdletBinding(SupportsShouldProcess)]
param (
    [Parameter()]
    $null
)

#------------- DEFINE VARIABLES -------------#

[string]$sonarrApiKey = ""
[string]$sonarrUrl = ""
[int]$seriesToRename = 10


#------------- SCRIPT STARTS -------------#

if ($PSVersionTable.PSVersion.Major -lt 7){
    throw "You need at least Powershell 7 to run this script"
}

if (-Not (Test-Path -Path $PSScriptRoot\seriesChecked.txt )){
    New-Item -ItemType File -Name seriesChecked.txt -Path $PSScriptRoot
}

$seriesRenamed = Get-Content $PSScriptRoot\seriesChecked.txt

$webHeaders = @{
    "x-api-key"= "$($sonarrApiKey)"
}

$allSeries = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/series" -Headers $webHeaders -StatusCodeVariable apiStatusCode

$filteredSeries = $allSeries | Where-Object {$_.title -notin $seriesRenamed} | Select-Object -First $seriesToRename

if ($filteredSeries.count -eq 0){
    Clear-Content -Path $PSScriptRoot\seriesChecked.txt
}


foreach ($series in $filteredSeries){

    $episodesToRename = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/rename?seriesId=$($series.id)" -Headers $webHeaders -StatusCodeVariable apiStatusCode

    if ($episodesToRename.count -gt 0){

        Write-Output "$($series.title) has $($episodesToRename.count) episodes to be renamed"

            $renameFiles = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Post -ContentType "application/json" -Body "{`"name`":`"RenameFiles`",`"seriesId`":$($series.id),`"files`":[$($episodesToRename.episodeFileId -join ",")]}" -StatusCodeVariable apiStatusCode

            do {
                $tasks = Invoke-RestMethod -Uri "$($sonarrUrl)/api/v3/command" -Headers $webHeaders -Method Get
                $renameTask = $tasks | Where-Object {$_.id -eq $renameFiles.id}

                Write-Output "Waiting for files to be renamed for $($series.title)"

                Start-Sleep 5
            } until (
                $renameTask.status -eq "completed"
            )#>
        Add-Content -Value $series.title -Path $PSScriptRoot\seriesChecked.txt
    }
    else {
        Write-Output "$($series.title) has no episodes to be renamed"
        Add-Content -Value $series.title -Path $PSScriptRoot\seriesChecked.txt
    }

}
