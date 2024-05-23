# Send-ReadarrBooksToKindle

This script was written to alleviate the gap that exists between managing your book library with Readarr and sending those books via email to eReaders such as Kindle.

I have only tested this script with sending to a Kindle, but if you have a different eReader that supports receiving eBooks via email, please let me know if it works!

> [!IMPORTANT]
> Send to Kindle For Email only supports the following file types: PDF, DOC, DOCX, TXT, RTF, HTM, HTML, PNG, GIF, JPG, JPEG, BMP, EPUB - [Source](https://www.amazon.com/sendtokindle/email)

## Script Requirements

* [Powershell Universal](https://powershelluniversal.com/) v4 or later (Free Version)
* [Readarr](https://readarr.com/)
* [`Send-MailKitMessage`](https://github.com/austineric/Send-MailKitMessage) Powershell Module

## Configuration

### Send-MailKitMessage

1. Install the module as specified [here](https://github.com/austineric/Send-MailKitMessage?tab=readme-ov-file#installation).

### Powershell Universal Configuration

1. Install Powershell Universal using one of their [supported installation methods](https://docs.powershelluniversal.com/getting-started) and access it through your browser, once installed.

> [!WARNING]
> Windows installations will require you to create an inbound firewall rule to allow traffic over the port that Powershell Universal is listening on.

#### Script

1. Navigate to Automation > Scripts.
1. Click on `Create New Script` and give it an easily recognizable name (e.g. `Send Readarr Books to Kindle`).
1. Copy/paste the [script contents](https://raw.githubusercontent.com/angrycuban13/Just-A-Bunch-Of-Starr-Scripts/main/Send-ReadarrBooksToKindle/Send-ReadarrBooksToKindle.ps1) into the code editor and click `Save`.

#### API Endpoint

1. Navigate to APIs > Endpoints
2. Click on `Create New Endpoint`.
   1. On the `URL` field, give it an URL of your choice (e.g. `readarr`).
   1. On the `Method` field, make sure to add `POST`.
      1. I recommend you leave `GET` enabled as well so you can debug as needed.
3. After the endpoint has been created, click on the `Edit` button and copy/paste the following into the code editor


    ```powershell
    
    # Convert JSON to PSObject
    $readarrWebhookData = ConvertFrom-Json -InputObject $body

    if ($readarrWebhookData.EventType -eq "Test") {
        Write-Host "Readarr sent a test"
    }

    else {
    $bookAuthor = $readarrWebhookData.author.name
    $bookTitle = $readarrWebhookData.book.title
    $bookFilePath = $readarrWebhookData.bookfiles.path

    Invoke-PSUScript -Name 'YOUR-SCRIPT-NAME-HERE' -Author $bookAuthor -BookTitle $bookTitle -BookFilePath $bookFilePath -Wait
    }
    ```

> [!IMPORTANT]
> Make sure to update `YOUR-SCRIPT-NAME-HERE` with the name of the script from the [previous step](#script)

4. Click `Save`

#### Variables

> [!WARNING]
> If you don't configure these variables, the script exceution will fail

##### Simple Variables

| Variable Type | Name | Store in Database | Type | Value
| --- | --- | --- | --- | ---
|Simple |  `mailSmtpServer` | No | `String` | Your SMTP Server (e.g. `mail.domain.com`)
| Simple | `mailSmtpPort` | No | `String` | SMTP Port  (e.g. `587` or `465`)
| Simple | `mailSmtpFromAddress` | No | `String`| SMTP address you will be using to send emails (e.g. `myemail@domain.com`)
| Simple | `mailSmtpToAddress` | No | `String` | SMTP address that will be receiving emails (e.g. `yourotheremail@domain.com`)

> [!TIP]
> You could theoretically specify an *Array* instead of a *String* for "$mailSmtpToAddress" and use multiple email addresses if you wanted to send it to more than one person but I have not tested this

##### Secret Variables

| Variable Type | Name | Type | Username | Password | Vault
| --- | --- | --- | --- | --- | --
| Secret | `mailSmtpCredentials` | `PSCredential` | Username used to authenticate with mail server (e.g. `myusername@domain.com`) | Password used to authenticate with your mail server (e.g. hunter2) | Your own preference, further vault info can be found [here](https://docs.powershelluniversal.com/platform/variables#vaults).

## Common Issues

1. Powershell Universal running on Windows and Readarr running on Docker (or viceversa if you hate puppies) causes `$bookFilePath` to have the incorrect path.
   1. Since this is very specific to every setup, there might be some tweaking on your part similar to Remote File Paths in Readarr.
