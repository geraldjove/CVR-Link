param([string]$Payload=(Join-Path $PSScriptRoot '..\.deps\release\payload'))
$ErrorActionPreference='Stop'
. (Join-Path $PSScriptRoot 'Setup.ps1')
$sandbox=Join-Path $PSScriptRoot ('..\.deps\setup-test-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $sandbox -Force | Out-Null
$sandbox=(Resolve-Path -LiteralPath $sandbox).Path
$checks=0
function Assert($Value,[string]$Name){if(-not $Value){throw $Name};$script:checks++}
# Tests never write to a real Steam folder and do not need to stop a live game.
function Assert-GameClosed {}
function New-Game([string]$Name){
    $folder=Join-Path $sandbox $Name;New-Item -ItemType Directory -Path $folder -Force | Out-Null
    [IO.File]::WriteAllText((Join-Path $folder $script:GameExe),'test-game')
    return $folder
}
$game=New-Game 'fresh';$state=Join-Path $sandbox 'state'
$script:GameHash=Get-Hash (Join-Path $game $script:GameExe)
$null=Install-Link $Payload $game $state
Assert (Test-LinkInstalled $Payload $state) 'Clean install is recognized'
Assert ((Get-Hash (Join-Path $game 'UE4SS.dll')) -eq (Get-Hash (Join-Path $Payload 'loader\UE4SS.dll'))) 'Pinned loader is copied'
Assert ((Get-Content -Raw -LiteralPath (Join-Path $game 'UE4SS-settings.ini')) -match 'bUseUObjectArrayCache = false') 'Crash-safe setting is applied'
Assert ((Get-ChildItem -LiteralPath (Join-Path $game 'Mods') -Directory).Count -eq 1) 'No sample mods are installed'
$before=(Get-Content -Raw -LiteralPath (Join-Path $state 'install.json') | ConvertFrom-Json).files[0].backup
$null=Install-Link $Payload $game $state
$after=(Get-Content -Raw -LiteralPath (Join-Path $state 'install.json') | ConvertFrom-Json).files[0].backup
Assert ($before -eq $after) 'Repair keeps the original backup'
$journal=Join-Path $state 'install.json'
$legacy=Get-Content -Raw -LiteralPath $journal | ConvertFrom-Json
foreach($oldVersion in '0.1.0','0.2.0','0.2.1','0.2.2','0.2.3','0.2.4','0.2.5','0.2.6','0.2.7','0.2.8','0.2.9','0.2.10','0.2.11','0.2.12','0.2.13','0.2.14','0.2.15','0.2.16','0.2.17','0.2.18','0.2.23'){
    $legacy.version=$oldVersion
    [IO.File]::WriteAllText($journal,($legacy | ConvertTo-Json -Depth 5))
    Assert (-not (Test-LinkInstalled $Payload $state)) ('Version '+$oldVersion+' requires setup even when runtime hashes match')
}
$oldRuntime=Join-Path $game 'Mods\Flatscreen\Scripts\Controls.lua'
[IO.File]::WriteAllText($oldRuntime,'previous runtime')
($legacy.files | Where-Object path -EQ 'Mods\Flatscreen\Scripts\Controls.lua').sha256=Get-Hash $oldRuntime
[IO.File]::WriteAllText($journal,($legacy | ConvertTo-Json -Depth 5))
$null=Install-Link $Payload $game $state
$upgraded=Get-Content -Raw -LiteralPath $journal | ConvertFrom-Json
Assert ($upgraded.version -eq '0.2.32' -and (Test-LinkInstalled $Payload $state)) 'Upgrade replaces the old runtime and records 0.2.32'
Assert ($upgraded.files[0].backup -eq $before) 'Upgrade keeps the original rollback backup'
$null=Remove-Link $state
Assert (-not(Test-Path -LiteralPath (Join-Path $game 'UE4SS.dll'))) 'Remove deletes a loader that we added'
Assert (Test-Path -LiteralPath (Join-Path $game $script:GameExe)) 'Remove keeps the game'
Assert (-not(Test-Path -LiteralPath (Join-Path $state 'install.json'))) 'Completed removal clears the install journal'
$game=New-Game 'existing';$state=Join-Path $sandbox 'existing-state'
New-Item -ItemType Directory -Path (Join-Path $game 'Mods\AnotherMod') -Force | Out-Null
Copy-Item -LiteralPath (Join-Path $Payload 'loader\UE4SS.dll') -Destination $game
$oldIni="[General]`r`nOtherSetting = keep`r`nbUseUObjectArrayCache = true`r`n[Debug]`r`nGuiConsoleEnabled = 1`r`n"
[IO.File]::WriteAllText((Join-Path $game 'UE4SS-settings.ini'),$oldIni)
[IO.File]::WriteAllText((Join-Path $game 'Mods\mods.txt'),"AnotherMod : 1`r`nFlatscreen : 0`r`n")
$null=Install-Link $Payload $game $state
Assert ((Get-Content -Raw -LiteralPath (Join-Path $game 'UE4SS-settings.ini')).Contains('OtherSetting = keep')) 'Other loader settings are kept'
$mods=Get-Content -Raw -LiteralPath (Join-Path $game 'Mods\mods.txt')
Assert ($mods.Contains('AnotherMod : 1') -and $mods.Contains('Flatscreen : 1')) 'Other mods stay enabled and Flatscreen is enabled'
$kept=@(Remove-Link $state)
Assert ((Get-Content -Raw -LiteralPath (Join-Path $game 'UE4SS-settings.ini')) -ceq $oldIni) 'Existing loader config is restored'
Assert (Test-Path -LiteralPath (Join-Path $game 'UE4SS.dll')) 'Existing loader is kept'
Assert ($kept -contains 'dwmapi.dll') 'New shared loader stays when another mod needs it'
$game=New-Game 'edited';$state=Join-Path $sandbox 'edited-state'
$null=Install-Link $Payload $game $state
[IO.File]::WriteAllText((Join-Path $game 'Mods\Flatscreen\Scripts\main.lua'),'user edit')
$kept=@(Remove-Link $state)
Assert ($kept -contains 'Mods\Flatscreen\Scripts\main.lua') 'Removal keeps user edits'
Assert ((Get-Content -Raw -LiteralPath (Join-Path $game 'Mods\Flatscreen\Scripts\main.lua')) -eq 'user edit') 'User edit bytes are unchanged'
$game=New-Game 'conflict';$state=Join-Path $sandbox 'conflict-state'
[IO.File]::WriteAllText((Join-Path $game 'dwmapi.dll'),'other loader')
$rejected=$false;try{$null=Install-Link $Payload $game $state}catch{$rejected=$true}
Assert ($rejected -and (Get-Content -Raw -LiteralPath (Join-Path $game 'dwmapi.dll')) -eq 'other loader') 'Loader conflict stops before writes'
Assert (-not(Test-Path -LiteralPath $state)) 'Conflict leaves no install state'
$game=New-Game 'wrong-build';[IO.File]::WriteAllText((Join-Path $game $script:GameExe),'different game')
$rejected=$false;try{$null=Get-InstallFiles $Payload $game}catch{$rejected=$true}
Assert $rejected 'Untested game build is rejected'
$game=New-Game 'rollback';$state=Join-Path $sandbox 'rollback-state'
New-Item -ItemType Directory -Path (Join-Path $state 'install.json.tmp') -Force | Out-Null
$rejected=$false;try{$null=Install-Link $Payload $game $state}catch{$rejected=$true}
Assert ($rejected -and -not(Test-Path -LiteralPath (Join-Path $game 'UE4SS.dll'))) 'Failed journal save rolls all installed files back'
$paths=@(Get-LibraryPaths '"libraryfolders" { "0" { "path" "D:\\Steam Library" } "1" { "path" "E:\\Games" } }')
Assert ($paths.Count -eq 2 -and $paths[0] -eq 'D:\Steam Library') 'Steam libraries with spaces are parsed'
$rejected=$false;try{$null=Safe-Child $game '..\outside'}catch{$rejected=$true}
Assert $rejected 'Parent traversal is rejected'
$game=New-Game 'unknown-file';$state=Join-Path $sandbox 'unknown-state'
$null=Install-Link $Payload $game $state
$journal=Join-Path $state 'install.json';$record=Get-Content -Raw -LiteralPath $journal | ConvertFrom-Json
$record.files[0].path='other-game-file.txt';$record | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $journal
$rejected=$false;try{$null=Remove-Link $state}catch{$rejected=$true}
Assert ($rejected -and (Test-Path -LiteralPath (Join-Path $game 'UE4SS.dll'))) 'Unknown uninstall file stops removal before any writes'
$text=Set-IniValue "[General]`nflag=old`n[Other]`nflag=leave" 'General' 'flag' 'new'
Assert ($text.Contains('flag = new') -and $text.Contains('flag=leave')) 'INI patch stays in its section'
[ordered]@{count=$checks;passed=$true;scope='isolated filesystem checks; no game install changed'} | ConvertTo-Json | Set-Content -LiteralPath (Join-Path $sandbox 'result.json')
"Installer: $checks checks passed."
