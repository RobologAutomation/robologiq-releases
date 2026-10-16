# RoboLogIQ for Windows - installer.
# Run in PowerShell (no admin rights needed):
#     irm https://download.robologiot.co.in/install.ps1 | iex
# Installs into %LOCALAPPDATA%\RoboLogIQ\app, adds Start-menu and desktop shortcuts and starts the app.
# Run it again at any time to repair or reinstall; later updates happen inside the app.
$ErrorActionPreference = 'Stop'
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$ProgressPreference = 'SilentlyContinue'   # much faster downloads in Windows PowerShell 5

$feed = 'https://download.robologiot.co.in/latest.json'
$root = Join-Path $env:LOCALAPPDATA 'RoboLogIQ'
$app  = Join-Path $root 'app'
$tmp  = Join-Path $env:TEMP 'robologiq-install'

Write-Host ''
Write-Host '  RoboLogIQ for Windows' -ForegroundColor Yellow
Write-Host '  by Robolog Automation' -ForegroundColor DarkGray
Write-Host ''
Write-Host '  Checking the newest version...'
$info = Invoke-RestMethod -Uri $feed -Headers @{ 'Cache-Control' = 'no-cache' }
$url  = $info.windows.url
if (-not $url) { throw 'No Windows version is published yet.' }

New-Item -ItemType Directory -Force -Path $tmp, $app | Out-Null
$zip = Join-Path $tmp 'robologiq-windows.zip'
Write-Host ("  Downloading RoboLogIQ {0}..." -f $info.version)
Invoke-WebRequest -Uri $url -OutFile $zip -UseBasicParsing

if ($info.windows.sha256) {
  $hash = (Get-FileHash -Path $zip -Algorithm SHA256).Hash.ToLower()
  if ($hash -ne $info.windows.sha256.ToLower()) { throw 'The download was damaged. Please run the installer again.' }
}

Write-Host '  Installing...'
Get-Process robologiq -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
$stage = Join-Path $tmp 'stage'
if (Test-Path $stage) { Remove-Item $stage -Recurse -Force }
Expand-Archive -Path $zip -DestinationPath $stage -Force
if (-not (Test-Path (Join-Path $stage 'robologiq.exe'))) { throw 'The download does not contain robologiq.exe.' }
robocopy $stage $app /MIR /R:3 /W:1 /NFL /NDL /NJH /NJS | Out-Null
if ($LASTEXITCODE -ge 8) { throw "Copying the files failed (robocopy $LASTEXITCODE)." }
Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue

$exe = Join-Path $app 'robologiq.exe'
$shell = New-Object -ComObject WScript.Shell
$links = @(
  (Join-Path ([Environment]::GetFolderPath('Programs')) 'RoboLogIQ.lnk'),
  (Join-Path ([Environment]::GetFolderPath('Desktop')) 'RoboLogIQ.lnk')
)
foreach ($l in $links) {
  $s = $shell.CreateShortcut($l)
  $s.TargetPath = $exe
  $s.WorkingDirectory = $app
  $s.IconLocation = "$exe,0"
  $s.Description = 'RoboLogIQ - IoT device monitoring'
  $s.Save()
}

# "Apps & features" entry, so it can be removed like any other program
$uninst = Join-Path $root 'uninstall.ps1'
@'
Get-Process robologiq -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
Remove-Item (Join-Path ([Environment]::GetFolderPath('Programs')) 'RoboLogIQ.lnk') -ErrorAction SilentlyContinue
Remove-Item (Join-Path ([Environment]::GetFolderPath('Desktop')) 'RoboLogIQ.lnk') -ErrorAction SilentlyContinue
Remove-Item 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\RoboLogIQ' -Recurse -ErrorAction SilentlyContinue
Remove-Item (Join-Path $env:LOCALAPPDATA 'RoboLogIQ') -Recurse -Force -ErrorAction SilentlyContinue
'@ | Set-Content -Path $uninst -Encoding UTF8
$key = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\RoboLogIQ'
New-Item -Path $key -Force | Out-Null
Set-ItemProperty -Path $key -Name DisplayName -Value 'RoboLogIQ'
Set-ItemProperty -Path $key -Name DisplayVersion -Value "$($info.version)"
Set-ItemProperty -Path $key -Name Publisher -Value 'Robolog Automation'
Set-ItemProperty -Path $key -Name DisplayIcon -Value $exe
Set-ItemProperty -Path $key -Name InstallLocation -Value $app
Set-ItemProperty -Path $key -Name UninstallString -Value "powershell.exe -NoProfile -ExecutionPolicy Bypass -File `"$uninst`""
Set-ItemProperty -Path $key -Name NoModify -Value 1 -Type DWord
Set-ItemProperty -Path $key -Name NoRepair -Value 1 -Type DWord

Write-Host ("  Done. RoboLogIQ {0} is installed." -f $info.version) -ForegroundColor Green
Write-Host '  Find it in the Start menu or on your desktop. Updates now come inside the app.'
Start-Process -FilePath $exe
