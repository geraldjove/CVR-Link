param([string]$Exe=(Join-Path $PSScriptRoot '..\.deps\release\CVRLink.exe'))
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.IO.Compression
$root=Split-Path -Parent $PSScriptRoot
$assembly=[Reflection.Assembly]::Load([IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Exe)))
$stream=$assembly.GetManifestResourceStream('payload.zip')
$archive=[IO.Compression.ZipArchive]::new($stream,[IO.Compression.ZipArchiveMode]::Read)
$expected=[ordered]@{'Control.ps1'=(Join-Path $root 'Control.ps1');'Launcher.ps1'=(Join-Path $PSScriptRoot 'Launcher.ps1');'Setup.ps1'=(Join-Path $PSScriptRoot 'Setup.ps1');'UE4SS-LICENSE.txt'=(Join-Path $PSScriptRoot 'UE4SS-LICENSE.txt')}
$expected['CVRLink.ico']=Join-Path $PSScriptRoot 'CVRLink.ico'
foreach($file in 'main.lua','Controls.lua','Inventory.lua','Ammo.lua','HUD.lua','ItemActions.lua','Placement.lua','Menu.lua','Room.lua','Settings.lua','Display.lua','FlatMenu.lua','Scope.lua'){
    $source=Join-Path $root $file
    if(-not(Test-Path -LiteralPath $source)){$source=Join-Path $root ('runtime/'+$file)}
    $expected['runtime/'+$file]=$source
}
$expected['ScopePackage.ps1']=Join-Path $PSScriptRoot 'ScopePackage.ps1'
foreach($file in 'CVRScope.pak','CVRScope.json'){$expected['scope/'+$file]=Join-Path $root ('scope/'+$file)}
$vendor=@{'loader/UE4SS.dll'='8AC18FBFFC1EF96B0662D4A2D537B3F224C26D65CAABA7989A9404C566102B26';'loader/dwmapi.dll'='CE596412BEFA68C30B7F88F65BEB77D9BDAD55E9B96A276A5A9CF690C63F24BB';'loader/UE4SS-settings.ini'=(Get-FileHash -LiteralPath (Join-Path $root '.deps\release\payload\loader\UE4SS-settings.ini')).Hash}
$bad='(?i)([A-Z]:[\\/]Users[\\/]|[A-Z]:[\\/]ChatGPT|github_pat_[A-Za-z0-9_]{10}|ghp_[A-Za-z0-9]{10}|sk-[A-Za-z0-9]{20}|BEGIN (RSA |EC )?PRIVATE KEY|7656119[0-9]{10})'
try{
    if($archive.Entries.Count -ne 24){throw 'Unexpected embedded file count.'}
    foreach($entry in $archive.Entries){
        $name=$entry.FullName
        if($name.Contains('\')){throw 'Payload paths must use forward slashes.'}
        if(-not $expected.Contains($name) -and -not $vendor.ContainsKey($name)){throw ('Unexpected embedded file: '+$name)}
        $input=$entry.Open();$memory=[IO.MemoryStream]::new();try{$input.CopyTo($memory);$bytes=$memory.ToArray()}finally{$input.Dispose();$memory.Dispose()}
        $hash=[BitConverter]::ToString([Security.Cryptography.SHA256]::Create().ComputeHash($bytes)).Replace('-','')
        $wanted=if($vendor.ContainsKey($name)){$vendor[$name]}else{(Get-FileHash -LiteralPath $expected[$name]).Hash}
        if($hash -ne $wanted){throw ('Embedded file differs from reviewed source: '+$name)}
        foreach($encoding in [Text.Encoding]::ASCII,[Text.Encoding]::Unicode){if($encoding.GetString($bytes) -match $bad){throw ('Private-data pattern in embedded file: '+$name)}}
    }
}finally{$archive.Dispose();$stream.Dispose()}
$bytes=[IO.File]::ReadAllBytes((Resolve-Path -LiteralPath $Exe))
foreach($encoding in [Text.Encoding]::ASCII,[Text.Encoding]::Unicode){if($encoding.GetString($bytes) -match $bad){throw 'Private-data pattern in EXE.'}}
$hash=(Get-FileHash -LiteralPath $Exe).Hash
[IO.File]::WriteAllText((Join-Path (Split-Path -Parent $Exe) 'SHA256SUMS'),$hash+'  CVRLink.exe'+"`n")
[ordered]@{version=$assembly.GetName().Version.ToString(3);exeSha256=$hash;bytes=$bytes.Length;embeddedFiles=24;sourceMatch=$true;vendorHashesMatch=$true;privateDataPatternScan='passed';verified=(Get-Date -Format o)} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $root '.deps\release-sanitization.json')
'Release EXE: 24 allowed files; source hashes, vendor hashes, and private-data scan passed.'
