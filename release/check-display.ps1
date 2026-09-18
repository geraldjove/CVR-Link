$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms
$root=Split-Path -Parent $PSScriptRoot
$ui=[IO.File]::ReadAllText((Join-Path $PSScriptRoot 'DisplayUI.ps1'))
. ([scriptblock]::Create($ui.Substring(0,$ui.IndexOf('$displayPanel='))))
$tokens=$null;$errors=$null
$ast=[Management.Automation.Language.Parser]::ParseFile((Join-Path $root 'Control.ps1'),[ref]$tokens,[ref]$errors)
$writer=$ast.Find({param($n) $n -is [Management.Automation.Language.FunctionDefinitionAst] -and $n.Name -eq 'Write-Atomic'},$true)
. ([scriptblock]::Create($writer.Extent.Text))
$directory=Join-Path ([IO.Path]::GetTempPath()) ('CVR-display-check-'+[guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $directory | Out-Null
$displayGameSettingsPath=Join-Path $directory 'GameUserSettings.ini'
$script:testRunning=$false
function Get-Process {if($script:testRunning){return @{Id=1}}}
$count=0
function Check([bool]$Value,[string]$Message){if(-not $Value){throw $Message};$script:count++}
try{
 $original=@'
[/Script/Engine.GameUserSettings]
bUseVSync=False
FrameRateLimit=0.000000
ResolutionSizeX=1280
ResolutionSizeY=720
FullscreenMode=1
LastConfirmedFullscreenMode=1
PreferredFullscreenMode=1
LastUserConfirmedResolutionSizeX=1280
LastUserConfirmedResolutionSizeY=720
OtherSetting=old
[OtherMod]
KeepMe=1
'@
 [IO.File]::WriteAllText($displayGameSettingsPath,$original)
 Protect-DisplayGameSettings
 $backup=Join-Path $directory 'display-game-original.ini'
 Check ([IO.File]::ReadAllText($backup) -ceq $original) 'Exact original game settings were not backed up'
 $changed=$original.Replace('bUseVSync=False','bUseVSync=True').Replace('FrameRateLimit=0.000000','FrameRateLimit=60.000000').Replace('OtherSetting=old','OtherSetting=new')
 [IO.File]::WriteAllText($displayGameSettingsPath,$changed)
 Protect-DisplayGameSettings
 Check ([IO.File]::ReadAllText($backup) -ceq $original) 'Original backup overwritten'
 $script:testRunning=$true;Restore-DisplayGameSettings
 Check ([IO.File]::ReadAllText($displayGameSettingsPath) -ceq $changed) 'Running-game INI was changed'
 $script:testRunning=$false;Restore-DisplayGameSettings
 Check ([IO.File]::ReadAllText($displayGameSettingsPath) -ceq $original.Replace('OtherSetting=old','OtherSetting=new')) 'Restoration lost unrelated settings or did not restore display values'
 Check (-not [IO.File]::Exists($backup)) 'Finished backup was not cleared'
 Protect-DisplayGameSettings
 [IO.File]::WriteAllText($backup,'broken')
 $before=[IO.File]::ReadAllText($displayGameSettingsPath);$rejected=$false
 try{Restore-DisplayGameSettings}catch{$rejected=$true}
 Check ($rejected -and [IO.File]::ReadAllText($displayGameSettingsPath) -ceq $before) 'Bad backup changed game preferences'
 $sample=@{token=123;until=0;action='apply';vsync=1;fps=60;mode=2;width=1280;height=720}
 Write-Atomic (Join-Path $directory 'display.ini') (Encode-DisplaySettings $sample)
 Check ((Get-DisplayLaunchFlags) -eq ' -ResX=1280 -ResY=720') 'Confirmed profile launch dimensions are wrong'
 $queued=$sample.Clone();$queued.token=124;$queued.width=800;$queued.height=600
 Write-Atomic (Join-Path $directory 'display-request.ini') (Encode-DisplaySettings $queued)
 Check ((Get-DisplayLaunchFlags) -eq ' -ResX=800 -ResY=600') 'Queued launch choice was ignored'
 $queued.until=1;Write-Atomic (Join-Path $directory 'display-request.ini') (Encode-DisplaySettings $queued)
 Check ((Get-DisplayLaunchFlags) -eq ' -ResX=1280 -ResY=720') 'Expired request overrode the confirmed profile'
 $script:displayStamp=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 Assert-DisplayLiveChange $sample $sample $true
 $queued.fps=20;Assert-DisplayLiveChange $queued $sample $false
 $rejected=$false;try{Assert-DisplayLiveChange $queued $sample $true}catch{$rejected=$true}
 Check $rejected 'DLSS live resize accepted'
 $queued=$sample.Clone();$queued.fps=20;$queued.vsync=0
 Assert-DisplayLiveChange $queued $sample $true
 Check $true 'V-Sync and FPS-only changes work with DLSS'
 $script:displayStamp-=10;$rejected=$false;try{Assert-DisplayLiveChange $queued $sample $true}catch{$rejected=$true}
 Check $rejected 'Stale readback accepted for DLSS live change'
 # A stable timer readback must not shrink/grow the AutoSize UI twice a tick.
 Remove-Item -LiteralPath $backup
 $displayStatus=[Windows.Forms.Label]::new();$displayStatus.AutoSize=$true
 $script:textChanges=0;$displayStatus.Add_TextChanged({$script:textChanges++})
 $script:displayRequest=$null;$script:displayNotice=$null;$script:testRunning=$true
 $stamp=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 [IO.File]::WriteAllText((Join-Path $directory 'display-status.txt'),"$stamp|message=Display ready.|actual_fps=0|actual_vsync=1|mode=2|width=1920|height=1080")
 Refresh-Display
 Check ($script:textChanges -eq 1 -and $displayStatus.Text.Contains('Game readback:')) 'Display status must update once with its complete text'
 1..10 | ForEach-Object {Refresh-Display}
 Check ($script:textChanges -eq 1) 'Unchanged display readback is relaying out FOV/display controls'
 $displayStatus.Dispose()
 "Display app: $count backup, preservation, launch, DLSS and stable-layout checks passed."
}finally{
 # Only this freshly created flat test folder; no recursive deletion.
 Get-ChildItem -LiteralPath $directory -File | ForEach-Object {Remove-Item -LiteralPath $_.FullName}
 Remove-Item -LiteralPath $directory
}
