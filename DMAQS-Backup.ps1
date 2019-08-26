﻿<#

.DESCRIPTION
  Stops and queries DMAQS service then uploads output to S3, echoing timestamped archive folder to D:/Extract_Archive

.NOTES
  Version:        1.0
  Author:         Callum Bond
  Creation Date:  19/08/2019
  Purpose/Change: Initial script development

  TODO:
  - Determine level of error-handling required (write to log, generate email, 24/7)
  - General cleanup
  - Improve behaviour of try/catch statements
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

# Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"

# Set proxy address
# Set-VpnConnectionProxy = "" 

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Name and location of logs
$log = "D:\log\log.txt"
$logFile = "D:\Log"

# $logFile = New-Item -ItemType Directory -Path "$logs\Log_$((Get-Date).ToString('yyyyMMdd'))"

# File locations
$src = "D:\Extract"
$dest = "D:\Extract_Archives"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function Stop-DMAQS {
# Check DMAQS output folder for *.x40 folders. Stop service if none are found.
    if ((Get-ChildItem $src -Filter *.x40 | Select-Object -First 1 | Measure-Object).Count -eq 0) {
        Stop-Service -Name "DMAQS"
        Write-Output "DMAQS stopped."
} Else {
        Write-Output "DMAQS service cannot be stopped at this time. Retrying in 30 seconds."
        Start-Sleep -Seconds 30
        Stop-DMAQS
        }    
}

Function Query-DMAQS {
# Query DMAQS
    Try {
        D:/Utils/extract_cars.bat
        Write-Output "Extracted DMAQS data to D:/Extract."
    }
    
    Catch {
        Write-Output "Query failed."
        Write-Log
        Break
    }
}

Function Truncate-Data {
    # Tread carefully here!
    Try {
        D:/Utils/truncate_vlocity_log.bat
        Write-Output "Logs truncated."
}
    Catch {
        Write-Log
        Exit
    }
}

Function Upload-ToS3 {
    # Upload to S3
    
    <# TODO: 
    # Confirm successful upload to S3
    # Consider building the catch statemnt to repeatedly attempt to upload to S3 until successful
    #>

    Try {
        Foreach ($f in 'D:\Extract\*.csv.gz') {
        Write-S3Object -BucketName vlocity_log_incoming_test -File $f -Key $f -CannedACLName public-read
        Write-Output "Uploaded $f."
    }
        } Catch {
            Write-Log
            Write-Output 'Failed to upload to S3.'
    }
}

Function Archive-Data {
    # Create time-stamped folder and echo uploaded logs there
    Try {
        $New_Destination = New-Item -ItemType Directory -Path "$dest\Moved_To_S3_$((Get-Date).ToString('yyyyMMdd'))"
        Get-ChildItem -Path $src -Recurse -Include *.csv.gz | Move-Item -Force -Destination $New_Destination
        Write-Output 'Logs moved to D:/Extract_Archives.'
    } Catch {
        Write-Log
        Write-Output 'Failed to archive.'
    }
}

Function Start-DMAQS {
    # Once all complete, restart DMAQS
    If ((Get-ChildItem $src -Force | Select-Object -First 1 |Measure-Object).Count -eq 0) {
        Start-Service -Name "DMAQS"
        Write-Output 'DMAQS service started.'
        Exit
    } Else {
        Write-Output "Could not restart DMAQS. Retrying in 30 seconds."
        Start-Sleep -Seconds 30
        Start-DMAQS
    }
}

<# 

Function Email-Alert($emailTo) {
# Send email to stakeholders if unexpected error encountered

    $message = @"
        Attention!

        You have been identified as a stakeholder in the DMAQS backup process. This is an alert to inform you that the backup has failed."

        Thank you,

        IT
"@        
 
    $emailFrom = ""
    $emailTo = ""
    $subject="Alert - DMAQ Backup Failed"
    $smtpserver="smtp-mail.outlook.com"
    $smtp=New-Object Net.Mail.SmtpClient($smtpServer) 
    $smtp.Send($emailFrom, $emailTo, $subject, $message) 
} 

#> 

Function Get-TimeStamp {
    return "[{0:dd/MM/yy} {0:HH:mm:ss}]" -f (Get-Date)
}

Function Write-Log {
        Get-Timestamp | Out-File $log -Append   
        $_.Exception | Out-File $log -Append
}

#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Stop-DMAQS
# Query-DMAQS
# Truncate-Data
Upload-ToS3
# Archive-Data
# Start-DMAQS

