<#
.SYNOPSIS
	Rename all files with the same extension to the same name.

.DESCRIPTION
    Rename all files with the same extension to the same name. This is intended for files in different directories.

.PARAMETER Extension
    Specify the extension.
    
.PARAMETER Log
    Specify if logging is enabled.
        
.PARAMETER LogPath
    Specify the path the logs should go if default is not desired. Default location is C:\logs.

.PARAMETER NewFileName
    Specify the name all files will be changed too.

.PARAMETER Path
    Specify the path to search for all files.

.EXAMPLE
    Rename-ImageFileByExtension -Extension .jpg -Log -NewFileName "Album_Art" -Path $env:USERPROFILE\Music

.NOTES
    Any improvements welcome.
#>

function Rename-ImageFileByExtension {

    [CmdletBinding()]    
    param(
        [Parameter(Mandatory=$true)]
        [ValidateSet('.jpg','.png')]
        [String]$Extension,
        [Switch]$Log,
        [String]$LogPath='C:\logs\FileRename\',
        [Parameter(Mandatory=$true)]
        [String]$NewFileName,
        [Parameter(Mandatory=$true)]
        [String]$Path
    )

    #region INITIAL VARIABLES

        $LogFile = "$(Get-Date -Format yyyy-MM-dd_hh-mm-ss)_FileRename.log"

    #endregion

    #region FUNCTIONS

        function Set-Change {

            param(
                [Array[]]$InputArray,
                [String]$Ext,
                [String]$NName
            )

            foreach ($Item in $InputArray){

                # if there is only one file, rename
                if ((Get-ChildItem $Item.DirectoryName | Where-Object {$PSItem.Extension -eq $Ext}).Count -eq 1){

                    $NewName = $NName + $Item.Extension

                    if ($Item.Name -ne $NewName){
                        
                        Write-Output "`0"
                        Write-Host -ForegroundColor Green "$($Item.FullName)"
                        Write-Host -ForegroundColor Green "Attempting to Change $($Item.Name) to $NName$($Item.Extension)"
                        Rename-Item -Path $Item.FullName -NewName $NewName -Force -ErrorVariable NoRename -ErrorAction SilentlyContinue
                        if($NoRename){
                        
                            Write-Warning "Unable to rename file: $($Item.FullName)"
                        }
                        
                        $TestChange = Test-Path -Path ($Item.DirectoryName + "\$NewName")
                        if ($TestChange -eq $true){
                        
                            Write-Host "Changed Succeeded"
                            Write-Output "`0"
                        }
                        else {"what"}
                    }
                    else{
                    
                        Write-Host -ForegroundColor Yellow "$($Item.FullName)"
                        Write-Host -ForegroundColor Yellow "No need to change name. Currently: $($Item.Name)"
                    }
                }
                else {
                
                    Write-Host -ForegroundColor Cyan "Skipping $($Item.Name) in Folder $($Item.DirectoryName)"
                    Continue
                }
            }
        }

    #endregion

    #refion SCRIPT

       if ($Log){

            if(-not (Test-Path $LogPath)){
            
                New-Item -Path $LogPath -ItemType Directory
            }
            Start-Transcript -Path "$LogPath\$LogFile"
        }
        else{
        
            Write-Verbose "No logging"
        }

        Write-Output "`0"
        Write-Output "Please wait..."
        Write-Output "`0"
        $Files = Get-ChildItem "$Path\*" -Recurse | Where-Object {$PSItem.Extension -eq $Extension}

        Set-Change -InputArray $Files -Ext $Extension -NName $NewFileName

        if ($Log){
        
            Stop-Transcript
        }

    #endregion
}