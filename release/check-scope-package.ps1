param([Parameter(Mandatory=$true)][string]$Stage)
$ErrorActionPreference='Stop'
. (Join-Path $Stage 'release/Setup.ps1')
function Assert-GameClosed {}
$sandbox=Join-Path $Stage ('.deps/scope-package-test-'+[guid]::NewGuid().ToString('N'))
$game=Join-Path $sandbox 'game/Binaries/Win64';$state=Join-Path $sandbox 'state'
New-Item -ItemType Directory -Path $game,$state | Out-Null
$payload=Join-Path $Stage '.deps/release/payload'
Install-ScopePackage $payload $game $state
if(-not(Test-ScopePackage $payload $game $state)){throw 'Private scope install mismatch'}
$folder=Get-ScopeFolder $game
if(-not $folder.StartsWith([IO.Path]::GetFullPath($sandbox),[StringComparison]::OrdinalIgnoreCase)){throw 'Scope package escaped the test sandbox'}
$pak=Join-Path $folder 'CVRScope.pak'
Remove-Item -LiteralPath $pak
if(Test-ScopePackage $payload $game $state){throw 'Missing private PAK was accepted'}
Install-ScopePackage $payload $game $state
if(-not(Test-ScopePackage $payload $game $state)){throw 'Missing private PAK did not repair'}
[IO.File]::WriteAllText($pak,'user changed file')
$blocked=$false
try{Install-ScopePackage $payload $game $state}catch{$blocked=$true}
if(-not $blocked -or [IO.File]::ReadAllText($pak) -ne 'user changed file'){throw 'Changed PAK was not protected'}
$kept=@(Remove-ScopePackage $game $state)
if($kept -notcontains $pak -or -not(Test-Path -LiteralPath $pak)){throw 'Removal did not retain the changed PAK'}
if(Test-Path -LiteralPath (Join-Path $folder 'CVRScope.json')){throw 'Owned manifest was not removed'}
$blocked=$false
try{Get-ScopeFolder (Join-Path $sandbox 'wrong-layout') | Out-Null}catch{$blocked=$true}
if(-not $blocked){throw 'Unexpected binary folder layout was accepted'}
'8 scope package checks pass.'
