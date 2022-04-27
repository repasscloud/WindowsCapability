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
[System.String]$WinEdition = "Pro"
[System.String]$WinArch = "x64"
[System.String]$FidoRelease = "21H2"
[System.String]$WinLcid = "English"
[System.String]$SupportedWinRelease = "Windows_10"

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
Get-WindowsCapability -Path "${env:TMP}\Win${WinRelease}_${FidoRelease}_${WinLcid}_${WinArch}_MOUNT" # | ForEach-Object {
    
#     $obj = $_

#     [System.String]$DisplayName = $obj.DisplayName
#     Write-Output "Verifying AppxProvisionedPackage: ${DisplayName}"
    
#     try
#     {
#         Invoke-RestMethod -Uri "${env:API_URI}/v1/AppXProvisionedPackage/displayname/${DisplayName}" -Method Get -Headers $CHeaders -ErrorAction Stop | Out-Null

#         $RecordFound = Invoke-RestMethod -Uri "${env:API_URI}/v1/AppXProvisionedPackage/displayname/${DisplayName}" -Method Get -Headers $CHeaders
#         [System.Int64]$Id = $RecordFound.id

#         <# ARCH #>
#         if (@($RecordFound.arch) -notcontains $WinArch)
#         {
#             $newArray = @($RecordFound.arch) + $WinArch
#             $Body = @{
#                 id = $Id
#                 uuid = $RecordFound.uuid
#                 displayName = $RecordFound.displayName
#                 arch = $newArray
#                 lcid = @($RecordFound.lcid)
#                 supportedWindowsVersions = @($RecordFound.supportedWindowsVersions)
#                 supportedWindowsEditions = @($RecordFound.supportedWindowsEditions)
#                 supportedWindowsReleases = @($RecordFound.supportedWindowsReleases)
#             } | ConvertTo-Json
#             Write-Output "<| Test WinArch"
#             Invoke-RestMethod -Uri "${env:API_URI}/v1/AppXProvisionedPackage/${Id}" -Method Put -UseBasicParsing -Body $Body -ContentType 'application/json' -ErrorAction Stop
#         }
#         else
#         {
#             Write-Output "  => WinArch OK"
#         }

#         <# LCID #>
#         if (@($RecordFound.lcid) -notcontains $WinLcid)
#         {
#             $newArray = @($RecordFound.lcid) + $WinLcid
#             $Body = @{
#                 id = $Id
#                 uuid = $RecordFound.uuid
#                 displayName = $RecordFound.displayName
#                 arch = @($RecordFound.arch)
#                 lcid = $newArray
#                 supportedWindowsVersions = @($RecordFound.supportedWindowsVersions)
#                 supportedWindowsEditions = @($RecordFound.supportedWindowsEditions)
#                 supportedWindowsReleases = @($RecordFound.supportedWindowsReleases)
#             } | ConvertTo-Json
#             Write-Output "<| Test Lcid"
#             Invoke-RestMethod -Uri "${env:API_URI}/v1/AppXProvisionedPackage/${Id}" -Method Put -UseBasicParsing -Body $Body -ContentType 'application/json' -ErrorAction Stop
#         }
#         else
#         {
#             Write-Output "  => Lcid OK"
#         }

#         <# SUPPORTEDWINDOWSVERSIONS #>
#         if (@($RecordFound.supportedWindowsVersions) -notcontains $FidoRelease)
#         {
#             $newArray = @($RecordFound.supportedWindowsVersions) + $FidoRelease
#             $Body = @{
#                 id = $Id
#                 uuid = $RecordFound.uuid
#                 displayName = $RecordFound.displayName
#                 arch = @($RecordFound.arch)
#                 lcid = @($RecordFound.lcid)
#                 supportedWindowsVersions = $newArray
#                 supportedWindowsEditions = @($RecordFound.supportedWindowsEditions)
#                 supportedWindowsReleases = @($RecordFound.supportedWindowsReleases)
#             } | ConvertTo-Json
#             Write-Output "<| Test SupportedWindowsVersions"
#             Invoke-RestMethod -Uri "${env:API_URI}/v1/AppXProvisionedPackage/${Id}" -Method Put -UseBasicParsing -Body $Body -ContentType 'application/json' -ErrorAction Stop
#         }
#         else
#         {
#             Write-Output "  => SupportedWindowsVersions OK"
#         }

#         <# SUPPORTEDWINDOWSEDITIONS #>
#         if (@($RecordFound.supportedWindowsEditions) -notcontains $WinEdition)
#         {
#             $newArray = @($RecordFound.supportedWindowsEditions) + $WinEdition
#             $Body = @{
#                 id = $Id
#                 uuid = $RecordFound.uuid
#                 displayName = $RecordFound.displayName
#                 arch = @($RecordFound.arch)
#                 lcid = @($RecordFound.lcid)
#                 supportedWindowsVersions = @($RecordFound.supportedWindowsVersions)
#                 supportedWindowsEditions = $newArray
#                 supportedWindowsReleases = @($RecordFound.supportedWindowsReleases)
#             } | ConvertTo-Json
#             Write-Output "<| Test SupportedWindowsEditions"
#             Invoke-RestMethod -Uri "${env:API_URI}/v1/AppXProvisionedPackage/${Id}" -Method Put -UseBasicParsing -Body $Body -ContentType 'application/json' -ErrorAction Stop
#         }
#         else
#         {
#             Write-Output "  => SupportedWindowsEditions OK"
#         }

#         <# SUPPORTEDWINDOWSRELEASES #>
#         if (@($RecordFound.supportedWindowsReleases) -notcontains $SupportedWinRelease)
#         {
#             $newArray = @($RecordFound.supportedWindowsReleases) + $SupportedWinRelease
#             $Body = @{
#                 id = $Id
#                 uuid = $RecordFound.uuid
#                 displayName = $RecordFound.displayName
#                 arch = @($RecordFound.arch)
#                 lcid = @($RecordFound.lcid)
#                 supportedWindowsVersions = @($RecordFound.supportedWindowsVersions)
#                 supportedWindowsEditions = @($RecordFound.supportedWindowsEditions)
#                 supportedWindowsReleases = $newArray
#             } | ConvertTo-Json
#             Write-output "<| Test SupportedWindowsReleases"
#             Invoke-RestMethod -Uri "${env:API_URI}/v1/AppXProvisionedPackage/${Id}" -Method Put -UseBasicParsing -Body $Body -ContentType 'application/json' -ErrorAction Stop
#         }
#         else
#         {
#             Write-Output "  => SupportedWindowsReleases OK"
#         }
#     }
#     catch
#     {
#         $Body = @{
#             id = 0
#             uuid = [System.Guid]::NewGuid().Guid.ToString()
#             displayName = $DisplayName
#             arch = @($WinArch)
#             lcid = @($WinLcid)
#             supportedWindowsVersions = @($FidoRelease)
#             supportedWindowsEditions = @($WinEdition)
#             supportedWindowsReleases = @($SupportedWinRelease)
#         } | ConvertTo-Json
#         Invoke-RestMethod -Uri "${env:API_URI}/v1/AppXProvisionedPackage" -Method Post -UseBasicParsing -Body $Body -ContentType 'application/json' -ErrorAction Stop
#     }
# }

<# CLEAN UP #>
DisMount-WindowsImage -Path "${env:TMP}\Win${WinRelease}_${FidoRelease}_${WinLcid}_${WinArch}_MOUNT" -Discard
Remove-Item -Path "${env:TMP}\Win${WinRelease}_${FidoRelease}_${WinLcid}_${WinArch}_MOUNT" -Recurse -Force -Confirm:$false
