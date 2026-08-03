param(
  [string]$BuildDirectory = "build/windows/x64/runner/Release",
  [string]$Output = "build/releases/meeting-notes.msix",
  [string]$Publisher = "CN=MeetingNotes Development",
  [string]$Identity = "com.meetingnotes.app",
  [string]$CertificatePath = "",
  [string]$CertificatePassword = ""
)

$ErrorActionPreference = "Stop"
$root = (Resolve-Path (Join-Path $PSScriptRoot "../..")).Path
$source = Join-Path $root $BuildDirectory
if (-not (Test-Path $source)) { throw "Windows release build not found: $source" }

$staging = Join-Path $env:TEMP "easy-meeting-msix-$PID"
if (Test-Path $staging) { Remove-Item -Recurse -Force $staging }
New-Item -ItemType Directory -Path $staging | Out-Null
Copy-Item (Join-Path $source "*") $staging -Recurse
New-Item -ItemType Directory -Path (Join-Path $staging "Assets") | Out-Null

Add-Type -AssemblyName System.Drawing
$icon = [System.Drawing.Image]::FromFile((Join-Path $root "android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"))
foreach ($spec in @(@("Square44x44Logo.png", 44), @("Square150x150Logo.png", 150))) {
  $bitmap = New-Object System.Drawing.Bitmap($spec[1], $spec[1])
  $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
  $graphics.DrawImage($icon, 0, 0, $spec[1], $spec[1])
  $bitmap.Save((Join-Path $staging "Assets/$($spec[0])"), [System.Drawing.Imaging.ImageFormat]::Png)
  $graphics.Dispose()
  $bitmap.Dispose()
}
$icon.Dispose()

$manifest = @"
<?xml version="1.0" encoding="utf-8"?>
<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"
         xmlns:uap="http://schemas.microsoft.com/appx/manifest/uap/windows10"
         xmlns:rescap="http://schemas.microsoft.com/appx/manifest/foundation/windows10/restrictedcapabilities"
         IgnorableNamespaces="uap rescap">
  <Identity Name="$Identity" Publisher="$Publisher" Version="1.0.0.1" ProcessorArchitecture="x64" />
  <Properties>
    <DisplayName>会议纪要</DisplayName>
    <PublisherDisplayName>MeetingNotes</PublisherDisplayName>
    <Logo>Assets\Square150x150Logo.png</Logo>
  </Properties>
  <Dependencies>
    <TargetDeviceFamily Name="Windows.Desktop" MinVersion="10.0.17763.0" MaxVersionTested="10.0.26100.0" />
  </Dependencies>
  <Resources><Resource Language="zh-CN" /></Resources>
  <Applications>
    <Application Id="App" Executable="easy_meeting.exe" EntryPoint="Windows.FullTrustApplication">
      <uap:VisualElements DisplayName="会议纪要" Description="本地优先的 AI 会议纪要"
        BackgroundColor="transparent" Square44x44Logo="Assets\Square44x44Logo.png"
        Square150x150Logo="Assets\Square150x150Logo.png" />
    </Application>
  </Applications>
  <Capabilities><rescap:Capability Name="runFullTrust" /></Capabilities>
</Package>
"@
Set-Content -Path (Join-Path $staging "AppxManifest.xml") -Value $manifest -Encoding UTF8

$kits = Join-Path ${env:ProgramFiles(x86)} "Windows Kits/10/bin"
$makeAppx = Get-ChildItem $kits -Filter makeappx.exe -Recurse |
  Where-Object { $_.FullName -match "\\x64\\" } | Sort-Object FullName -Descending | Select-Object -First 1
if (-not $makeAppx) { throw "makeappx.exe was not found in the Windows SDK" }
$outputPath = Join-Path $root $Output
New-Item -ItemType Directory -Path (Split-Path $outputPath) -Force | Out-Null
& $makeAppx.FullName pack /d $staging /p $outputPath /o

if ($CertificatePath) {
  $signTool = Get-ChildItem $kits -Filter signtool.exe -Recurse |
    Where-Object { $_.FullName -match "\\x64\\" } | Sort-Object FullName -Descending | Select-Object -First 1
  if (-not $signTool) { throw "signtool.exe was not found in the Windows SDK" }
  $arguments = @("sign", "/fd", "SHA256", "/f", $CertificatePath)
  if ($CertificatePassword) { $arguments += @("/p", $CertificatePassword) }
  $arguments += $outputPath
  & $signTool.FullName $arguments
}

Remove-Item -Recurse -Force $staging
Write-Output $outputPath

