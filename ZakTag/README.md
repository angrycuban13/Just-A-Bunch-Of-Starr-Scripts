# Purpose

The ZakTag.ps1 script automatically tags movies in Radarr with their release group. The script retrieves all movies from Radarr, filters the results to only movies with existing files, and then retrieves all existing tags. The script then creates missing tags for each release group, filters the tags to only release group tags, and tags movies with their corresponding release group tag. If the movie has the wrong tag, the script will remove it and apply the correct tag.

## Prerequisites

Please fill in the variables in line 709-710:

- `$radarrApiKey` - Your Radarr API Key
- `$radarrUrl` - Your Radarr URL

## `ZakTag.ps1` usage

- Dry Run:

    ```powershell
    pwsh.exe  //path/to/zaktag.ps1 -WhatIf
    ```

- Production:

    ```powershell
    pwsh.exe  //path/to/zaktag.ps1
    ```
