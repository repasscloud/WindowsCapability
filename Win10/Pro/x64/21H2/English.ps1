<# PRE EXECUTION SETUP #>
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
[System.String]$repo = "pbatard/Fido"
[System.String]$releases = "https://api.github.com/repos/${repo}/releases"
Write-Output "Determining latest release"
[System.String]$tag = (Invoke-WebRequest $releases | ConvertFrom-Json)[0].tag_name
[System.String]$download = "https://github.com/pbatard/Fido/archive/refs/tags/${tag}.zip"
[System.String]$zipfile = Split-Path -Path $download -Leaf
[System.String]$dirname = $zipfile -replace '.*\.zip$',''
Write-Output "Downloading latest release"
Invoke-WebRequest -UseBasicParsing -Uri $download -OutFile $zipfile
Write-Output "Extracting release files"
Expand-Archive $zipfile -Force
Remove-Item -Path $zipfile -Recurse -Force -ErrorAction SilentlyContinue 
[System.String]$FidoFile = Get-ChildItem -Path ".\${dirname}" -Recurse -Filter "Fido.ps1" | Select-Object -ExpandProperty FullName
$CHeaders = @{accept = 'application/json'}

<# CONFIG #>
[System.String]$WinRelease = "10"
[System.String]$WinEdition = "Pro"  # WindowsEdition (Home, Pro, Pro_N, Education, Education_N, Enterprise, Enterprise_N, Pro_Education, Pro_Education_N, Pro_Workstations,Pro_N_Workstations, Enterprise_LTSC)
[System.String]$WinArch = "x64"
[System.String]$FidoRelease = "21H2"  # WindowsVersion (v21H2, v21H1, v20H2, v2004, v1909, v1903, v1809, v1809, v1803, v1709, v1703, v1607, v1511, v1507)
[System.String]$WinLcid = "English"
[System.String]$SupportedWinRelease = "Windows_10"  # WindowsRelease (Windows_7, Windows_8, Windows_8_1, Windows_10, Windows_11)

<# SETUP #>
[System.String]$DownloadLink = & $FidoFile -Win $WinRelease -Rel $FidoRelease -Ed $WinEdition -Lang $WinLcid -Arch $WinArch -GetUrl
Invoke-WebRequest -UseBasicParsing -Uri $DownloadLink -OutFile "Win${WinRelease}_${FidoRelease}_${WinLcid}_${WinArch}.iso" -ContentType "application/octet-stream"
[System.String]$IsoFile = Get-ChildItem -Path . -Recurse -Filter "*.iso" | Select-Object -ExpandProperty FullName

<# MOUNT #>
$iso = Mount-DiskImage -ImagePath $IsoFile -Access ReadOnly -StorageType ISO
[System.String]$DriveLetter = $($iso | Get-Volume | Select-Object -ExpandProperty DriveLetter) + ":"
[System.String]$InstallWIM = Get-ChildItem -Path "${DriveLetter}\" -Recurse -Filter "install.wim" | Select-Object -ExpandProperty FullName
New-Item -Path $env:TMP -ItemType Directory -Name "Win${WinRelease}_${FidoRelease}_${WinLcid}_${WinArch}_MOUNT" -Force -Confirm:$false
[System.String]$ImageIndex = Get-WindowsImage -ImagePath $InstallWIM | Where-Object -FilterScript {$_.ImageName -match '^Windows 10 Pro$'} | Select-Object -ExpandProperty ImageIndex
Mount-WindowsImage -ImagePath $InstallWIM -Index $ImageIndex -Path "${env:TMP}\Win${WinRelease}_${FidoRelease}_${WinLcid}_${WinArch}_MOUNT" -ReadOnly

<# MAIN API EXEC #>
Get-WindowsCapability -Path "${env:TMP}\Win${WinRelease}_${FidoRelease}_${WinLcid}_${WinArch}_MOUNT" | ForEach-Object {
    
    $obj = $_

    [System.String]$Name = $obj.Name
    [System.String]$State = $obj.State
    Write-Output "Verifying WindowsCapability: ${Name}"
    switch ($State)
    {
        'Installed' {
            $Enabled = $true
        }
        'NotPresent' {
            $Enabled = $false
        }
        Default {
            $Enabled = $false
        }
    }


    # public int Id { get; set; }
    # public Guid UUID { get; set; }
    # public string Name { get; set; } = null!;  // this object does not have a UID
    # public bool Present { get; set; }
    # public string[] SupportedWindowsVersions { get; set; }  // WindowsVersion (v21H2, v21H1, v20H2, v2004, v1909, v1903, v1809, v1809, v1803, v1709, v1703, v1607, v1511, v1507)
    # public string[] SupportedWindowsEditions { get; set; }  // WindowsEdition (Home, Pro, Pro_N, Education, Education_N, Enterprise, Enterprise_N, Pro_Education, Pro_Education_N, Pro_Workstations,Pro_N_Workstations, Enterprise_LTSC)

    try
    {
        Invoke-RestMethod -Uri "${env:API_URI}/v1/windowscapability/name/${Name}" -Method Get -Headers $CHeaders -ErrorAction Stop | Out-Null

        $RecordFound = Invoke-RestMethod -Uri "${env:API_URI}/v1/WindowsCapability/name/${Name}" -Method Get -Headers $CHeaders
        [System.Int64]$Id = $RecordFound.id

        <# SUPPORTEDWINDOWSVERSIONS #>
        if (@($RecordFound.supportedWindowsVersions) -notcontains $FidoRelease)
        {
            $newArray = @($RecordFound.supportedWindowsVersions) + $FidoRelease
            $Body = @{
                id = $Id
                uuid = $RecordFound.uuid
                name = $RecordFound.name
                present = $RecordFound.state
                supportedWindowsVersions = $newArray
                supportedWindowsEditions = @($RecordFound.supportedWindowsEditions)
                supportedWindowsReleases = @($RecordFound.supportedWindowsReleases)
            } | ConvertTo-Json
            Write-Output "<| Test SupportedWindowsVersions"
            Invoke-RestMethod -Uri "${env:API_URI}/v1/WindowsCapability/${Id}" -Method Put -UseBasicParsing -Body $Body -ContentType 'application/json' -ErrorAction Stop
        }
        else
        {
            Write-Output "  => SupportedWindowsVersions OK"
        }

        <# SUPPORTEDWINDOWSEDITIONS #>
        if (@($RecordFound.supportedWindowsEditions) -notcontains $WinEdition)
        {
            $newArray = @($RecordFound.supportedWindowsEditions) + $WinEdition
            $Body = @{
                id = $Id
                uuid = $RecordFound.uuid
                name = $RecordFound.name
                present = $RecordFound.state
                supportedWindowsVersions = @($RecordFound.supportedWindowsVersions)
                supportedWindowsEditions = $newArray
                supportedWindowsReleases = @($RecordFound.supportedWindowsReleases)
            } | ConvertTo-Json
            Write-Output "<| Test SupportedWindowsEditions"
            Invoke-RestMethod -Uri "${env:API_URI}/v1/WindowsCapability/${Id}" -Method Put -UseBasicParsing -Body $Body -ContentType 'application/json' -ErrorAction Stop
        }
        else
        {
            Write-Output "  => SupportedWindowsEditions OK"
        }

        <# SUPPORTEDWINDOWSRELEASES #>
        if (@($RecordFound.supportedWindowsReleases) -notcontains $SupportedWinRelease)
        {
            $newArray = @($RecordFound.supportedWindowsReleases) + $SupportedWinRelease
            $Body = @{
                id = $Id
                uuid = $RecordFound.uuid
                name = $RecordFound.name
                present = $RecordFound.state
                supportedWindowsVersions = @($RecordFound.supportedWindowsVersions)
                supportedWindowsEditions = @($RecordFound.supportedWindowsEditions)
                supportedWindowsReleases = $newArray
            } | ConvertTo-Json
            Write-output "<| Test SupportedWindowsReleases"
            Invoke-RestMethod -Uri "${env:API_URI}/v1/WindowsCapability/${Id}" -Method Put -UseBasicParsing -Body $Body -ContentType 'application/json' -ErrorAction Stop
        }
        else
        {
            Write-Output "  => SupportedWindowsReleases OK"
        }
    }
    catch
    {
        $SupportedWindowsRelease = "v" + $FidoRelease
        $Body = @{
            id = 0
            uuid = [System.Guid]::NewGuid().Guid.ToString()
            name = $Name
            present = $Enabled
            supportedWindowsVersions = @($SupportedWindowsRelease)
            supportedWindowsEditions = @($WinEdition)
            supportedWindowsReleases = @($SupportedWinRelease)
        } | ConvertTo-Json
        Invoke-RestMethod -Uri "${env:API_URI}/v1/WindowsCapability" -Method Post -UseBasicParsing -Body $Body -ContentType 'application/json' -ErrorAction Stop
    }
}

<# CLEAN UP #>
DisMount-WindowsImage -Path "${env:TMP}\Win${WinRelease}_${FidoRelease}_${WinLcid}_${WinArch}_MOUNT" -Discard
Remove-Item -Path "${env:TMP}\Win${WinRelease}_${FidoRelease}_${WinLcid}_${WinArch}_MOUNT" -Recurse -Force -Confirm:$false
