[CmdletBinding()]
param (
    [Parameter(Mandatory = $true)]
    [string]
    $Author,

    [Parameter(Mandatory = $true)]
    [string]
    $BookTitle,

    [Parameter(Mandatory = $true)]
    [string]
    $BookFilePath
)

function Get-RandomEmailContent {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true, ParameterSetName = 'EmailSubject')]
        [switch]
        $EmailSubject,

        [Parameter(Mandatory = $true, ParameterSetName = 'EmailBody')]
        [switch]
        $EmailBody
    )

    begin {
        $url = 'https://whatthecommit.com/index.txt'
    }

    process {
        Start-Sleep -Milliseconds 250

        $response = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop -SkipHttpErrorCheck -StatusCodeVariable statusCode

        if ($emailSubject.IsPresent) {

            if ($statusCode -notmatch '2\d\d') {
                Write-Error "Failed to get random email subject. Status code: $statusCode"
                $content = 'Lorem ipsum'
            }

            else {
                $content = $response
            }
        }

        elseif ($emailBody.IsPresent) {
            if ($statusCode -notmatch '2\d\d') {
                Write-Error "Failed to get random email body. Status code: $statusCode"
                $content = 'Lorem ipsum'
            }

            else {
                $content = $response
            }
        }

        else {
            throw 'Please specify either EmailSubject or EmailBody'
        }
    }

    end {
        $content
    }
}

function Send-EmailToKindle {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]
        $EmailSubject,

        [Parameter(Mandatory = $true)]
        [string]
        $EmailBody

        <#         [Parameter(Mandatory = $true)]
        [string]
        $BookFilePath,

        [Parameter(Mandatory = $true)]
        [string]
        $BookTitle,

        [Parameter(Mandatory = $true)]
        [string]
        $Author #>
    )

    begin {
        #authentication ([System.Management.Automation.PSCredential], optional)
        $Credential = [System.Management.Automation.PSCredential]::new($secret:mailSmtpCredentials)

        #SMTP server ([string], required)
        $SMTPServer = $mailSmtpServer

        #port ([int], required)
        $Port = $mailSmtpPort

        #sender ([MimeKit.MailboxAddress] http://www.mimekit.net/docs/html/T_MimeKit_MailboxAddress.htm, required)
        $From = [MimeKit.MailboxAddress]$mailSmtpFromAddress

        #recipient list ([MimeKit.InternetAddressList] http://www.mimekit.net/docs/html/T_MimeKit_InternetAddressList.htm, required)
        $RecipientList = [MimeKit.InternetAddressList]::new()
        $RecipientList.Add([MimeKit.InternetAddress] $mailSmtpToAddress)

        #subject ([string], optional)
        $Subject = $emailSubject

        #text body ([string], optional)
        $TextBody = $emailBody

        #attachment list ([System.Collections.Generic.List[string]], optional)
        $AttachmentList = [System.Collections.Generic.List[string]]::new()
        $AttachmentList.Add($bookFilePath)
    }

    process {
        #splat parameters
        $emailParams = @{
            'Credential'     = $Credential
            'SMTPServer'     = $SMTPServer
            'Port'           = $Port
            'From'           = $From
            'RecipientList'  = $RecipientList
            'Subject'        = $Subject
            'TextBody'       = $TextBody
            'AttachmentList' = $AttachmentList
        }
    }

    end {
        #send message
        Write-Host "Emailing book $bookTitle by $author to Kindle..."
        Send-MailKitMessage @emailParams
    }
}

New-PSDrive -Name 'S' -PSProvider FileSystem -Root '\\synology.lan\data' -Credential $secret:SynologySMB | Out-Null

$emailSubject = Get-RandomEmailContent -EmailSubject

$emailBody = Get-RandomEmailContent -EmailBody

Send-EmailToKindle -EmailSubject $emailSubject -EmailBody $emailBody #-BookFilePath $bookFilePath -BookTitle $bookTitle -Author $author
