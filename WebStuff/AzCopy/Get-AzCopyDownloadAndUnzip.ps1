$GetAZCopyVer = Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows"
$CurrentAzCopyVer = $GetAZCopyVer.BaseResponse.ResponseUri.AbsolutePath
$OnWeb = $CurrentAzCopyVer.Split("/")[2]
$AzCopyFile = 'C:\azcopy\azcopy.exe'

$GetAzCopyInBin = (& $AzCopyFile --help)
$InFolder = $GetAzCopyInBin.split(" ")[1]

if ($OnWeb -match $InFolder){

    # Skip download
}
else{

    # Download
    Invoke-WebRequest -Uri "https://aka.ms/downloadazcopy-v10-windows" `
            -OutFile C:\AzCopy\bin\AzCopy.zip `
            -UseBasicParsing
    
    if(Test-Path "C:\AzCopy\bin\AzCopy.zip" ){

        # Remove current AzCopy
        Remove-Item -Path C:\AzCopy\bin\azcopy.exe

        # Expand archive of downloaded file
        Expand-Archive C:\AzCopy\bin\AzCopy.zip C:\AzCopy\bin\AzCopy -Force
    
        # Move to correct location
        Get-ChildItem C:\AzCopy\bin\AzCopy\*\azcopy.exe | Move-Item -Destination "C:\AzCopy\bin\AzCopy.exe"
    
        # Clean up
        Remove-Item -Path C:\AzCopy\bin\AzCopy.zip -Force
        Remove-Item -Path C:\AzCopy\bin\AzCopy -Recurse -Force
    }
    else{
    
        Write-Output "Could not download AzCopy. Did not remove current version"
    }
}