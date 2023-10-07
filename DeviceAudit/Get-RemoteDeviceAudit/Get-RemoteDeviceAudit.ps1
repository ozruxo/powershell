<#
.SYNOPSIS
    Get detailed information from any remote computer.

.DESCRIPTION
    Get detailed information from any remote computer.

.PARAMETER ComputerNames
	Place hostname(s) of computer(s).

.PARAMETER CreateCSVOnly
    Creates a directory on the root of your drive (C:\TMP\<ComputerName>) and copies over the CSV that were created on the remote computer.

.PARAMETER CreateExcelFromCSVOnly
    Prompts for you to provide a directory location of where the files are located to create a Excel from. Name of the folder with the CSV files should match the name ComputerName paramter. Input of directory path will just be the path to the folder with name matching the ComputerName parameter.
            
.EXAMPLE
    Get-RemoteDeviceAudit -ComputerNames <ComputerName>

.EXAMPLE
    Get-RemoteDeviceAudit -ComputerNames <ComputerName>, <ComputerName>

.EXAMPLE
    Get-RemoteDeviceAudit -ComputerNames <ComputerName> -CreateCSVOnly

.EXAMPLE
    Get-RemoteDeviceAudit -ComputerNames <ComputerName> -CreateExcelFromCSVOnly

.NOTES
    Should re-write the network portion insteading of silencing errors
    Should include more error handling/output
    [scriptblock]::Create(). Should probably allow script to run against self
    I was lazy with some additions
#>

#function Get-RemoteDeviceAudit {

    param(

        [Parameter(Mandatory=$true)]
        [String[]]$ComputerNames,
        [Switch]$CreateCSVOnly,
        [Switch]$CreateExcelFromCSVOnly
    )

    Begin{  
        #region LOCAL LOGGING AND DIRECTORY CREATION

            $LogDate           = Get-Date -Format yyyy-MM-dd_hh-mm-ss
            $LogExcelDirectory = "$env:USERPROFILE\Desktop\ComputerAudits"
            $LogJobsDirectory  = "C:\logs\SystemAusitJobLogs"
            
            if(-not(Test-Path "$LogExcelDirectory")){
                        
                New-Item -Path $LogExcelDirectory -ItemType Directory   
            }
            
            if(-not(Test-Path "$LogJobsDirectory")){
                       
                New-Item -Path $LogJobsDirectory -ItemType Directory   
            }

        #endregion

        #region SWITCH PARAMETERS

            if ($CreateCSVOnly -and $CreateExcelFromCSVOnly){

                Write-Host -ForegroundColor Red "Err... what?"
                Exit
            }

            if ($CreateCSVOnly -and (-not($CreateExcelFromCSVOnly))){

                $CreateCSVOnly = $true
            }
            else {

                $CreateCSVOnly = $false
            }

            if ($CreateExcelFromCSVOnly -and (-not($CreateCSVOnly))){

                Write-Host "`0"
                Write-Host "Since the ComputerNames parameter is mandatory. Directory Path should be the parent"
                Write-Host "folders of the ComputerName folder with CSVs in a subdirectory. Resulting in: "
                Write-Host "`0"
                Write-Host "`t<Directory Path>\<ComputerName>\<csvfiles>"
                Write-Host "`0"
                Write-Host -ForegroundColor DarkYellow "Example input: C:\tmp"
                Write-host "`0"
                $CreateExcelFromCSVPath = Read-Host "Directory Path"
            }
            else{

                $CreateExcelFromCSVPath = $false
            }
            # Script not designed to run against computer running the script
            foreach ($Com in $ComputerNames){
                
                # If computer name in list, re-write the array to exclude the computer name
                if($env:COMPUTERNAME -eq $Com){

                    Write-Host "`0"
                    if($PSVersionTable.PSVersion.Major -gt 5 ){
                    
                        Write-Host "Script cannot be run against itself. `u{1F641}"
                    }
                    else{
                    
                        $EmojiIcon = [System.Convert]::toInt32("1F641",16)
                        Write-Host "Script cannot be run against itself.$([System.Char]::ConvertFromUtf32($EmojiIcon))"
                    }
                    
                    Write-Host "`0"
                    $ComputerNames = $ComputerNames.Where({$PSItem -ne $env:COMPUTERNAME})
                }
                if ($ComputerNames.count -lt 1){

                    # Script was being run against just itself, so end the script
                    Exit
                }
            }

        #endregion

        #region INITIAL VARIABLE
        
            # Empty Strongly Typed Array
            [System.Collections.ArrayList]$NoConnectionComputer = @()
            [System.Collections.ArrayList]$BlockedJobs = @()
            [System.Collections.ArrayList]$ConnectedComputer = @()

            # For jobs
            $Symbol = "\", "|", "/", "-"
            $JobInt = 0

        #endregion
    }

    Process {
        foreach ($ComputerName in $ComputerNames){

            if (-not(Test-Path "\\$ComputerName\C$\Windows") -and $false -eq $CreateExcelFromCSVPath){
                
                # Append variable
                $NoConnectionComputer.Add($ComputerName) | Out-Null
            }
            else{

                # Append variable
                $ConnectedComputer.Add($ComputerName) | Out-Null
                
                # Start Job
                Start-Job -InformationAction SilentlyContinue -Name $computerName -ArgumentList $ComputerName,$LogDate,$LogExcelDirectory,$CreateCSVOnly,$CreateExcelFromCSVPath -ScriptBlock {

                    $ComputerName = $args[0]
                    $LogDate = $args[1]
                    $LogExcelDirectory = $args[2]
                    $CreateCSVOnly = $args[3]
                    $CreateExcelFromCSVPath = $args[4]
                    $LogExcelFile = "$LogDate-Audit-$ComputerName.xlsx"

                    if ($False -eq $CreateExcelFromCSVPath){

                        #region GATHER SYSTEM PROPERTIES
                
                            Invoke-Command -ComputerName $ComputerName -ScriptBlock {

                                #region VARIABLES AND LOGGING
                                    
                                    # Formate Date
                                    $LogDate = Get-Date -Format yyyy-MM-dd_hh-mm-ss

                                    $LogDirectory     = "C:\Logs\SystemAudit\$env:COMPUTERNAME"
                                    if(-not(Test-Path "$LogDirectory")){
                                    
                                        New-Item -Path $LogDirectory -ItemType Directory   
                                    }

                                    # Sheet 1 (System Overview)
                                    $LogFile1         = "$LogDate-sheet1a-$env:COMPUTERNAME.csv"
                                    # Values
                                    # A custom PSOjbect will be used and exported, after getting porperties
                                    # Set header for file
                                    Add-Content -Value $SOHeader -Path "$LogDirectory\$LogFile1"
                                    
                                    # Sheet 2 (Route Table)
                                    $LogFile2      = "$LogDate-sheet2_0-$env:COMPUTERNAME.csv"
                                    # No Header or values needed
                                    
                                    # Sheet 2_1 (Certificates)
                                    $LogFile2_1    = "$LogDate-sheet2_1-$env:COMPUTERNAME.csv"
                                    # No Header or values needed

                                    # Sheet 2_2 (SMB Shares)
                                    $LogFile2_2    = "$LogDate-sheet2_2-$env:COMPUTERNAME.csv"

                                    # Sheet 2_3 (Firewall Rules)
                                    $LogFile2_3    = "$LogDate-sheet2_3-$env:COMPUTERNAME.csv"

                                    # Sheet 2_3 (NetStat)
                                    $LogFile2_4    = "$LogDate-sheet2_4-$env:COMPUTERNAME.csv"

                                    # Sheet 3 (Running Services)
                                    $LogFile3      = "$LogDate-sheet3-$env:COMPUTERNAME.csv"
                                    # Values
                                    $RSHeader      = "ProcessId,Name,StartMode,State,Status,ExitCode"
                                    # Set header for file
                                    Add-Content -Value $RSHeader -Path "$LogDirectory\$LogFile3"
                                    
                                    # Sheet 4 (Scheduled Tasks)
                                    $LogFile4      = "$LogDate-sheet4-$env:COMPUTERNAME.csv"
                                    # Values
                                    $STHeader      = "Taskname,Status,Author,RunAsUser" 
                                    # Set header for file
                                    Add-Content -Value $STHeader -Path "$LogDirectory\$LogFile4"
                                    
                                    # Sheet 5 (Installed Software)
                                    $LogFile5      = "$LogDate-sheet5-$env:COMPUTERNAME.csv"
                                    # Values
                                    $ISHeader      = "Name,Version,Vendor,InstallDate,InstallSource,LocalPackage"
                                    # Set header for file
                                    Add-Content -Value $ISHeader -Path "$LogDirectory\$LogFile5"

                                    # Sheet 6 (Updates)
                                    $LogFile6      = "$LogDate-sheet6-$env:COMPUTERNAME.csv"
                                    # Values
                                    $UpHeader      = "Description,HotFixID,Caption,InstalledOn"
                                    # Set header for file
                                    Add-Content -Value $UpHeader -Path "$LogDirectory\$LogFile6"

                                    # Sheet 7 (Drivers)
                                    $LogFile7a     = "$LogDate-sheet7a-$env:COMPUTERNAME.csv"
                                    $LogFile7b     = "$LogDate-sheet7b-$env:COMPUTERNAME.csv"
                                    # Values
                                    $DrHeaderA     = "Description,Signer,IsSigned,DeviceId,DriverVersion,DriverDate"
                                    $DrHeaderB     = "Caption,Description,Manufacturer,PNPClass"
                                    # Set header for file
                                    Add-Content -Value $DrHeaderA -Path "$LogDirectory\$LogFile7a"
                                    Add-Content -Value $DrHeaderB -Path "$LogDirectory\$LogFile7b"

                                    # Sheet 8 (Windows Features)
                                    $LogFile8      = "$LogDate-sheet8-$env:COMPUTERNAME.csv"
                                    # Values
                                    $WFHeader      = "FeatureName,State"
                                    # Set header for file
                                    Add-Content -Value $WFHeader -Path "$LogDirectory\$LogFile8"

                                    # Sheet 9 (Events)
                                    $LogFile9a     = "$LogDate-sheet9a-$env:COMPUTERNAME.csv"
                                    $LogFile9b     = "$LogDate-sheet9b-$env:COMPUTERNAME.csv"
                                    $LogFile9c     = "$LogDate-sheet9c-$env:COMPUTERNAME.csv"
                                    $LogFile9d     = "$LogDate-sheet9d-$env:COMPUTERNAME.csv"
                                    # Values [Log in, Log off, PSSession, Reboot]
                                    $LoHeaderA     = "Time,Event,User"
                                    $LoHeaderB     = "Time,Event,User"
                                    $LoHeaderC     = "Time,Event,User"
                                    $LoHeaderD     = "Time,Id,Message"
                                    # Set header for file
                                    Add-Content -Value $LoHeaderA -Path "$LogDirectory\$LogFile9a"
                                    Add-Content -Value $LoHeaderB -Path "$LogDirectory\$LogFile9b"
                                    Add-Content -Value $LoHeaderC -Path "$LogDirectory\$LogFile9c"
                                    Add-Content -Value $LoHeaderD -Path "$LogDirectory\$LogFile9d"

                                    # Sheet 10 (Application Events)
                                    $LogFile10a    = "$LogDate-sheet10a-$env:COMPUTERNAME.csv"
                                    $LogFile10b    = "$LogDate-sheet10b-$env:COMPUTERNAME.csv"
                                    # Values
                                    $AEHeaderA     = "LevelDisplayName,Message,ProviderName,LogName,UserId,TimeCreated"
                                    $AEHeaderB     = "LevelDisplayName,Message,ProviderName,LogName,UserId,TimeCreated" 
                                    # Set header for file
                                    Add-Content -Value $AEHeaderA -Path "$LogDirectory\$LogFile10a"
                                    Add-Content -Value $AEHeaderB -Path "$LogDirectory\$LogFile10b"

                                    # Sheet 11 (System Events)
                                    $LogFile11a    = "$LogDate-sheet11a-$env:COMPUTERNAME.csv"
                                    $LogFile11b    = "$LogDate-sheet11b-$env:COMPUTERNAME.csv"
                                    # Values
                                    $SEHeaderA     = "LevelDisplayName,Message,ProviderName,LogName,UserId,TimeCreated"
                                    $SEHeaderB     = "LevelDisplayName,Message,ProviderName,LogName,UserId,TimeCreated" 
                                    # Set header for file
                                    Add-Content -Value $SEHeaderA -Path "$LogDirectory\$LogFile11a"
                                    Add-Content -Value $SEHeaderB -Path "$LogDirectory\$LogFile11b"

                                #endregion

                                #region LOCAL SPECIFICATIONS
                    
                                    Write-Output "Setting variables for System overview page"

                                    # Null out Array's for printing as string
                                    $ExportAdmins = $null

                                    # Determine PowerShell version for getting list of Administrators
                                    if($PSVersionTable.PSVersion.Major -lt 5){
                    
                                        # Get Administrators (Using older method in case of system with older Powershell Version)
                                        $GetAdmins = net localgroup administrators
                                        $Last = $GetAdmins.count - 3
                                        $ListAdmin = $GetAdmins[6..$last]
                                        foreach ($Admin in $ListAdmin){
                    
                                            $ExportAdmins += "$Admin; "
                                        }
                                        # Export to file
                                        Add-content
                                    }
                                    else{
                    
                                        # Get Administrator with latest cmdlet
                                        $ListAdmin = (Get-LocalGroupMember -Name Administrators -ErrorAction SilentlyContinue -ErrorVariable LAError).Name
                                        foreach ($Admin in $ListAdmin){
                    
                                            $ExportAdmins += "$Admin; "
                                        }

                                        if ($LAError){
                                
                                            # Get Administrators (Using older method in case the above weirdly fails)
                                            $GetAdmins = net localgroup administrators
                                            $Last = $GetAdmins.count - 3
                                            $ListAdmin = $GetAdmins[6..$last]
                                            foreach ($Admin in $ListAdmin){
                    
                                                $ExportAdmins += "$Admin; "
                                            }
                                        }
                                    }

                                    # Create Custom PowerShell Object for exporting and add property
                                    $SystemOverview = [PSCustomObject]@{ExportAdmin=$ExportAdmins}

                                    # Get Hardware properties
                                    $ComputerSystem = Get-CimInstance -ClassName CIM_ComputerSystem | Select-Object Domain, Manufacturer, Model, SystemFamily, UserName
                                    $SystemOverview | Add-Member -Name Domain -MemberType NoteProperty -Value $ComputerSystem.Domain
                                    $SystemOverview | Add-Member -Name Manufacturer -MemberType NoteProperty -Value $ComputerSystem.Manufacturer
                                    $SystemOverview | Add-Member -Name Model -MemberType NoteProperty -Value $ComputerSystem.Model
                                    $SystemOverview | Add-Member -Name SystemFamily -MemberType NoteProperty -Value $ComputerSystem.SystemFamily
                                    if ([string]::IsNullOrWhiteSpace($computerSystem.UserName)){

                                        $ListOfUsers = [System.Collections.ArrayList]::New()
                                        $QSession = cmd /c query Session
                                        foreach ($QS in $QSession){

                                            if($QS -match 'Active'){
                                                
                                                $Aid1 = $QS -replace ' ',''
                                                if ($Aid1 -match '>console'){

                                                    $Aid1 = $Aid1 -replace '>console',''
                                                }
                                                if($Aid1 -match '>rdp-tcp#'){

                                                    $Replace1 = $Aid1 -replace '(\>)',''
                                                    $Replace2 = $Replace1 -replace '(rdp-tcp#)',''
                                                    $Aid1 = $Replace2 -replace '^[(0-9)]',''
                                                }
                                                if($Aid1 -match 'rdp-tcp#'){

                                                    $Aid1 =$Aid1 -replace 'rdp-tcp#',''
                                                }
                                                else {
                                                    $Aid2 = ($Aid1 -split '(?=\d)',2)[0]
                                                    $ListOfUsers.Add($Aid2) | Out-Null
                                                }
                                            }

                                            if($QS -match 'Disc'){
                                                
                                                $Did1 = $QS -replace ' ',''
                                                if($Did1 -match 'services'){

                                                }
                                                else{
                                                    $Did2 = ($Did1 -split '(?=\d)',2)[0]
                                                    $ListOfUsers.Add($Did2) | Out-Null
                                                }
                                            }
                                        }
                                        foreach ($User in $ListOfUsers){

                                            $UserNames = $UserNames + "$User; "
                                        }
                                        if ([String]::IsNullOrWhiteSpace($UserNames)){

                                            $SystemOverview | Add-Member -Name Username -MemberType NoteProperty -Value 'N/A'
                                        }
                                        else{
                                        
                                            $SystemOverview | Add-Member -Name Username -MemberType NoteProperty -Value $UserNames
                                        }
                                    }
                                    else{
                                        $SystemOverview | Add-Member -Name Username -MemberType NoteProperty -Value $ComputerSystem.UserName
                                    }

                                    $ComputerChassis = Get-CimInstance -ClassName CIM_Chassis | Select-Object SerialNumber, SMBIOSAssetTag
                                    $SystemOverview | Add-Member -Name SerialNumber -MemberType NoteProperty -Value $ComputerChassis.SerialNumber
                                    $SystemOverview | Add-Member -Name AssetTag -MemberType NoteProperty -Value $ComputerChassis.SMBIOSAssetTag

                                    $ComputerBIOSVersion = (Get-CimInstance -ClassName CIM_BIOSElement).SMBIOSBIOSVersion
                                    $SystemOverview | Add-Member -Name BIOSVersion -MemberType NoteProperty -Value $ComputerBIOSVersion

                                    $ComputerProcessor = Get-CimInstance -ClassName Cim_Processor | Select-Object DeviceID, Name, AddressWidth, NumberOfCores, NumberOfLogicalProcessors
                                    
                                    foreach ($CP in $ComputerProcessor){
                                    
                                        $ComputerProcessorDeviceId += "$($CP.DeviceId); "
                                        $ComputerProcessorName += "$($CP.Name); "
                                        $ComputerProcessorAddressWidth += "$($CP.AddressWidth); "
                                        $ComputerProcessorNumberOfCores += "$($CP.NumberOfCores); "
                                        $ComputerProcessorNumberOfLogicalProcessors += "$($CP.NumberOfLogicalProcessors); "
                                    }

                                    $SystemOverview | Add-Member -Name CPUId -MemberType NoteProperty -Value $ComputerProcessorDeviceId
                                    $SystemOverview | Add-Member -Name CPUName -MemberType NoteProperty -Value $ComputerProcessorName
                                    $SystemOverview | Add-Member -Name CPUAddrWidth -MemberType NoteProperty -Value $ComputerProcessorAddressWidth
                                    $SystemOverview | Add-Member -Name CPUNumCore -MemberType NoteProperty -Value $ComputerProcessorNumberOfCores
                                    $SystemOverview | Add-Member -Name CPULogProc -MemberType NoteProperty -Value $ComputerProcessorNumberOfLogicalProcessors
                    
                                    $ComputerMemory = Get-CimInstance -ClassName CIM_PhysicalMemory | Select-Object Capacity, DeviceLocator, Manufacturer, PartNumber, Serialnumber, ConfiguredClockSpeed
                                    $SystemOverview | Add-Member -Name RAMCapacity -MemberType NoteProperty -Value "$([math]::round($ComputerMemory.Capacity[0] / 1GB)) GB"
                                    $SystemOverview | Add-Member -Name RAMDeviceLoc -MemberType NoteProperty -Value $ComputerMemory.DeviceLocator[0]
                                    $SystemOverview | Add-Member -Name RAMManuf -MemberType NoteProperty -Value $ComputerMemory.Manufacturer[0]
                                    $SystemOverview | Add-Member -Name RAMPartNum -MemberType NoteProperty -Value $ComputerMemory.PartNumber[0]
                                    $SystemOverview | Add-Member -Name RAMSerialNum -MemberType NoteProperty -Value $ComputerMemory.SerialNumber[0]
                                    $SystemOverview | Add-Member -Name RAMConfClock -MemberType NoteProperty -Value $ComputerMemory.ConfiguredClockSpeed[0]

                                    $ComputerHardDiskPnpIDs = (Get-CimInstance -ClassName CIM_DiskDrive).PNPDeviceID
                                    $HDPI = $null
                                    foreach ($HardDiskPnpId in $ComputerHardDiskPnpIDs){
                                    
                                        $HDPI += "$HardDiskPnpId; "
                                    }
                                    $SystemOverview | Add-Member -Name HardDiskPnpIDs -MemberType NoteProperty -Value $HDPI
                                    $ComputerHardDiskData = Get-CimInstance -ClassName CIM_LogicalDisk | Select-Object DeviceID, Name, FileSystem, FreeSpace, Size
                                    $ComputerHDRemaining = $null
                                    foreach ($HardDiskData in $ComputerHardDiskData){

                                        if ($HardDiskData.DeviceID -eq 'C:'){

                                            $SystemOverview | Add-Member -Name HDDeviceId -MemberType NoteProperty -Value $HardDiskData.DeviceID
                                            $SystemOverview | Add-Member -Name HDName -MemberType NoteProperty -Value $HardDiskData.Name
                                            $SystemOverview | Add-Member -Name HDFS -MemberType NoteProperty -Value $HardDiskData.FileSystem
                                            $SystemOverview | Add-Member -Name HDFreeSpace -MemberType NoteProperty -Value ("$([math]::round($HardDiskData.FreeSpace / 1GB)) GB")
                                            $SystemOverview | Add-Member -Name HDSize -MemberType NoteProperty -Value ("$([math]::round($HardDiskData.Size / 1GB)) GB")
                                        }
                                        else{
                                
                                            if([String]::IsNullOrWhiteSpace($HardDiskData.Name)){

                                                $ComputerHDRemaining += "Name: NoName Free Space: $([math]::round($HardDiskData.FreeSpace / 1GB)) GB; "
                                            }
                                            else{
                                            
                                                $ComputerHDRemaining += "Name: $($HardDiskData.Name) Free Space: $([math]::round($HardDiskData.FreeSpace / 1GB)) GB; "
                                            }
                                        }
                                    }
                                    $SystemOverview | Add-Member -Name HDRemaining -MemberType NoteProperty -Value $ComputerHDRemaining

                                    $DO = $null
                                    $ComputerDisplayOutputs = (Get-CimInstance -ClassName CIM_VideoController).Caption
                                    foreach ($DisplayOutput in $ComputerDisplayOutputs){
                                    
                                        $DO += "$DisplayOutput; "
                                    }
                                    $SystemOverview | Add-Member -Name DisplayOutputs -MemberType NoteProperty -Value $DO

                                    $ComputerOperatingSystem = Get-CimInstance -ClassName CIM_OperatingSystem | Select-Object Caption, InstallDate, LastBootUpTime, LocalDateTime, BuildNumber
                                    $SystemOverview | Add-Member -Name OSCaption -MemberType NoteProperty -Value $ComputerOperatingSystem.Caption
                                    $SystemOverview | Add-Member -Name OSInstallD -MemberType NoteProperty -Value $ComputerOperatingSystem.InstallDate

                                    $CurrentTimeZone = Get-TimeZone | Select-Object -ExpandProperty DisplayName
                                    $SystemOverview | Add-Member -Name OSTimeZone -MemberType NoteProperty -Value $CurrentTimeZone
                                    
                                    $SystemOverview | Add-Member -Name OSLastBoot -MemberType NoteProperty -Value $ComputerOperatingSystem.LastBootUpTime
                                    $SystemOverview | Add-Member -Name OSLocalTime -MemberType NoteProperty -Value $ComputerOperatingSystem.LocalDateTime
                                    $SystemOverview | Add-Member -Name OSBuildNum -MemberType NoteProperty -Value $ComputerOperatingSystem.BuildNumber

                                    If ($ComputerOperatingsystem.Caption -match "Microsoft Windows 10"){

                                        switch ($ComputerOperatingSystem.BuildNumber){
                            
                                            22621 {$ComputerOSVersion = "22H2"}
                                            19044 {$ComputerOSVersion = "21H2"}
                                            19043 {$ComputerOSVersion = "21H1"}
                                            19042 {$ComputerOSVersion = "20H2"}
                                            19041 {$ComputerOSVersion = 2004}
                                            18363 {$ComputerOSVersion = 1909}
                                            18362 {$ComputerOSVersion = 1903}
                                            17763 {$ComputerOSVersion = 1809}
                                            17134 {$ComputerOSVersion = 1803}
                                            16299 {$ComputerOSVersion = 1709}
                                            15063 {$ComputerOSVersion = 1703}
                                            14393 {$ComputerOSVersion = 1607}
                                            10586 {$ComputerOSVersion = 1511}
                                            10240 {$ComputerOSVersion = "RTM build"}
                                            Default {$ComputerOSVersion = "Version not listed"}
                                        }
                                    }

                                    if ($ComputerOperatingSystem.Caption -match "Microsoft Windows 11"){
                    
                                        switch($ComputerOperatingSystem.BuildNumber){
                            
                                            22000 {$ComputerOSVersion = "21H2"}
                                            22621 {$ComputerOSVersion = "22H2"}
                                        }
                                    }
                                    $SystemOverview | Add-Member -Name OsVersion -MemberType NoteProperty -Value $ComputerOSVersion

                                    $ComputerNetwork = Get-CimInstance Win32_NetworkAdapterConfiguration | Select-Object InterfaceIndex, Description, DHCPEnabled, DHCPServer, DNSDomainSuffixSearchOrder, IPAddress, IPConnectionMetric, DefaultIPGateway, IPSubnet, MACAddress
                                    foreach ($NetworkInterfaceCard in $ComputerNetwork){
                    
                                        if ($NetworkInterfaceCard.DefaultIPGateway){

                                            $SystemOverview | Add-Member -Name NICIntIndex -MemberType NoteProperty -Value $NetworkInterfaceCard.InterfaceIndex -ErrorAction SilentlyContinue
                                            $SystemOverview | Add-Member -Name NICDesc -MemberType NoteProperty -Value $NetworkInterfaceCard.Description -ErrorAction SilentlyContinue
                                            $SystemOverview | Add-Member -Name NICDHCPEnab -MemberType NoteProperty -Value $NetworkInterfaceCard.DHCPEnabled -ErrorAction SilentlyContinue
                                            $SystemOverview | Add-Member -Name NICDHCPServ -MemberType NoteProperty -Value $NetworkInterfaceCard.DHCPServer -ErrorAction SilentlyContinue
                                            $SuffixString = $null
                                            foreach ($suffix in $NetworkInterfaceCard.DNSDomainSuffixSearchOrder){
                                            
                                                $SuffixString += "$suffix; "
                                            }
                                            $SystemOverview | Add-Member -Name NICSuffix -MemberType NoteProperty -Value $SuffixString -ErrorAction SilentlyContinue
                                            $IPString = $null
                                            foreach ($IP in $NetworkInterfaceCard.IPAddress) {
                                            
                                                $IPString += "$IP; "
                                            }
                                            $SystemOverview | Add-Member -Name NICIP -MemberType NoteProperty -Value $IPString -ErrorAction SilentlyContinue
                                            $SubnetString = $null
                                            foreach ($Subnet in $NetworkInterfaceCard.IPSubnet){
                                            
                                                $SubnetString += "$Subnet; "
                                            }
                                            $SystemOverview | Add-Member -Name NICSubnet -MemberType NoteProperty -Value $SubnetString -ErrorAction SilentlyContinue
                                            $SystemOverview | Add-Member -Name NICMAC -MemberType NoteProperty -Value $NetworkInterfaceCard.MACAddress -ErrorAction SilentlyContinue
                                        }
                                    }
                                    #Additional IP's with gateways
                                    $NetworkCount = ($ComputerNetwork | Where-Object {$PSItem.DefaultIPGateway}).Count
                                    $NetworkAvailableDG = $ComputerNetwork | Where-Object {$PSItem.DefaultIPGateway}
                                    for($DGInt = 1;$DGInt -lt $NetworkCount; $DGInt++){
                                    
                                        $DGInt
                                        $AdditionalIPs += "$($NetworkAvailableDG[$DGInt].IPAddress[0]), "
                                    }
                                    $SystemOverview | Add-Member -Name NICAddIP -MemberType NoteProperty -Value $AdditionalIPs

                                    # Get Bit Locker Information
                                    try {
                            
                                        $GetBitlockerVolume = Get-BitLockerVolume
                                        foreach ($GBE in $GetBitlockerVolume){

                                            $BitlockerVolume               += "$($GBE.VolumeType), "
                                            $BitlockerMountPoint           += "$($GBE.MountPoint), "
                                            $BitlockerEncryptionPercentage += "$($GBE.EncryptionPercentage), "
                                            foreach($ProtectorType in $GBE.KeyProtector.KeyProtectorType){

                                                $BitlockerProtectorType    += "$ProtectorType,"
                                            }
                                            $BitlockerKeyProtector         += "$BitlockerProtectorType, "
                                            $BitlockerProtectionStatus     += "$($GBE.ProtectionStatus), "
                                        }
                                        
                                        $ComputerBitlocker = New-Object psobject @{
                                    
                                            VolumeType           = "$BitlockerVolume"
                                            MountPoint           = "$BitlockerMountPoint"
                                            EncryptionPercentage = "$BitlockerEncryptionPercentage"
                                            KeyProtector         = "$BitlockerKeyProtector"
                                            ProtectionStatus     = "$BitlockerProtectionStatus"
                                        }
                                    }
                                    catch {

                                        if (Test-Path "C:\Windows\System32\manage-bde.exe"){
                            
                                            $InitialComputerBitlocker = manage-bde -status
                                            $BLEnd = $InitialComputerBitlocker.count
                                            $BLInteger = 0
                                            foreach ($BLitem in $InitialComputerBitlocker){
                                    
                                                if($BLitem -match 'Volume]'){
                                        
                                                    $BitlockerVolumeName += "$(($BLitem.split('[')[1]).Replace("]",'')), "
                                                }
                                                if($BLitem -match "\[\]"){
                                        
                                                    $BitlockerMountPoint += "$($BLitem.split(':')[0]), "
                                                }
                                                if($BLitem -match 'Percentage Encrypted'){
                                        
                                                    $BitlockerPercentage += "$(($BLitem.split(':')[1]).Replace(" ",'')), "
                                                }
                                                if ($BLitem -match 'Protection Status'){
                                        
                                                    $BitlockerProtectionStatus += "$(($BLitem.split(':')[1]).Replace(" ",'')), "
                                                }
                                                if ($BLitem -match 'Key Protectors'){
                                        
                                                    $BLBegin = $BLInteger + 1
                                                }
                                                    $BLInteger++
                                            }

                                            $SplitKeyProtector += $InitialComputerBitlocker[$BLBegin..($BLEnd-2)]
                                            foreach ($BLKP in $SplitKeyProtector){
                                    
                                                $BitlockerKeyProtector += "$(($BLKP).replace(" ",'')), "
                                            }

                                            $ComputerBitlocker = New-Object psobject @{
                                    
                                                VolumeType           = "$BitlockerVolumeName"
                                                MountPoint           = "$BitlockerMountPoint"
                                                EncryptionPercentage = "$BitlockerPercentage"
                                                KeyProtector         = "$BitlockerKeyProtector"
                                                ProtectionStatus     = "$BitlockerProtectionStatus"
                                            }
                                        }
                                    }
                                    
                                    $SystemOverview | Add-Member -Name BitlockerVolType -MemberType NoteProperty -Value $ComputerBitlocker.VolumeType
                                    $SystemOverview | Add-Member -Name BitlockerMntPoint -MemberType NoteProperty -Value $ComputerBitlocker.MountPoint
                                    $SystemOverview | Add-Member -Name BitlockerEncyrptPerc -MemberType NoteProperty -Value $ComputerBitlocker.EncyptionPercentage
                                    $SystemOverview | Add-Member -Name BitlockerKeyProtec -MemberType NoteProperty -Value $ComputerBitlocker.KeyProtector
                                    $SystemOverview | Add-Member -Name BitlockerProtecStatus -MemberType NoteProperty -Value $ComputerBitlocker.ProtectionStatus

                                    # Check if Guest User Account is Enabled
                                    if (Get-LocalUser){
                            
                                        $ComputerGuestAccount = (Get-LocalUser -Name Guest).Enabled
                                    }
                                    else{
                            
                                        $ComputerGA = net user Guest
                                        foreach ($CGA in $ComputerGA){
                                
                                            if ($CGA -match "Account active"){
                                    
                                                $ComputerGuestAccount = ($CGA.split("active")[1]).Replace(" ",'')
                                            }
                                        }
                                    }
                                    $SystemOverview | Add-Member -Name GuestAccount -MemberType NoteProperty -Value $ComputerGuestAccount

                                    # Get Power Profile
                                    $GetPowerProfile = powercfg /list
                                    foreach ($GetPP in $GetPowerProfile){
                        
                                        if($GetPP -match '\*'){
                            
                                            $ComputerPowerProfile = $GetPP
                                        }
                                    }
                                    $SystemOverview | Add-Member -Name PowerProfile -MemberType NoteProperty -Value $ComputerPowerProfile

                                    # Get VPN information
                                    $VPNConnection =  Get-VpnConnection | Select-Object ConnectionStatus, DNSSuffix, Name, ServerAddress, SplitTunneling, ServerList
                                    foreach ($VPNC in $VPNConnection.Serverlist){
                                    
                                        $VPNServerAddresses = $VPNServerAddresses + "$($VPNC.ServerAddress); "
                                    }
                                    # Add members to $SystemOverview
                                    $SystemOverview | Add-Member -Name VPNConStat -MemberType NoteProperty -Value $VPNConnection.ConnectionStatus
                                    $SystemOverview | Add-Member -Name VPNDNSSuffix -MemberType NoteProperty -Value $VPNConnection.DNSSuffix
                                    $SystemOverview | Add-Member -Name VPNName -MemberType NoteProperty -Value $VPNConnection.Name
                                    $SystemOverview | Add-Member -Name VPNSvrAdd -MemberType NoteProperty -Value $VPNConnection.ServerAddress
                                    $SystemOverview | Add-Member -Name VPNTunnel -MemberType NoteProperty -Value $VPNConnection.SplitTunneling
                                    $SystemOverview | Add-Member -Name VPNSvrAdds -MemberType NoteProperty -Value $VPNServerAddresses

                                    # Get Time information
                                    Write-Output "Getting Time Information"
                                    $TheTimes = cmd /c "w32tm /query /status"
                                    foreach($TimeLine in $TheTimes){

                                        if($TimeLine -match 'ReferenceId:'){

                                            $SystemOverview | Add-Member -Name TimeRefId -MemberType NoteProperty -Value ($TimeLine.Split(':',2)[1])
                                            
                                        }
                                        if($TimeLine -match 'Last Successful Sync Time:'){

                                            $SystemOverview | Add-Member -Name TimeSync -MemberType NoteProperty -Value ($TimeLine.Split(':',2)[1])
                                            
                                        }
                                        if($TimeLine -match 'Source:'){

                                            $SystemOverview | Add-Member -Name TimeSource -MemberType NoteProperty -Value ($TimeLine.Split(":")[1])
                                        }
                                    }

                                #endregion

                                #region REMOTE ACCESS STATUS

                                    # Silence the progress bar from displaying on terminal
                                    $ProgressPreference = 'SilentlyContinue'

                                    Write-Output "Checking Remote Access"
                                    # Test RDP Port
                                    $ComputerRDP = (Test-NetConnection -Port 3389 -ComputerName $env:COMPUTERNAME -WarningAction SilentlyContinue).TcpTestSucceeded

                                    # Test WinRM Port
                                    $ComputerWinRM = (Test-NetConnection -Port 5985 -ComputerName $env:COMPUTERNAME -WarningAction SilentlyContinue).TcpTestSucceeded

                                    # Test SSH Port
                                    $ComputerSSH = (Test-NetConnection -Port 22 -ComputerName $env:COMPUTERNAME -WarningAction SilentlyContinue).TcpTestSucceeded

                                    $SystemOverview | Add-Member -Name RDP -Type NoteProperty -Value $ComputerRDP
                                    $SystemOverview | Add-Member -Name WinRM -Type NoteProperty -Value $ComputerWinRM
                                    $SystemOverview | Add-Member -Name SSH -Type NoteProperty -Value $ComputerSSH

                                #endregion

                                #region PRINT SYSTEM OVERVIEW (SHEET1)
                                
                                    $SystemOverview | Export-Csv -Path "$LogDirectory\$LogFile1" -NoTypeInformation

                                #endregion

                                #region ROUTE TABLE

                                    Write-Output "Getting Route Table"
                                    $ComputerRoutePrint = cmd /c "route print"
                                    foreach ($RPLine in $ComputerRoutePrint) {
                                    
                                        Add-Content -Value $RPLine -Path "$LogDirectory\$LogFile2"
                                    }

                                #endregion

                                #region CERTIFICATES

                                    Write-Output "Getting Certificate Data"
                                    Get-ChildItem 'Cert:\LocalMachine\Root' | Export-Csv -Path "$LogDirectory\$LogFile2_1" -NoTypeInformation

                                #endregion

                                #region SMB SHARES

                                    Write-Output "Getting SMB Share Data"
                                    $SMBShares = Get-SmbShare
                                    # Export header to CSV
                                    Add-Content -Value "Name,Path,Description,ScopeName,AccountName,AccessControlType,AccessRight" -Path "$LogDirectory\$LogFile2_2"
                                    foreach ($Share in $SMBShares){
                                    
                                        # Export share to CSV
                                        Add-Content -Value "$($Share.Name),$($Share.Path),$($Share.Description),$($Share.ScopeName)" -Path "$LogDirectory\$LogFile2_2"
                                        # Export share permissions to CSV
                                        $ShareAccess = Get-SmbShareAccess -Name $Share.Name
                                        foreach ($ShareAC in $ShareAccess){
                                        
                                            Add-Content -Value ",,,,$($ShareAC.AccountName),$($ShareAC.AccessControlType),$($ShareAC.AccessRight)" -Path "$LogDirectory\$LogFile2_2"
                                        }
                                    }

                                #endregion

                                #region FIREWALL RULES

                                    Write-Output "Getting Firewall Rules"
                                    Get-NetFirewallRule | Export-Csv -Path "$LogDirectory\$LogFile2_3" -NoTypeInformation

                                #endregion

                                #region ACTIVE CONNECTIONS (NetStat)

                                    Write-Output "Getting Active Connections"
                                    $NetStat = cmd /c "netstat -ab"
                                    foreach ($NSLine in $NetStat){
                                    
                                        Add-Content -Value $NSLine -Path "$LogDirectory\$LogFile2_4"
                                    }

                                #endregion

                                #region RUNNING SERVICES

                                    Write-Output "Getting Running Services"
                                    $ComputerRunningServices = Get-CimInstance Win32_Service
                                    $ComputerRunningServices | Export-Csv -Path "$LogDirectory\$LogFile3" -NoTypeInformation
                                    
                                #endregion

                                #region SCHEDULED TASKS
                        
                                    Write-Output "Getting Scheduled Tasks"
                                    $ComputerScheduledTasks = schtasks /query /V /FO CSV | ConvertFrom-Csv | Select-Object TaskName, Status, Author, 'Run As User'
                                    $ComputerScheduledTasks | Export-Csv -Path "$LogDirectory\$LogFile4" -NoTypeInformation

                                #endregion

                                #region INSTALLED SOFTWARE
                    
                                    Write-Output "Getting Installed Software"
                                    $ComputerInstalledSoftware = Get-CimInstance Win32_Product | Select-Object Name, Version, Vendor, InstallDate, InstallSource, LocalPackage
                                    $ComputerInstalledSoftware | Export-Csv -Path "$LogDirectory\$LogFile5" -NoTypeInformation

                                #endregion

                                #region OPERATING SYSTEM UPDATES
                    
                                    Write-Output "Getting Operating System Updates"
                                    $ComputerUpdates = Get-CimInstance Win32_QuickFixEngineering | Select-Object Description, HotFixID, Caption, InstalledOn | Sort-Object InstalledOn -Descending
                                    $ComputerUpdates | Export-Csv -Path "$LogDirectory\$LogFile6" -NoTypeInformation

                                #endregion

                                #region DRIVERS

                                    Write-Output "Getting all Drivers"
                                    $ComputerSignedDrivers = Get-CimInstance Win32_PnPSignedDriver | Select-Object Description, Signer, IsSigned, DeviceID, DriverVersion, DriverDate
                                    $ComputerPNPDrivers = Get-CimInstance Win32_PnPEntity | Select-Object Caption, Description, Manufacturer, PNPClass
                                    $ComputerSignedDrivers | Export-Csv -Path "$LogDirectory\$LogFile7a" -NoTypeInformation
                                    $ComputerPNPDrivers | Export-Csv -Path "$LogDirectory\$LogFile7b" -NoTypeInformation
                    
                                #endregion

                                #region WINDOWS FEATURES

                                    Write-Output "Getting Windows Features"
                                    If ($ComputerOSCaption -notmatch 'Server'){

                                        try{

                                            $ComputerFeatures = Get-WindowsoptionalFeature -Online
                                        }
                                        catch {
                            
                                            # Can only be used as local administrator
                                            $ComputerFeatures = @()
                                            $ComputerFeaturesDISM = dism /online /get-features
                                            foreach($FeatureString in $ComputerFeaturesDISM){
                                
                                                if ($FeatureString -match "Feature"){
                                    
                                                    $FeatureLine = $FeatureString
                                                    $Feature = $FeatureLine.split(":")[1]
                                                }
                                                if ($FeatureString -match "State"){
                                    
                                                    $StateLine = "$FeatureString"
                                                    $State = $StateLine.Split(":")[1]
                                                }
                                                if ($Feature -and $State){
                                            
                                                    $ComputerFeaturesObject = New-Object -MemberType PSObject -Property @{
                                            
                                                        'FeatureName' = "$Feature"
                                                        'State' = "$State"
                                                    }
                                                    $ComputerFeatures += $ComputerFeaturesObject

                                                    $Feature = $null
                                                    $State = $null
                                                }
                                            }
                                        }
                                        
                                        #Print
                                        $ComputerFeatures | Export-Csv -Path "$LogDirectory\$LogFile8" -NoTypeInformation
                                    }
                                    if ($ComputerOSCaption -match 'Server'){

                                        if (Get-WindowsFeature){

                                            $ComputerFeatures = Get-WindowsFeature | Select-Object @{N='FeatureName';E={$PSItem.Name}},@{N='State';E={$_.InstallState}}
                                        }
                                        else{
                            
                                            # Can only be used as local administrator
                                            $ComputerFeatures = @()
                                            $ComputerFeaturesDISM = dism /online /get-features
                                            foreach($FeatureString in $ComputerFeaturesDISM){
                                
                                                if ($FeatureString -match "Feature"){
                                    
                                                    $FeatureLine = $FeatureString
                                                    $Feature = $FeatureLine.split(":")[1]
                                                }
                                                if ($FeatureString -match "State"){
                                    
                                                    $StateLine = "$FeatureString"
                                                    $State = $StateLine.Split(":")[1]
                                                }
                                                if ($Feature -and $State){
                                            
                                                    $ComputerFeaturesObject = New-Object -MemberType PSObject -Property @{
                                            
                                                        'FeatureName' = "$Feature"
                                                        'State' = "$State"
                                                    }
                                                    $ComputerFeatures += $ComputerFeaturesObject

                                                    $Feature = $null
                                                    $State = $null
                                                }
                                            }
                                        }
                                        
                                        #Print
                                        $ComputerFeatures | Export-Csv -Path "$LogDirectory\$LogFile8" -NoTypeInformation
                                    }

                                #endregion

                                #region EVENTS
                    
                                    Write-Output "Getting Event Logs"
                                    # Get Logon Events
                                    $LoginoutEvents = Get-EventLog system -source Microsoft-Windows-Winlogon
                                    $ComputerLoginEvents = @()
                                    $ComputerLogoffEvents = @()
                                    ForEach ($Log in $LoginoutEvents) {

                                        if($Log.InstanceId -eq 7001){
                                
                                            $ComputerLoginEvents += New-Object PSObject -Property @{
                            
                                                Time = $log.TimeWritten
                                                "Event" = 'Logon'
                                                User = "'" + (New-Object System.Security.Principal.SecurityIdentifier $Log.ReplacementStrings[1]).Translate([System.Security.Principal.NTAccount]) + "'"
                                            }
                                        }
                                        if($Log.InstanceId -eq 7002){

                                            $computerLogoffEvents += New-Object PSObject -Property @{

                                                Time = $Log.TimeWritten
                                                "Event" = 'Logoff'
                                                User = "'" + (New-Object System.Security.Principal.SecurityIdentifier $Log.ReplacementStrings[1]).Translate([System.Security.Principal.NTAccount]) + "'"
                                            }
                                        }
                                    }

                                    #Print
                                    $ComputerLoginEvents | Export-Csv -Path "$LogDirectory\$LogFile9a" -NoTypeInformation
                                    $ComputerLogoffEvents | Export-Csv -Path "$LogDirectory\$LogFile9b" -NoTypeInformation

                                    # Get PSSession Events
                                    $PSSessionEvents = Get-WinEVent Microsoft-Windows-PowerShell/Operational
                                    $ComputerPSSessionEvents = @()
                                    foreach ($PSEvent in $PSSessionEvents){

                                        if ($PSEvent.Id -match 53504){

                                            $UserId = $PSEvent.UserId
                                            $objSID = New-Object System.Security.Principal.SecurityIdentifier($UserId) -ErrorAction SilentlyContinue
                                            $UserName = $objSID.Translate([System.Security.Principal.NTAccount])

                                            $ComputerPSSessionEvents += New-Object PSObject -Property @{
                                
                                                Time = $PSEvent.TimeCreated
                                                "Event" = 'PSSession'
                                                User = "'$UserName'"
                                            }
                                        }
                                    }

                                    #Print
                                    $ComputerPSSessionEvents | Export-Csv -Path "$LogDirectory\$LogFile9c" -NoTypeInformation

                                    # Get System Reboot Events
                                    $ComputerRestartEvents = Get-WinEvent -FilterHashtable @{LogName='System';id=1074}
                                    #Print
                                    $ComputerRestartEvents | Export-Csv -Path "$LogDirectory\$LogFile9d" -NoTypeInformation

                                    # Get All Error
                                    $ComputerErrorAppEvent = Get-WinEvent Application -ErrorAction SilentlyContinue | Where-Object {$PSItem.LevelDisplayName -eq 'Error' -and $PSItem.Id -ge 1000} | Select-Object LevelDisplayName, Message, ProviderName, LogName, UserId, TimeCreated
                                    $ComputerErrorSysEvent = Get-WinEvent System | Where-Object {$PSItem.LevelDisplayName -eq 'Error'} | Select-Object LevelDisplayName, Message, ProviderName, LogName, UserId, TimeCreated
                                    # Print
                                    $ComputerErrorAppEvent | Export-Csv "$LogDirectory\$LogFile10a" -NoTypeInformation
                                    $ComputerErrorSysEvent | Export-Csv "$LogDirectory\$LogFile11a" -NoTypeInformation


                                    # Get all Warnings
                                    $ComputerWarnAppEvent = Get-WinEvent Application -ErrorAction SilentlyContinue | Where-Object {$PSItem.LevelDisplayName -eq 'Warning' -and $PSItem.Id -ge 1000} | Select-Object LevelDisplayName, Message, ProviderName, LogName, UserId, TimeCreated
                                    $ComputerWarnSysEvent = Get-WinEvent System | Where-Object {$PSItem.LevelDisplayName -eq 'Warning'} | Select-Object LevelDisplayName, Message, ProviderName, LogName, UserId, TimeCreated
                                    # Print
                                    $ComputerWarnAppEvent | Export-Csv "$LogDirectory\$LogFile10b" -NoTypeInformation
                                    $ComputerWarnSysEvent | Export-Csv "$LogDirectory\$LogFile11b" -NoTypeInformation

                                #endregion
                            }

                        #endregion
                    }

                    #region GATHER CSV's AND CREATE VARIABLES FOR EXCEL

                        # Create directory for temp storage
                        if($false -eq $CreateExcelFromCSVPath){
                            
                            $TemporaryDirectoryPath = "C:\TMP"
                            if(-not(Test-Path $TemporaryDirectoryPath)){
                        
                                New-Item -Path $TemporaryDirectoryPath -ItemType Directory
                            }
                            # Copy files
                            Copy-Item -Path "\\$ComputerName\C$\Logs\SystemAudit\$ComputerName\" -Destination $TemporaryDirectoryPath -Force -Recurse
                            if ($CreateCSVOnly){
                                
                                # Since only the CSV is needed. End the job.
                                Exit
                            }
                        }
                        else{

                            $TemporaryDirectoryPath = $CreateExcelFromCSVPath
                        }

                    #endregion

                    #region CREATE VARIABLES FOR EXCEL

                        # Get a list of files in temp folder and populate variable for printing
                        $ListOfCSvs = Get-ChildItem "$TemporaryDirectoryPath\$ComputerName"
                        foreach ($Csv in $ListOfCSvs) {

                            # Files to variable
                            if ($CSV.Name -match 'Sheet1a'){$ComputerOVProperties     = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet2_0'){$ComputerRoutePrint        = Get-Content $Csv.FullName}
                            if ($CSV.Name -match 'Sheet2_1'){$ComputerCertificates    = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet2_2'){$ComputerSMBShares       = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet2_3'){$ComputerFirewallRules   = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet2_4'){$ComputerNetStat         = Get-Content $Csv.FullName}
                            if ($CSV.Name -match 'Sheet3'){$ComputerRunningServices   = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet4'){$ComputerScheduledTasks    = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet5'){$ComputerInstalledSoftware = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet6'){$ComputerUpdates           = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet7a'){$ComputerSignedDrivers    = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet7b'){$ComputerPNPDrivers       = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet8'){$ComputerFeatures          = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet9a'){$ComputerLoginEvents      = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet9b'){$ComputerLogoffEvents     = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet9c'){$ComputerPSSessionEvents  = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet9d'){$ComputerRestartEvents    = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet10b'){$ComputerWarnAppEvent    = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet10a'){$ComputerErrorAppEvent   = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet11b'){$ComputerWarnSysEvent    = Import-Csv $Csv.FullName}
                            if ($CSV.Name -match 'Sheet11a'){$ComputerErrorSysEvent   = Import-Csv $Csv.FullName}
                        }
                    #endregion

                    #region [SHEET 1] CREAT EXCEL AND PRINT COMPUTER DATA PROPERTIES
            
                        Write-Output "Print to Sheet 1"

                        # Launch New Instance of Excel
                        $Excel = New-Object -Com Excel.Application

                        # Make Excel Visible
                        $Excel.visible = $False

                        # Create a New Workbook
                        $workbook = $Excel.Workbooks.Add()

                        # Declarate Excel Sheets as $Sheet for script (Example this is sheet 1)
                        $Sheet1 = $workbook.WorkSheets.Item(1)

                        # Name of WorkSheet - For bottom Tab
                        $Excel.Worksheets.Item(1).Name = "$ComputerName System Overview"

                        # Declare all Static Cells and Information (Row, Column)
                        $Sheet1.Cells.Item(1,1) = "$($ComputerName.ToUpper())"
                        $Sheet1.Cells.Item(2,2) = "Administrators"
                        $Sheet1.Cells.Item(3,2) = "Guest Enabled"
                        $Sheet1.Cells.Item(6,2) = "Operating System"
                        $Sheet1.Cells.Item(7,2) = "Domain"
                        $Sheet1.Cells.Item(8,2) = "User Name"
                        $Sheet1.cells.item(9,2) = "Caption"
                        $Sheet1.cells.item(10,2) = "Install Date"
                        $Sheet1.cells.item(11,2) = "Time Zone"
                        $Sheet1.Cells.Item(12,2) = "Last Boot Time"
                        $Sheet1.cells.item(13,2) = "Local Date Time"
                        $Sheet1.cells.item(14,2) = "Build Number"
                        $Sheet1.cells.item(15,2) = "OS Version"
                        $Sheet1.Cells.Item(17,2) = "Hardware"
                        $Sheet1.Cells.Item(18,2) = "Manufacturer"
                        $Sheet1.cells.item(19,2) = "Model"
                        $Sheet1.cells.item(20,2) = "System Family"
                        $Sheet1.cells.item(21,2) = "Serial Number"
                        $Sheet1.Cells.Item(22,2) = "AssetTag"
                        $Sheet1.Cells.Item(23,2) = "BIOS Version"
                        $Sheet1.Cells.Item(24,2) = "Display Outputs"
                        $Sheet1.cells.item(2,5) = "Power Profile"
                        $Sheet1.cells.item(3,5) = "Profile"
                        $Sheet1.cells.item(6,5) = "Network (with DefaultGateway)"
                        $Sheet1.cells.item(7,5) = "Interface Index"
                        $Sheet1.Cells.Item(8,5) = "Description"
                        $Sheet1.cells.item(9,5) = "DHCP"
                        $Sheet1.cells.item(10,5) = "DHCP Server"
                        $Sheet1.cells.item(11,5) = "DNS Suffix"
                        $Sheet1.cells.item(12,5) = "IP Address"
                        $Sheet1.cells.item(13,5) = "IP Subnet Mask"
                        $Sheet1.cells.item(14,5) = "MAC Address"
                        $Sheet1.cells.item(15,5) = "Additional IPs"
                        $Sheet1.cells.item(17,5) = "Processor(s)"
                        $Sheet1.cells.item(18,5) = "CPU ID"
                        $Sheet1.cells.item(19,5) = "CPU Name"
                        $Sheet1.cells.item(20,5) = "CPU Width"
                        $Sheet1.cells.item(21,5) = "CPU Cores"
                        $Sheet1.cells.item(22,5) = "CPU Logic Proc"
                        $Sheet1.cells.item(6,8) = "(Single) Memory Module"
                        $Sheet1.cells.item(7,8) = "Capacity"
                        $Sheet1.cells.item(8,8) = "Device Locator"
                        $Sheet1.cells.item(9,8) = "Manufacturer"
                        $Sheet1.cells.item(10,8) = "Part Number"
                        $Sheet1.cells.item(11,8) = "Serial Number"
                        $Sheet1.cells.item(12,8) = "Configured Clock Speed"
                        $Sheet1.cells.item(17,8) = "Disk(s)"
                        $Sheet1.cells.item(18,8) = "Device ID"
                        $Sheet1.cells.item(19,8) = "Name"
                        $Sheet1.cells.item(20,8) = "File System"
                        $Sheet1.cells.item(21,8) = "Free Space"
                        $Sheet1.cells.item(22,8) = "Size"
                        $Sheet1.cells.item(23,8) = "PNP IDs"
                        $Sheet1.Cells.item(24,8) = "Remaining Disks"
                        $Sheet1.cells.item(6,11) = "BitLocker"
                        $Sheet1.cells.item(7,11) = "Volume Type"
                        $Sheet1.cells.item(8,11) = "Mount Point"
                        $Sheet1.cells.item(9,11) = "Encrypted Percentage"
                        $Sheet1.cells.item(10,11) = "Key Protector"
                        $Sheet1.cells.item(11,11) = "Protection Status"
                        $Sheet1.cells.item(17,11) = "Firewall"
                        $Sheet1.cells.item(18,11) = "RDP Access"
                        $Sheet1.cells.item(19,11) = "WinRM Access"
                        $Sheet1.cells.item(20,11) = "SSH Access"
                        $Sheet1.cells.item(26,2) = "VPN"
                        $Sheet1.cells.item(27,2) = "VPN Connection Status"
                        $Sheet1.cells.item(28,2) = "VPN DNS Suffix"
                        $Sheet1.cells.item(29,2) = "VPN Name"
                        $Sheet1.cells.item(30,2) = "VPN Server Address"
                        $Sheet1.cells.item(31,2) = "VPN Split Tunnel"
                        $Sheet1.cells.item(32,2) = "VPN Server Addresses"
                        $Sheet1.cells.item(26,5) = "Time"
                        $Sheet1.cells.item(27,5) = "Time Reference ID"
                        $Sheet1.cells.item(28,5) = "Last Sync"
                        $Sheet1.cells.item(29,5) = "Time Source"
            
                    #endregion

                    #region [SHEET 1] SYSTEM OVERVIEW VARIABLE PRINTING AND STYLE TABLE

                        # Declared cells for $value input 
                        #$Sheet1.Cells.Item(1,1) = "$ComputerName"
                        $Sheet1.Cells.Item(2,3) = "$($ComputerOVProperties.ExportAdmins)"
                        $Sheet1.Cells.Item(3,3) = "$($ComputerOVProperties.GuestAccount)"
                        #$Sheet1.Cells.Item(6,2) = "Operating System"
                        $Sheet1.Cells.Item(7,3) = "$($ComputerOVProperties.Domain)"
                        $Sheet1.Cells.Item(8,3) = "$($ComputerOVProperties.Username)"
                        $Sheet1.cells.item(9,3) = "$($ComputerOVProperties.OSCaption)"
                        $Sheet1.cells.item(10,3) = "$($ComputerOVProperties.OSInstallD)"
                        $Sheet1.cells.item(11,3) = "$($ComputerOVProperties.OSTimeZone)"
                        $Sheet1.Cells.Item(12,3) = "$($ComputerOVProperties.OSLastBoot)"
                        $Sheet1.cells.item(13,3) = "$($ComputerOVProperties.OSLocalTime)"
                        $Sheet1.cells.item(14,3) = "$($ComputerOVProperties.OSBuildNum)"
                        $Sheet1.cells.item(15,3) = "$($ComputerOVProperties.OSVersion)"
                        #$Sheet1.Cells.Item(17,2) = "Hardware"
                        $Sheet1.Cells.Item(18,3) = "$($ComputerOVProperties.Manufacturer)"
                        $Sheet1.cells.item(19,3) = "$($ComputerOVProperties.Model)"
                        $Sheet1.cells.item(20,3) = "$($ComputerOVProperties.SystemFamily)"
                        $Sheet1.cells.item(21,3) = "$($ComputerOVProperties.SerialNumber)"
                        $Sheet1.Cells.Item(22,3) = "$($ComputerOVProperties.AssetTag)"
                        $Sheet1.Cells.Item(23,3) = "$($ComputerOVProperties.BIOSVersion)"
                        $Sheet1.Cells.Item(24,3) = "$($ComputerOVProperties.DisplayOutputs)"
                        #$Sheet1.cells.item(2,5) = "Power Profile"
                        $Sheet1.cells.item(3,6) = "$($ComputerOVProperties.PowerProfile)"
                        #$Sheet1.cells.item(6,5) = "Network (Online)"
                        $Sheet1.cells.item(7,6) = "$($ComputerOVProperties.NICIntIndex)"
                        $Sheet1.Cells.Item(8,6) = "$($ComputerOVProperties.NICDesc)"
                        $Sheet1.cells.item(9,6) = "$($ComputerOVProperties.NICDHCPEnab)"
                        $Sheet1.cells.item(10,6) = "$($ComputerOVProperties.NICDHCPServ)"
                        $Sheet1.cells.item(11,6) = "$($ComputerOVProperties.NICSuffix)"
                        $Sheet1.cells.item(12,6) = "$($ComputerOVProperties.NICIP)"
                        $Sheet1.cells.item(13,6) = "$($ComputerOVProperties.NICSubnet)"
                        $Sheet1.cells.item(14,6) = "$($ComputerOVProperties.NICMAC)"
                        $Sheet1.cells.item(15,6) = "$($ComputerOVProperties.NICAddIP)"
                        #$Sheet1.cells.item(17,5) = "Processor"
                        $Sheet1.cells.item(18,6) = "$($ComputerOVProperties.CPUId)"
                        $Sheet1.cells.item(19,6) = "$($ComputerOVProperties.CPUName)"
                        $Sheet1.cells.item(20,6) = "$($ComputerOVProperties.CPUAddrWidth)"
                        $Sheet1.cells.item(21,6) = "$($ComputerOVProperties.CPUNumCore)"
                        $Sheet1.cells.item(22,6) = "$($ComputerOVProperties.CPULogProc)"
                        #$Sheet1.cells.item(6,8) = "Memory"
                        $Sheet1.cells.item(7,9) = "$($ComputerOVProperties.RAMCapacity)"
                        $Sheet1.cells.item(8,9) = "$($ComputerOVProperties.RAMDeviceLoc)"
                        $Sheet1.cells.item(9,9) = "$($ComputerOVProperties.RAMManuf)"
                        $Sheet1.cells.item(10,9) = "$($ComputerOVProperties.RAMPartNum)"
                        $Sheet1.cells.item(11,9) = "$($ComputerOVProperties.RAMSerialNum)"
                        $Sheet1.cells.item(12,9) = "$($ComputerOVProperties.RAMConfClock)"
                        #$Sheet1.cells.item(17,8) = "Disk(s)"
                        $Sheet1.cells.item(18,9) = "$($ComputerOVProperties.HDDeviceID)"
                        $Sheet1.cells.item(19,9) = "$($ComputerOVProperties.HDName)"
                        $Sheet1.cells.item(20,9) = "$($ComputerOVProperties.HDFS)"
                        $Sheet1.cells.item(21,9) = "$($ComputerOVProperties.HDFreeSpace)"
                        $Sheet1.cells.item(22,9) = "$($ComputerOVProperties.HDSize)"
                        $Sheet1.cells.item(23,9) = "$($ComputerOVProperties.HardDiskPnpIDs)"
                        $Sheet1.cells.item(24,9) = "$($ComputerOVProperties.HDRemaining)"
                        #$Sheet1.cells.item(6,11) = "BitLocker"
                        $Sheet1.cells.item(7,12) = "$($ComputerOVProperties.VolType)"
                        $Sheet1.cells.item(8,12) = "$($ComputerOVProperties.MntPoint)"
                        $Sheet1.cells.item(9,12) = "$($ComputerOVProperties.EncryptPerc)"
                        $Sheet1.cells.item(10,12) = "$($ComputerOVProperties.KeyProtec)"
                        $Sheet1.cells.item(11,12) = "$($ComputerOVProperties.ProtecStatus)"
                        #$Sheet1.cells.item(17,11) = "Firewall"
                        $Sheet1.cells.item(18,12) = "$($ComputerOVProperties.RDP)"
                        $Sheet1.cells.item(19,12) = "$($ComputerOVProperties.WinRM)"
                        $Sheet1.cells.item(20,12) = "$($ComputerOVProperties.SSH)"
                        #$Sheet1.cells.item(26,2) = "VPN"
                        $Sheet1.cells.item(27,3) = "$($ComputerOVProperties.VPNConStat)"
                        $Sheet1.cells.item(28,3) = "$($ComputerOVProperties.VPNDNSSuffix)"
                        $Sheet1.cells.item(29,3) = "$($ComputerOVProperties.VPNName)"
                        $Sheet1.cells.item(30,3) = "$($ComputerOVProperties.VPNSvrAdd)"
                        $Sheet1.cells.item(31,3) = "$($ComputerOVProperties.VPNTunnel)"
                        $Sheet1.cells.item(32,3) = "$($ComputerOVProperties.VPNSvrAdds)"
                        #$Sheet1.cells.item(26,5) = "Time"
                        $Sheet1.cells.item(27,6) = "$($ComputerOVProperties.TimeRefId)"
                        $Sheet1.cells.item(28,6) = "$($ComputerOVProperties.TimeSync)"
                        $Sheet1.cells.item(29,6) = "$($ComputerOVProperties.TimeSource)"

                        # Declare Color Index/Size/Name of Font to Use and Formatting
                        $WorkBook = $Sheet1.UsedRange
                        $WorkBook.font.size = 12
                        # Hostname
                        $Sheet1.Cells(1,1).font.colorindex = 23
                        $Sheet1.Cells(1,1).interior.colorindex = 24
                        # Administrators
                        $Sheet1.Cells(2,2).font.colorindex = 23
                        $Sheet1.Cells(2,2).interior.colorindex = 15
                        # Operating System
                        $Sheet1.Cells(6,2).font.colorindex = 23
                        $Sheet1.Cells(6,2).interior.colorindex = 15
                        # Hardware
                        $Sheet1.Cells(17,2).font.colorindex = 23
                        $Sheet1.Cells(17,2).interior.colorindex = 15
                        # Power Profile
                        $Sheet1.Cells(2,5).font.colorindex = 23
                        $Sheet1.Cells(2,5).interior.colorindex = 15
                        # Network
                        $Sheet1.Cells(6,5).font.colorindex = 23
                        $Sheet1.Cells(6,5).interior.colorindex = 15
                        # Processor
                        $Sheet1.Cells(17,5).font.colorindex = 23
                        $Sheet1.Cells(17,5).interior.colorindex = 15
                        # Memory
                        $Sheet1.Cells(6,8).font.colorindex = 23
                        $Sheet1.Cells(6,8).interior.colorindex = 15
                        # Disk
                        $Sheet1.Cells(17,8).font.colorindex = 23
                        $Sheet1.Cells(17,8).interior.colorindex = 15
                        # Bitlocker
                        $Sheet1.Cells(6,11).font.colorindex = 23
                        $Sheet1.Cells(6,11).interior.colorindex = 15
                        # Firewall
                        $Sheet1.Cells(17,11).font.colorindex = 23
                        $Sheet1.Cells(17,11).interior.colorindex = 15
                        #VPN
                        $Sheet1.Cells(26,2).font.colorindex = 23
                        $Sheet1.Cells(26,2).interior.colorindex = 15
                        #Time
                        $Sheet1.Cells(26,5).font.colorindex = 23
                        $Sheet1.Cells(26,5).interior.colorindex = 15

                        $sheet1.Columns.Item(1).columnwidth = 20
                        $sheet1.Columns.Item(2).columnwidth = 35
                        $sheet1.Columns.Item(3).columnwidth = 35
                        $sheet1.Columns.Item(5).columnwidth = 35
                        $sheet1.Columns.Item(6).columnwidth = 35
                        $sheet1.Columns.Item(8).columnwidth = 35
                        $sheet1.Columns.Item(9).columnwidth = 35
                        $sheet1.Columns.Item(11).columnwidth = 35
                        $sheet1.Columns.Item(12).columnwidth = 35

                        # Align to the left [Center = -4108; Right = -4152]
                        $Sheet1.Cells(3,3).horizontalalignment = -4131
                        $sheet1.Cells(10,3).horizontalalignment = -4131
                        $sheet1.Cells(11,3).horizontalalignment = -4131
                        $sheet1.Cells(12,3).horizontalalignment = -4131
                        $sheet1.Cells(13,3).horizontalalignment = -4131
                        $sheet1.Cells(14,3).horizontalalignment = -4131
                        $sheet1.cells(15,3).horizontalalignment = -4131
                        $sheet1.cells(22,3).horizontalalignment = -4131
                        $sheet1.cells(7,6).horizontalalignment = -4131
                        $sheet1.cells(9,6).horizontalalignment = -4131
                        $sheet1.cells(20,6).horizontalalignment = -4131
                        $sheet1.cells(21,6).horizontalalignment = -4131
                        $sheet1.cells(22,6).horizontalalignment = -4131
                        $Sheet1.Cells(7,9).horizontalalignment = -4131
                        $sheet1.cells(10,9).horizontalalignment = -4131
                        $sheet1.cells(11,9).horizontalalignment = -4131
                        $sheet1.cells(12,9).horizontalalignment = -4131
                        $sheet1.cells(9,12).horizontalalignment = -4131
                        $sheet1.cells(18,12).horizontalalignment = -4131
                        $sheet1.cells(19,12).horizontalalignment = -4131
                        $sheet1.cells(20,12).horizontalalignment = -4131

                    #endregion

                    #region [SHEET 2] PRINT ROUTE TABLE

                        Write-Output "Print to Sheet 2"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null

                        $Sheet2 = $Excel.WorkSheets.Item(2)
                        # Name the sheet
                        $Excel.Worksheets.Item(2).Name = "ROUTETABLE"

                        # Where to start printing
                        $RTintRow = 1
                
                        # Print Route Table (Sheet 2 items)
                        foreach ($RouteTableLine in $ComputerRoutePrint) {
                    
                            try{
                                $Sheet2.Cells.Item($RTintRow,1) = $RouteTableLine
                                $RTintRow++
                            }
                            catch{
                                # Ignore Lines that do not need to print
                            }
                        }

                        $WorkBook.font.size = 12
                        $Workbook = $sheet2.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion 

                    #region [SHEET 2_1] CERTIFICATES

                        Write-Output "Print to sheet 2_1"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null
            
                        $Sheet2_1 = $Excel.WorkSheets.Item(3)
                        $Excel.Worksheets.Item(3).Name = "CERTIFICATES"
            
                        # Print Header
                        $Sheet2_1.Cells.Item(1,1) = "PSParentPath"
                        $Sheet2_1.Cells.Item(1,2) = "PsChildName"
                        $Sheet2_1.Cells.Item(1,3) = "EnhancedKeyUsageList"
                        $Sheet2_1.Cells.Item(1,4) = "DNSNameList"
                        $Sheet2_1.Cells.Item(1,5) = "SendAsTrustedIssuer"
                        $Sheet2_1.Cells.Item(1,6) = "Archived"
                        $Sheet2_1.Cells.Item(1,7) = "FriendlyName"
                        $Sheet2_1.Cells.Item(1,8) = "HasPrivateKey"
                        $Sheet2_1.Cells.Item(1,9) = "IssuerName"
                        $Sheet2_1.Cells.Item(1,10) = "NotAfter"
                        $Sheet2_1.Cells.Item(1,11) = "NotBefore"
                        $Sheet2_1.Cells.Item(1,12) = "SerialNumber"
                        $Sheet2_1.Cells.Item(1,13) = "SignatureAlgorithm"
                        $Sheet2_1.Cells.Item(1,14) = "Issuer"

                        $WorkBook = $Sheet2_1.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12
            
                        # Where to start printing
                        $CertintRow = 2

                        foreach ($Certificate in $ComputerCertificates) {
                            $Sheet2_1.Cells.Item($CertintRow,1) = $Certificate.PSParentPath
                            $Sheet2_1.Cells.Item($CertintRow,2) = $Certificate.PsChildName
                            $Sheet2_1.Cells.Item($CertintRow,3) = $Certificate.EnhancedKeyUsageList
                            $Sheet2_1.Cells.Item($CertintRow,4) = $Certificate.DNSNameList
                            $Sheet2_1.Cells.Item($CertintRow,5) = $Certificate.SendAsTrustedIssuer
                            $Sheet2_1.Cells.Item($CertintRow,6) = $Certificate.Archived
                            $Sheet2_1.Cells.Item($CertintRow,7) = $Certificate.FriendlyName
                            $Sheet2_1.Cells.Item($CertintRow,8) = $Certificate.HasPrivateKey
                            $Sheet2_1.Cells.Item($CertintRow,9) = $Certificate.IssuerName
                            $Sheet2_1.Cells.Item($CertintRow,10) = $Certificate.NotAfter
                            $Sheet2_1.Cells.Item($CertintRow,11) = $Certificate.NotBefore
                            $Sheet2_1.Cells.Item($CertintRow,12) = $Certificate.SerialNumber
                            $Sheet2_1.Cells.Item($CertintRow,13) = $Certificate.SignatureAlgorithm
                            $Sheet2_1.Cells.Item($CertintRow,14) = $Certificate.Issuer
                            $CertintRow++
                        }

                        $Workbook = $sheet2_1.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion

                    #region [SHEET 2_2] SMB SHARES

                        Write-Output "Print to sheet 2_2"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null
            
                        $Sheet2_2 = $Excel.WorkSheets.Item(4)
                        $Excel.Worksheets.Item(4).Name = "SMB SHARES"
            
                        # Print Header
                        $Sheet2_2.Cells.Item(1,1) = "Name"
                        $Sheet2_2.Cells.Item(1,2) = "Path"
                        $Sheet2_2.Cells.Item(1,3) = "Description"
                        $Sheet2_2.Cells.Item(1,4) = "ScopeName"
                        $Sheet2_2.Cells.Item(1,5) = "AccountName"
                        $Sheet2_2.Cells.Item(1,6) = "AccessControlType"
                        $Sheet2_2.Cells.Item(1,7) = "AccessRight"

                        $WorkBook = $Sheet2_2.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12
            
                        # Where to start printing
                        $SMBSintRow = 2

                        foreach ($SMBShare in $ComputerSMBShares) {
                            $Sheet2_2.Cells.Item($SMBSintRow,1) = $SMBShare.Name
                            $Sheet2_2.Cells.Item($SMBSintRow,2) = $SMBShare.Path
                            $Sheet2_2.Cells.Item($SMBSintRow,3) = $SMBShare.Description
                            $Sheet2_2.Cells.Item($SMBSintRow,4) = $SMBShare.ScopeName
                            $Sheet2_2.Cells.Item($SMBSintRow,5) = $SMBShare.AccountName
                            $Sheet2_2.Cells.Item($SMBSintRow,6) = $SMBShare.AccessControlType
                            $Sheet2_2.Cells.Item($SMBSintRow,7) = $SMBShare.AccessRight
                            $SMBSintRow++
                        }

                        $Workbook = $sheet2_2.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion

                    #region [SHEET 2_3] FIREWALL RULES

                        Write-Output "Print to sheet 2_3"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null
            
                        $Sheet2_3 = $Excel.WorkSheets.Item(5)
                        $Excel.Worksheets.Item(5).Name = "FIREWALL"
            
                        # Print Header
                        $Sheet2_3.Cells.Item(1,1) = "Name"
                        $Sheet2_3.Cells.Item(1,2) = "DisplayName"
                        $Sheet2_3.Cells.Item(1,3) = "Group"
                        $Sheet2_3.Cells.Item(1,4) = "Enabled"
                        $Sheet2_3.Cells.Item(1,5) = "Profile"
                        $Sheet2_3.Cells.Item(1,6) = "Direction"
                        $Sheet2_3.Cells.Item(1,7) = "Action"
                        $Sheet2_3.Cells.Item(1,8) = "EdgeTraversalPolicy"
                        $Sheet2_3.Cells.Item(1,9) = "Status"
                        $Sheet2_3.Cells.Item(1,10) = "Description"
                        $Sheet2_3.Cells.Item(1,11) = "DisplayGroup"
                        $Sheet2_3.Cells.Item(1,12) = "StatusCode"

                        $WorkBook = $Sheet2_3.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12
            
                        # Where to start printing
                        $FWRintRow = 2

                        foreach ($FirewallRule in $ComputerFirewallRules) {
                            $Sheet2_3.Cells.Item($FWRintRow,1) = $FirewallRule.Name
                            $Sheet2_3.Cells.Item($FWRintRow,2) = $FirewallRule.DisplayName
                            $Sheet2_3.Cells.Item($FWRintRow,3) = $FirewallRule.Group
                            $Sheet2_3.Cells.Item($FWRintRow,4) = $FirewallRule.Enabled
                            $Sheet2_3.Cells.Item($FWRintRow,5) = $FirewallRule.Profile
                            $Sheet2_3.Cells.Item($FWRintRow,6) = $FirewallRule.Direction
                            $Sheet2_3.Cells.Item($FWRintRow,7) = $FirewallRule.Action
                            $Sheet2_3.Cells.Item($FWRintRow,8) = $FirewallRule.EdgeTraversalPolicy
                            $Sheet2_3.Cells.Item($FWRintRow,9) = $FirewallRule.Status
                            $Sheet2_3.Cells.Item($FWRintRow,10) = $FirewallRule.Description
                            $Sheet2_3.Cells.Item($FWRintRow,11) = $FirewallRule.DisplayGroup
                            $Sheet2_3.Cells.Item($FWRintRow,12) = $FirewallRule.StatusCode
                            $FWRintRow++
                        }

                        $Workbook = $sheet2_3.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion

                    #region [SHEET 2_4] NETSTAT

                        Write-Output "Print to Sheet 2_4"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null

                        $Sheet2_4 = $Excel.WorkSheets.Item(6)
                        $Excel.Worksheets.Item(6).Name = "NETSTAT"

                        # Where to start printing
                        $NSintRow = 1
                
                        # Print NetStat (Sheet 2_4 items)
                        foreach ($NetstatLine in $ComputerNetStat) {
                    
                            try{
                                $Sheet2_4.Cells.Item($NSintRow,1) = $NetStatLine
                                $NSintRow++
                            }
                            catch{
                                # Ignore Lines that do not need to print
                            }
                        }

                        $WorkBook.font.size = 12
                        $Workbook = $sheet2_4.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion

                    #region [SHEET 3] RUNNING SERVICES
                
                        Write-Output "Print to sheet 3"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null
            
                        $Sheet3 = $Excel.WorkSheets.Item(7)
                        $Excel.Worksheets.Item(7).Name = "RUNNING SERVICES"
            
                        # Print Header
                        $Sheet3.Cells.Item(1,1) = "ProcessId"
                        $Sheet3.Cells.Item(1,2) = "Name"
                        $Sheet3.Cells.Item(1,3) = "StartMode"
                        $Sheet3.Cells.Item(1,4) = "State"
                        $Sheet3.Cells.Item(1,5) = "Status"
                        $Sheet3.Cells.Item(1,6) = "ExitCode"

                        $WorkBook = $Sheet3.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12
            
                        # Where to start printing
                        $RSintRow = 2

                        foreach ($RunningService in $ComputerRunningServices) {
                            $Sheet3.Cells.Item($RSintRow,1) = $RunningService.ProcessId
                            $Sheet3.Cells.Item($RSintRow,2) = $RunningService.Name
                            $Sheet3.Cells.Item($RSintRow,3) = $RunningService.StartMode
                            $Sheet3.Cells.Item($RSintRow,4) = $RunningService.State
                            $Sheet3.Cells.Item($RSintRow,5) = $RunningService.Status
                            $Sheet3.Cells.Item($RSintRow,6) = $RunningService.ExitCode
                            $RSintRow++
                        }

                        $Workbook = $sheet3.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion
        
                    #region [SHEET 4] SCHEDULED TASKS

                        Write-Output "Print to sheet 4"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null

                        $Sheet4 = $Excel.WorkSheets.Item(8)
                        $Excel.Worksheets.Item(8).Name = "SCHEDULED TASKS"
            
                        # Print header
                        $Sheet4.Cells.Item(1,1) = "TaskName"
                        $Sheet4.Cells.Item(1,2) = "Status"
                        $Sheet4.Cells.Item(1,3) = "Author"
                        $Sheet4.Cells.Item(1,4) = "RunAsUser"
            
                        $WorkBook = $Sheet4.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12

                        # Where to start printing
                        $STintRow = 2

                        foreach ($ScheduledTask in $ComputerScheduledTasks) {
                            $Sheet4.Cells.Item($STintRow,1) = $ScheduledTask.TaskName
                            $Sheet4.Cells.Item($STintRow,2) = $ScheduledTask.Status
                            $Sheet4.Cells.Item($STintRow,3) = $ScheduledTask.Author
                            $Sheet4.Cells.Item($STintRow,4) = $ScheduledTask.'Run As User'
                            $STintRow++
                        }

                        $Workbook = $sheet4.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion 

                    #region [SHEET 5] INSTALLED SOFTWARE

                        Write-Output "Print to sheet 5"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null

                        $Sheet5 = $Excel.WorkSheets.Item(9)
                        $Excel.Worksheets.Item(9).Name = "INSTALLED SOFTWARE"
            
                        $Sheet5.Cells.Item(1,1) = "Name"
                        $Sheet5.Cells.Item(1,2) = "Version"
                        $Sheet5.Cells.Item(1,3) = "Vendor"
                        $Sheet5.Cells.Item(1,4) = "InstallDate"
                        $Sheet5.Cells.Item(1,5) = "InstallSource"
                        $Sheet5.Cells.Item(1,6) = "LocalPackage"
            
                        $WorkBook = $Sheet5.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12

                        # Where to start printing
                        $ISintRow = 2

                        foreach ($InstalledSoftware in $ComputerInstalledSoftware) {
                            $Sheet5.Cells.Item($ISintRow,1) = $InstalledSoftware.Name
                            $Sheet5.Cells.Item($ISintRow,2) = $InstalledSoftware.Version
                            $Sheet5.Cells.Item($ISintRow,3) = $InstalledSoftware.Vendor
                            $Sheet5.Cells.Item($ISintRow,4) = $InstalledSoftware.InstallDate
                            $Sheet5.Cells.Item($ISintRow,5) = $InstalledSoftware.InstallSource
                            $Sheet5.Cells.Item($ISintRow,6) = $InstalledSoftware.LocalPackage

                            $ISintRow++
                        }
            
                        $Workbook = $sheet5.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion
        
                    #region [SHEET 6] UPDATES

                        Write-Output "Print to sheet 6"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null

                        $Sheet6 = $Excel.WorkSheets.Item(10)
                        $Excel.Worksheets.Item(10).Name = "UPDATES"

                        # Print Header
                        $Sheet6.Cells.Item(1,1) = "Description"
                        $Sheet6.Cells.Item(1,2) = "HotFixID"
                        $Sheet6.Cells.Item(1,3) = "Caption"
                        $Sheet6.Cells.Item(1,4) = "InstalledOn"
            
                        $WorkBook = $Sheet6.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12

                        # Where to start printing
                        $CUintRow = 2

                        foreach ($CUpdate in $ComputerUpdates) {
                            $Sheet6.Cells.Item($CUintRow,1) = $CUpdate.Description
                            $Sheet6.Cells.Item($CUintRow,2) = $CUpdate.HotFixID
                            $Sheet6.Cells.Item($CUintRow,3) = $CUpdate.Caption
                            $Sheet6.Cells.Item($CUintRow,4) = $CUpdate.InstalledOn
                            $CUintRow++
                        }

                        $Workbook = $sheet6.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion

                    #region [SHEET 7] DRIVERS

                        Write-Output "Print to sheet 7"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null

                        $Sheet7 = $Excel.WorkSheets.Item(11)
                        $Excel.Worksheets.Item(11).Name = "DRIVERS"

                        # Print Header (Signed Drivers)
                        $Sheet7.Cells.Item(1,1) = "Description"
                        $Sheet7.Cells.Item(1,2) = "Signer"
                        $Sheet7.Cells.Item(1,3) = "IsSigned"
                        $Sheet7.Cells.Item(1,4) = "DeviceID"
                        $Sheet7.Cells.Item(1,5) = "DriverVersion"
                        $Sheet7.Cells.Item(1,6) = "DriverDate"

                        # Print Header (PNP Drivers)
                        $Sheet7.Cells.Item(1,8) = "Caption"
                        $Sheet7.Cells.Item(1,9) = "Description"
                        $Sheet7.Cells.Item(1,10) = "Manufacturer"
                        $Sheet7.Cells.Item(1,11) = "PNPClass"

                        $WorkBook = $Sheet7.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12

                        # Where to start printing
                        $SDintRow = 2

                        # Signed Drivers
                        foreach ($SignedDriver in $ComputerSignedDrivers) {
                
                            $Sheet7.Cells.Item($SDintRow,1) = $SignedDriver.Description
                            $Sheet7.Cells.Item($SDintRow,2) = $SignedDriver.Signer
                            $Sheet7.Cells.Item($SDintRow,3) = $SignedDriver.IsSigned
                            $Sheet7.Cells.Item($SDintRow,4) = $SigneDriver.DeviceID
                            $Sheet7.Cells.Item($SDintRow,5) = $SignedDriver.DriverVersion
                            $Sheet7.Cells.Item($SDintRow,6) = $SignedDriver.DriverDate
                            $SDintRow++
                        }

                        # Where to start printing
                        $PNPintRow = 2

                        # PNP Drivers
                        foreach ($PNPDriver in $ComputerPNPDrivers){

                            $Sheet7.Cells.Item($PNPintRow,8) = $PNPDriver.Caption
                            $Sheet7.Cells.Item($PNPintRow,9) = $PNPDriver.Description
                            $Sheet7.Cells.Item($PNPintRow,10) = $PNPDriver.Manufacturer
                            $Sheet7.Cells.Item($PNPintRow,11) = $PNPDriver.PNPClass
                            $PNPintRow++
                        }

                        $Workbook = $sheet7.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion

                    #region [SHEET 8] WINDOWS FEATURES

                        Write-Output "Print to sheet 8"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null

                        $Sheet8 = $Excel.WorkSheets.Item(12)
                        $Excel.Worksheets.Item(12).Name = "WINDOWS FEATURES"
            
                        # Print header
                        $Sheet8.Cells.Item(1,1) = "FeatureName"
                        $Sheet8.Cells.Item(1,2) = "State"
            
                        $WorkBook = $Sheet8.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12

                        # Where to start Printing
                        $FEATintRow = 2

                        foreach ($Feature in $ComputerFeatures){
                            
                                $Sheet8.Cells.Item($FEATintRow,1) = $Feature.FeatureName
                                $Sheet8.Cells.Item($FEATintRow,2) = "'" + $Feature.State + "'"
                                $FEATintRow++
                        }
            
                        $Workbook = $sheet8.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion

                    #region [SHEET 9] EVENTS

                        Write-Output "Print to sheet 9"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null

                        $Sheet9 = $Excel.WorkSheets.Item(13)
                        $Excel.Worksheets.Item(13).Name = "EVENTS"

                        # Print Header (Log in Events)
                        $Sheet9.Cells.Item(1,1) = "Time"
                        $Sheet9.Cells.Item(1,2) = "Event"
                        $Sheet9.Cells.Item(1,3) = "User"

                        # Print Header (Log off Eventsclear)
                        $Sheet9.Cells.Item(1,6) = "Time"
                        $Sheet9.Cells.Item(1,7) = "Event"
                        $Sheet9.Cells.Item(1,8) = "User"

                        # Print Header (PSSession Events)
                        $Sheet9.Cells.Item(1,10) = "Time"
                        $Sheet9.Cells.Item(1,11) = "Event"
                        $Sheet9.Cells.Item(1,12) = "User"

                        # Print Header (Reboot Events)
                        $Sheet9.Cells.Item(1,14) = "Time"
                        $Sheet9.Cells.Item(1,15) = "Id"
                        $Sheet9.Cells.Item(1,16) = "Message"

                        $WorkBook = $Sheet9.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12

                        # Where to start printing
                        $LIEintRow = 2

                        # Log in Events
                        foreach ($LoginEvent in $ComputerLoginEvents) {
                    
                            $Sheet9.Cells.Item($LIEintRow,1) = $LoginEvent.Time
                            $Sheet9.Cells.Item($LIEintRow,2) = $LoginEvent.Event
                            $Sheet9.Cells.Item($LIEintRow,3) = $LoginEvent.User
                            $LIEintRow++
                        }

                        # Where to start printing
                        $LOEintRow = 2

                        # Log off Events
                        foreach ($LogoffEvent in $ComputerLogoffEvents) {
                    
                            $Sheet9.Cells.Item($LOEintRow,6) = $LogoffEvent.Time
                            $Sheet9.Cells.Item($LOEintRow,7) = $LogoffEvent.Event
                            $Sheet9.Cells.Item($LOEintRow,8) = $LogoffEvent.User
                            $LOEintRow++
                        }

                        # Where to start printing
                        $PSSintRow = 2

                        # PSSession Events
                        foreach ($PSSessionEvent in $ComputerPSSessionEvents) {
                    
                            $Sheet9.Cells.Item($PSSintRow,10) = $PSSessionEvent.Time
                            $Sheet9.Cells.Item($PSSintRow,11) = $PSSessionEvent.Event
                            $Sheet9.Cells.Item($PSSintRow,12) = $PSSessionEvent.User
                            $PSSintRow++
                        }

                        # Where to start printing
                        $REintRow = 2

                        # Reboot Events
                        foreach ($RestartEvent in $ComputerRestartEvents) {
                    
                            $Sheet9.Cells.Item($REintRow,14) = $RestartEvent.TimeCreated
                            $Sheet9.Cells.Item($REintRow,15) = $RestartEvent.Id
                            $Sheet9.Cells.Item($REintRow,16) = $RestartEvent.Message
                            $REintRow++
                        }

                        $Workbook = $sheet9.UsedRange
                        $WorkBook.EntireColumn.AutoFit() | Out-Null

                    #endregion

                    #region [SHEET 10] APPLICATION EVENTS

                        Write-Output "Print to sheet 10"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null

                        $Sheet10 = $Excel.WorkSheets.Item(14)
                        $Excel.Worksheets.Item(14).Name = "APPLICATION EVENTS"

                        # Print Header (Application Warngins)
                        $Sheet10.Cells.Item(1,1) = "LevelDisplayName"
                        $Sheet10.Cells.Item(1,2) = "Message"
                        $Sheet10.Cells.Item(1,3) = "ProviderName"
                        $Sheet10.Cells.Item(1,4) = "LogName"
                        $Sheet10.Cells.Item(1,5) = "UserId"
                        $Sheet10.Cells.Item(1,6) = "TimeCreated"

                        # Print Header (Application Errors)
                        $Sheet10.Cells.Item(1,8) = "LevelDisplayName"
                        $Sheet10.Cells.Item(1,9) = "Message"
                        $Sheet10.Cells.Item(1,10) = "ProviderName"
                        $Sheet10.Cells.Item(1,11) = "LogName"
                        $Sheet10.Cells.Item(1,12) = "UserId"
                        $Sheet10.Cells.Item(1,13) = "TimeCreated"

                        $WorkBook = $Sheet10.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12

                        # Where to start printing
                        $WAEintRow = 2

                        # Application Warnings
                        foreach ($WarnAppEvent in $ComputerWarnAppEvent) {
                    
                            $Sheet10.Cells.Item($WAEintRow,1) = $WarnAppEvent.LevelDisplayName
                            $Sheet10.Cells.Item($WAEintRow,2) = $WarnAppEvent.Message
                            $Sheet10.Cells.Item($WAEintRow,3) = $WarnAppEvent.ProviderName
                            $Sheet10.Cells.Item($WAEintRow,4) = $WarnAppEvent.LogName
                            $Sheet10.Cells.Item($WAEintRow,5) = "'" + $WarnAppEvent.UserId + "'"
                            $Sheet10.Cells.Item($WAEintRow,6) = $WarnAppEvent.TimeCreated
                            $WAEintRow++
                        }

                        # Where to start printing
                        $AEintRow = 2

                        # Application Errors
                        foreach ($ErrorAppEvent in $ComputerErrorAppEvent) {
                    
                            $Sheet10.Cells.Item($AEintRow,8) = $ErrorAppEvent.LevelDisplayName
                            $Sheet10.Cells.Item($AEintRow,9) = $ErrorAppEvent.Message
                            $Sheet10.Cells.Item($AEintRow,10) = $ErrorAppEvent.ProviderName
                            $Sheet10.Cells.Item($AEintRow,11) = $ErrorAppEvent.LogName
                            $Sheet10.Cells.Item($AEintRow,12) = "'" + $ErrorAppEvent.UserId + "'"
                            $Sheet10.Cells.Item($AEintRow,13) = $ErrorAppEvent.TimeCreated
                            $AEintRow++
                        }

                        $Workbook = $sheet10.UsedRange
                        for($EAEInt=1;$EAEInt -le 6;$EAEInt++){

                            $sheet10.Columns.Item($EAEInt).columnwidth = 35
                        }
                        for($EAEInt=8;$EAEInt -le 13;$EAEInt++){

                            $sheet10.Columns.Item($EAEInt).columnwidth = 35
                        }

                    #endregion

                    #region [SHEET 11] SYSTEM EVENTS

                        Write-Output "Print to sheet 11"
                        $Excel.Worksheets.add([System.Reflection.Missing]::Value,$Excel.Worksheets.Item($Excel.Worksheets.count)) | Out-Null

                        $Sheet11 = $Excel.WorkSheets.Item(15)
                        $Excel.Worksheets.Item(15).Name = "SYSTEM EVENTS"

                        # Print Header (System Warngins)
                        $Sheet11.Cells.Item(1,1) = "LevelDisplayName"
                        $Sheet11.Cells.Item(1,2) = "Message"
                        $Sheet11.Cells.Item(1,3) = "ProviderName"
                        $Sheet11.Cells.Item(1,4) = "LogName"
                        $Sheet11.Cells.Item(1,5) = "UserId"
                        $Sheet11.Cells.Item(1,6) = "TimeCreated"

                        # Print Header (System Errors)
                        $Sheet11.Cells.Item(1,8) = "LevelDisplayName"
                        $Sheet11.Cells.Item(1,9) = "Message"
                        $Sheet11.Cells.Item(1,10) = "ProviderName"
                        $Sheet11.Cells.Item(1,11) = "LogName"
                        $Sheet11.Cells.Item(1,12) = "UserId"
                        $Sheet11.Cells.Item(1,13) = "TimeCreated"

                        $WorkBook = $Sheet11.UsedRange
                        $WorkBook.Interior.ColorIndex = 35
                        $WorkBook.font.size = 12

                        # Where to start printing
                        $SWintRow = 2

                        # System Warnings
                        foreach ($WarnSysEvent in $ComputerWarnSysEvent) {
                
                            $Sheet11.Cells.Item($SWintRow,1) = $WarnSysEvent.LevelDisplayName
                            $Sheet11.Cells.Item($SWintRow,2) = $WarnSysEvent.Message
                            $Sheet11.Cells.Item($SWintRow,3) = $WarnSysEvent.ProviderName
                            $Sheet11.Cells.Item($SWintRow,4) = $WarnSysEvent.LogName
                            $Sheet11.Cells.Item($SWintRow,5) = "'" + $WarnSysEvent.UserId + "'"
                            $Sheet11.Cells.Item($SWintRow,6) = $WarnSysEvent.TimeCreated
                            $SWintRow++
                        }

                        # Where to start printing
                        $SEintRow = 2

                        # Application Errors
                        foreach ($ErrorSysEvent in $ComputerErrorSysEvent) {
                
                            $Sheet11.Cells.Item($SEintRow,8) = $ErrorSysEvent.LevelDisplayName
                            $Sheet11.Cells.Item($SEintRow,9) = $ErrorSysEvent.Message
                            $Sheet11.Cells.Item($SEintRow,10) = $ErrorSysEvent.ProviderName
                            $Sheet11.Cells.Item($SEintRow,11) = $ErrorSysEvent.LogName
                            $Sheet11.Cells.Item($SEintRow,12) = "'" + $ErrorSysEvent.UserId + "'"
                            $Sheet11.Cells.Item($SEintRow,13) = $ErrorSysEvent.TimeCreated
                            $SEintRow++
                        }

                        $Workbook = $sheet11.UsedRange
                        for($ESEInt=1;$ESEInt -le 6;$ESEInt++){

                            $sheet11.Columns.Item($ESEInt).columnwidth = 35
                        }
                        for($ESEInt=8;$ESEInt -le 13;$ESEInt++){

                            $sheet11.Columns.Item($ESEInt).columnwidth = 35
                        }

                    #endregion

                    # Save file and exit stream
                    $Excel.ActiveWorkbook.SaveAs("$LogExcelDirectory\$LogExcelFile")
                    $Excel.Quit()
                }
            }
        }
    }

    End {
        #region STOP JOBS

            Write-Output "`0"
            do {
                $Runningjobs = Get-Job
                if($JobInt -ge 0){
                
                    Start-Sleep -Milliseconds 100
                    Write-Host -NoNewline "`rPlease Wait $($Symbol[$JobInt])"
                    $JobInt++
                    if ($JobInt -eq 4){
                        
                        $JobInt = 0
                    }
                }
                foreach ($RunningJob in $Runningjobs){
                    if($RunningJob.State -eq "Completed"){
                        Receive-Job $RunningJob | Out-file "$LogJobsDirectory\$LogDate-$ComputerName-.log" -Append
                        Remove-Job -InstanceId $Runningjob.InstanceId
                    }
                    if($RunningJob.State -eq "Blocked"){
                        Stop-Job -InstanceId $RunningJob.InstanceId
                        Remove-Job -InstanceId $RunningJob.InstanceId

                        # Append variable
                        $BlockedJobs.Add($RunningJob.Name) | Out-Null
                    }
                }
            }until ($Runningjobs.count -eq 0)
            Write-Host -NoNewline "`rScript Complete"

        #endregion

        #region CLEANUP FOLDERS
                      
            foreach ($Computer in $ConnectedComputer){
            
                if ($BlockedJobs.Where({$BlockedJobs -ne $Computer}) -or ($false -eq $BlockedJobs -and $false -eq $NoConnectionComputer)){

                    if ($CreateCSVOnly -eq $false -and $CreateExcelFromCSVPath -eq $false){
                    
                        # Cleanup Local files
                        foreach($TempFolder in Get-ChildItem 'C:\TMP' ){
                        
                            if($TempFolder.Name -eq $Computer){
                            
                                Remove-Item $TempFolder.FullName -Recurse -Force
                            }
                        }
    
                        Remove-Item "\\$Computer\C$\Logs\SystemAudit\$Computer" -Recurse -Force
                    }
                    elseif ($CreateCSVOnly) {
                    
                        Remove-Item "\\$Computer\C$\Logs\SystemAudit\$Computer" -Recurse -Force
                        Write-Host -ForegroundColor DarkCyan "CSV's are here C:\TMP\$Computer"
                    }
                    else{
    
                        # Nothing to do here
                    }
                }
                else{

                    # Nothing to do here
                }
            }

        #endregion

        #region PRINT FAILED CONNECTIONS AND BLOCKED JOBS
        
            if($NoConnectionComputer){

                Write-Host "`0"
                Write-Host -ForegroundColor Red "Could not connect to:"
                $NoConnectionComputer
            }
            if($BlockedJobs){

                Write-Host "`0"
                Write-Host -ForegroundColor Red "Blocked Jobs:"
                $BlockedJobs
            }

        #endregion

        #region OPEN DIRECTORY
        
            if ($CreateCSVOnly -eq $true){

                Invoke-Item 'C:\TMP'
            }
            else{
            
                if ($CreateExcelFromCSVOnly -or ($ConnectedComputer -gt $NoConnectionComputer)){
                    
                    Invoke-Item $LogExcelDirectory
                }
            }
        #endregion
    }
#}