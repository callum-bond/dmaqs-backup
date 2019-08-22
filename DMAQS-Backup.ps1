<#

.DESCRIPTION
  Stops and queries DMAQS service then uploads output to S3, echoing timestamped archive folder to D:/Extract_Archive

.NOTES
  Version:        1.0
  Author:         Callum Bond
  Creation Date:  19/08/2019
  Purpose/Change: Initial script development

#>

#---------------------------------------------------------[Initialisations]--------------------------------------------------------

# Set Error Action to Silently Continue
$ErrorActionPreference = "Stop"

# Set proxy address
# Set-VpnConnectionProxy = "" 


# Database connection credentials
# TODO: Find a better way of authenticating DB access (i.e. not plaintext)
# TODO: Execute remote SQL file, incoporating postgre SQL exit flag

# $dbServer = ""
# $dbName = ""
# $uid = ""
# $pwd = ""


#----------------------------------------------------------[Declarations]----------------------------------------------------------

# Name and location of logs
$logs = "D:\Logs"
$logFile = New-Item -ItemType File -Path "$logs\$((Get-Date).ToString('yyyyMMdd'))"

# File locations
$src = "D:\Extract"
$dest = "C:\Extract_Archive"

# $out = C:Pathfile.bat


#-----------------------------------------------------------[Functions]------------------------------------------------------------

Function stopDMAQS {
# Stop DMAQS service once safe to do so
    if ((Get-ChildItem $src -Force | Select-Object -First 1 |Measure-Object).Count -eq 0) {
        # Stop-Process -Name "DMAQS"
        Write-Output "DMAQS stopped..."
        log-Write "DMAQS stopped."
} Else {
        Write-Output "DMAQS service cannot be stopped at this time. Retrying in 30 seconds."
        Start-Sleep -Seconds 30
        stopDMAQS
        log-Write "DMAQS failed to stop... Retrying in 30 seconds."
        }    
}

Function queryDMAQS {
# Query DMAQS database.
# Version 1: Call existing batch script and pipe output to $out variable.
    Try {
        D:/Util/extract_cars.bat
        Write-Output "Extracted DMAQS data to D:/Extract."
        logWrite "Extracted DMAQS data to D:/Extract."
    }
    
    Catch {
        Write-Output "Query failed."
        logWrite "Query failed."
        emailAlert
        Exit
    }
}

Function truncateData {
    # D:/Util/truncate_vlocity.log.bat
}

Function uploadToS3 {
    # Upload to S3
    
    <# TODO: 
    # Confirm successful upload to S3
    # Consider building the catch statemnt to repeatedly attempt to upload to S3 until successful
    #>

    Try {
        Foreach ($f in "*.csv.gz") {
        Write-S3Object -BucketName Vlocity_Incoming_Logs_Test -File $f -Key $f -CannedACLName public-read
        Write-Output "Uploaded $f."
        logWrite "Uploaded $f."
    }
        } Catch {
        Write-Output "File $f failed to upload."
        logWrite "File $f failed to upload."
        emailAlert
    }
}

Function archiveData {
    # Create archive of data and store in D:/Archive
    <#
    TODO: Move logs to newly created folder
    #>

    Try {
        New-Item -ItemType Directory -Path "$src\Uploaded_To_S3\$((Get-Date).ToString('yyyyMMdd'))"
        # Move logs to folder
        Write-Output "Logs moved to [folder]". 
        logWrite "Logs moved to folder." 
    } Catch {
        Write-Output "Failed to move item to archive folder."
        logWrite "Failed to move item to archive folder."
        emailAlert
    }
}

Function startDMAQS {
    # Once all complete, restart DMAQS

    <# TODO:
    # Determine a more robust way to find if DMAQS can be restarted
    #> 

    If ((Get-ChildItem $src -Force | Select-Object -First 1 |Measure-Object).Count -eq 0) {
        # Start-Process -Name "DMAQS"
        Write-Output "DMAQS service started."
        logWrite "DMAQS service started."
        Exit
    } Else {
    # Fix this up
        emailAlert
        Exit
    }
}

Function emailAlert($emailTo) {
    $message = @"
        Attention!

        You have been identified as a stakeholder in the DMAQS backup process. This is an alert to inform you that the backup has failed."

        Thank you,

        IT
"@        
 
    $emailFrom = "Callum.Bond@kineticit.com.au"
    $subject="Alert - DMAQ Backup Failed"
    $smtpserver="# I have no idea what the details for this are #"
    $smtp=New-Object Net.Mail.SmtpClient($smtpServer) 
    $smtp.Send($emailFrom, $emailTo, $subject, $message) 
} 


Function logWrite {
    # Write to log 
    Param([string]]$logString])
    Add-Content $logFile -value $logstring
    }

#-----------------------------------------------------------[Execution]------------------------------------------------------------

# Start logging


# Call functions

# stopDMAQS

# queryDMAQS

# truncateData

# uploadToS3

# archiveData

# startDMAQS

