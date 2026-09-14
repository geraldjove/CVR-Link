param([string]$Root=(Split-Path -Parent $PSScriptRoot))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression.FileSystem
$out=Join-Path $Root '.deps\release';$payload=Join-Path $out 'payload'
New-Item -ItemType Directory -Path $payload -Force | Out-Null
foreach($directory in 'loader','runtime'){New-Item -ItemType Directory -Path (Join-Path $payload $directory) -Force | Out-Null}
$archive=Join-Path $out 'UE4SS_v3.0.1.zip'
if(-not(Test-Path -LiteralPath $archive)){
    $ProgressPreference='SilentlyContinue'
    Invoke-WebRequest -UseBasicParsing -Uri 'https://github.com/UE4SS-RE/RE-UE4SS/releases/download/v3.0.1/UE4SS_v3.0.1.zip' -OutFile $archive
}
if((Get-FileHash -LiteralPath $archive).Hash -ne '4B47D4BCEDDD2F561A4E395BFA00924CCFC945AF576A2D0C613E6537846C57EC'){throw 'Official loader download did not match the release hash.'}
$zip=[IO.Compression.ZipFile]::OpenRead($archive)
try{foreach($file in 'UE4SS.dll','dwmapi.dll','UE4SS-settings.ini'){[IO.Compression.ZipFileExtensions]::ExtractToFile($zip.GetEntry($file),(Join-Path $payload ('loader\'+$file)),$true)}}finally{$zip.Dispose()}
foreach($file in 'main.lua','Controls.lua','Inventory.lua','Ammo.lua','HUD.lua','ItemActions.lua','Placement.lua','Menu.lua','Room.lua','Settings.lua'){
    $source=Join-Path $Root $file
    if(-not(Test-Path -LiteralPath $source)){$source=Join-Path $Root ('runtime\'+$file)}
    Copy-Item -LiteralPath $source -Destination (Join-Path $payload ('runtime\'+$file))
}
foreach($file in 'Launcher.ps1','Setup.ps1'){Copy-Item -LiteralPath (Join-Path $PSScriptRoot $file) -Destination (Join-Path $payload $file)}
Copy-Item -LiteralPath (Join-Path $Root 'Control.ps1') -Destination (Join-Path $payload 'Control.ps1')
Copy-Item -LiteralPath (Join-Path $PSScriptRoot 'UE4SS-LICENSE.txt') -Destination (Join-Path $payload 'UE4SS-LICENSE.txt')
$packed=Join-Path $out 'payload.zip';if(Test-Path -LiteralPath $packed){Remove-Item -LiteralPath $packed}
[IO.Compression.ZipFile]::CreateFromDirectory($payload,$packed,[IO.Compression.CompressionLevel]::Optimal,$false)
$compiler=Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$automation=Get-ChildItem -LiteralPath (Join-Path $env:WINDIR 'Microsoft.NET\assembly\GAC_MSIL\System.Management.Automation') -Recurse -Filter System.Management.Automation.dll | Select-Object -First 1 -ExpandProperty FullName
$exe=Join-Path $out 'CVRLink.exe'
& $compiler /nologo /target:winexe /platform:x64 /optimize+ /warnaserror+ /r:System.IO.Compression.dll /r:System.IO.Compression.FileSystem.dll /r:System.Windows.Forms.dll "/r:$automation" "/resource:$packed,payload.zip" "/out:$exe" (Join-Path $PSScriptRoot 'Host.cs')
if($LASTEXITCODE -ne 0){throw 'CVR Link EXE build failed.'}
Get-FileHash -LiteralPath $exe | Select-Object Hash
