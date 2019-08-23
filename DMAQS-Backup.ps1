<#

.DESCRIPTION
  Stops and queries DMAQS service then uploads output to S3, echoing timestamped archive folder to D:/Extract_Archive

.NOTES
  Version:        1.0
  Author:         Callum Bond
  Creation Date:  19/08/2019
  Purpose/Change: Initial script development

  TODO:
  - Determine if error handling can write to log without alert / write log and alert stakeholder / business critical alert
  - Improve error handling (more details)
  - Clean things up
#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

# Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"

# Set proxy address
# Set-VpnConnectionProxy = "" 

#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Name and location of logs
$log = "D:\log\log.txt"
$logFile = "D:\log"

# $logFile = New-Item -ItemType Directory -Path "$logs\Log_$((Get-Date).ToString('yyyyMMdd'))"

# File locations
$src = "C:\Temp\Extract"
$dest = "C:\Temp\Extract_Archive"

#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function stopDMAQS {
# Stop DMAQS service once safe to do so
    if ((Get-ChildItem $src -Force | Select-Object -First 1 | Measure-Object).Count -eq 0) {
        # Stop-Process -Name "DMAQS"
        Write-Output "DMAQS stopped."
        # logWrite "DMAQS stopped."
} Else {
        Write-Output "DMAQS service cannot be stopped at this time. Retrying in 30 seconds."
        Start-Sleep -Seconds 30
        stopDMAQS
        }    
}

Function queryDMAQS {
# Query DMAQS
    Try {
        # D:/Util/extract_cars.bat
        C:/Temp/Scripts/test_create.bat
        Write-Output "Extracted DMAQS data to D:/Extract."
        # logWrite "Extracted DMAQS data to D:/Extract."
    }
    
    Catch {
        Write-Output "Query failed."
        $_.Exception | Out-File $log -Append
        Break
        # emailAlert
        Exit
    }
}

Function truncateData {
    # Tread carefully here!
    Try {
        # D:/Util/truncate_vlocity_log.bat
        C:/Temp/Scripts/test_rename.bat
        Write-Output "Logs truncated."
}

    Catch {
        $_.Exception | Out-File $log -Append
        Exit
    }
}

Function uploadToS3 {
    # Upload to S3
    
    <# TODO: 
    # Confirm successful upload to S3
    # Consider building the catch statemnt to repeatedly attempt to upload to S3 until successful
    #>

    Try {
        Foreach ($f in "C:/Temp/Extract/test_file.txt") {
        Write-S3Object -BucketName REPLACE_ME -File $f -Key $f -CannedACLName public-read
        Write-Output "Uploaded $f."
    }
        } Catch {
                $_.Exception | Out-File $log -Append
                Write-Output "Failed to upload to S3."
                # emailAlert
    }
}

Function archiveData {
    # Create time-stamped folder and echo uploaded logs there
    Try {
        $New_Dest = New-Item -ItemType Directory -Path "$dest\Uploaded_To_S3_$((Get-Date).ToString('yyyyMMdd'))"
        Get-ChildItem -Path $src -Recurse -Include *.txt | Move-Item -Force -Destination $New_Dest
        Write-Output "Logs moved to D:/Extract_Archive."
    } Catch {
        $_.Exception | Out-File $log -Append
        Write-Output "Failed to archive."
        # emailAlert
    }
}

Function startDMAQS {
    # Once all complete, restart DMAQS
    If ((Get-ChildItem $src -Force | Select-Object -First 1 |Measure-Object).Count -eq 0) {
        # Start-Process -Name "DMAQS"
        Write-Output "DMAQS service started."
        Exit
    } Else {
        # emailAlert
        $_.Exception | Out-File $log -Append
        Write-Output "DMAQS started."
        Exit
    }
}

Function emailAlert($emailTo) {
# Send email to stakeholders if unexpected error encountered
<#
# TODO: Find way to authenticate with smtp server
#>
    $message = @"
        Attention!

        You have been identified as a stakeholder in the DMAQS backup process. This is an alert to inform you that the backup has failed."

        Thank you,

        IT
"@        
 
    $emailFrom = "Callum.Bond@kineticit.com.au"
    $emailTo = "Callumbond199@gmail.com"
    $subject="Alert - DMAQ Backup Failed"
    $smtpserver="smtp-mail.outlook.com"
    $smtp=New-Object Net.Mail.SmtpClient($smtpServer) 
    $smtp.Send($emailFrom, $emailTo, $subject, $message) 
} 

#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Call functions

stopDMAQS

queryDMAQS

truncateData

uploadToS3

archiveData

startDMAQS

