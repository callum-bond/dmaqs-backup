<#
.DESCRIPTION
  Automation script to extract, transform and load data from DMAQS database.
 
.NOTES
  Version:        1.0
  Author:         Callum Bond
  Creation Date:  19/08/2019
  Purpose/Change: Initial script development
#>
 
#---------------------------------------------------------[Initialisations]--------------------------------------------------------
 
$ErrorActionPreference = "Stop"
 
#----------------------------------------------------------[Declarations]----------------------------------------------------------
 
# Name and location of logs
$log = "D:\log\log.txt"
$logFile = "D:\Log"
 
# File locations
$src = "D:\Extract"
$dest = "D:\Extract_Archives"
 
# S3 parameters
$S3BucketName = 'vline-datalake/raw_Dmaq'
 
#-----------------------------------------------------------[Functions]------------------------------------------------------------
 
Function Stop-DMAQS {
# Check DMAQS output folder for *.x40 files. Stop service if none are found.
    if ((Get-ChildItem $src -Filter *.x40 | Select-Object -First 1 | Measure-Object).Count -eq 0) {
        Stop-Service -Name "DMAQS"
        Get-Timestamp | Out-File $log -Append
        Write-Output 'DMAQS stopped.' | Tee-Object -Filepath $log -Append
} Else {
        Write-Output 'DMAQS service cannot be stopped at this time. Retrying in 30 seconds.'
        Start-Sleep -Seconds 30
        Stop-DMAQS
        }    
}
 
Function Query-DMAQS {
# TODO: Exit gracefully if no data to be queried
    Try {
        Start-Process "cmd.exe" "/c D:/Utils/extract_cars.bat" -Wait
        Get-Timestamp | Out-File $log -Append
        Write-Output 'Extracted DMAQS data to D:/Extract.' | Tee-Object -Filepath $log -Append
    }
   
    Catch {
        Write-Output 'Query failed.'
        Write-Log
        Exit
    }
}
 
Function Truncate-Data {
# Check for and truncate .gz files, otherwise restart DMAQS and exit
    if ((Get-ChildItem $src -Filter *.gz | Select-Object -First 1| Measure-Object).Count -ne 0) {
        Start-Process "cmd.exe" "/c D:/Utils/truncate_vlocity_log.bat" -Wait
        Write-Output 'Logs truncated.' | Tee-Object -Filepath $log -Append
    } else {
        Get-Timestamp | Out-File $log -Append
        Write-Output 'No data to be truncated. Restarting DMAQS.' | Tee-Object -Filepath $log -Append
        Start-DMAQS
    }
}
 
Function Upload-ToS3 {
# TODO: Make this more robust
    Try {
        $results = Get-ChildItem $src -Recurse -Include '*.gz'
        foreach ($path in $results) {
        $fileName = [System.IO.Path]::GetFileName($path)
        Write-S3Object -BucketName $S3BucketName -File $path -Key vlocity_log_incoming/$fileName
        Get-Timestamp | Out-File $log -Append
        Write-Output 'Uploaded to S3:' $fileName | Tee-Object -Filepath $log -Append
        }
    }
 
    Catch {
            Write-Log
            Write-Output 'Failed to upload to S3: ' $_.Exception.Message
    }
}
 
Function Archive-Data {
    # Create time-stamped folder and echo uploaded logs there
    # TODO: Handle creation of multiple folders with the same timestamp (currently fails to archive more than once per day)
    Try {
        $New_Destination = New-Item -ItemType Directory -Path "$dest\Moved_To_S3_$((Get-Date).ToString('yyyyMMdd'))"
        Get-ChildItem -Path $src -Recurse -Include *.gz | Move-Item -Force -Destination $New_Destination
        Get-Timestamp | Out-File $log -Append
        Write-Output 'Logs moved to D:/Extract_Archives.' | Tee-Object -Filepath $log -Append
    } Catch {
        Write-Log
        Write-Output 'Failed to archive.'
    }
}
 
Function Start-DMAQS {
    # Once all complete, restart DMAQS
    If ((Get-ChildItem $src -Force | Select-Object -First 1 | Measure-Object).Count -eq 0) {
        Start-Service -Name "DMAQS"
        Get-Timestamp | Out-File $log -Append
        Write-Output 'DMAQS service started.' | Tee-Object -Filepath $log -Append
        Exit
    } Else {
        Write-Output 'Could not restart DMAQS. Retrying in 30 seconds.'
        Start-Sleep -Seconds 30
        Write-Log
        Start-DMAQS
    }
}
 
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
