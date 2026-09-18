function Set-DisplayIniText([string]$Text,[string]$Section,$Values) {
 $newline=if($Text.Contains("`r`n")){"`r`n"}else{"`n"}
 $start=0;$length=$Text.Length
 if($Section){
  $sections=[regex]::Matches($Text,('(?m)^\['+[regex]::Escape($Section)+'\]\r?$'))
  if($sections.Count -gt 1){throw "Duplicate display settings section: $Section"}
  if($sections.Count -eq 0){
   if($Text -and -not $Text.EndsWith("`n")){$Text+=$newline}
   $Text+='['+$Section+']'+$newline;$start=$Text.Length;$length=0
  }else{
   $start=$sections[0].Index+$sections[0].Length
   if($start -lt $Text.Length -and $Text[$start] -eq "`n"){$start++}
   $next=[regex]::Match($Text.Substring($start),'(?m)^\[')
   $length=if($next.Success){$next.Index}else{$Text.Length-$start}
  }
 }
 $body=$Text.Substring($start,$length)
 foreach($key in $Values.Keys){
  $pattern='(?m)^'+[regex]::Escape($key)+'=[^\r\n]*'
  $entries=[regex]::Matches($body,$pattern)
  if($entries.Count -gt 1){throw "Duplicate display setting: $key"}
  $line=$key+'='+$Values[$key]
  if($entries.Count -eq 1){$entry=$entries[0];$body=$body.Remove($entry.Index,$entry.Length).Insert($entry.Index,$line)}
  else{if($body -and -not $body.EndsWith("`n")){$body+=$newline};$body+=$line+$newline}
 }
 # A section header at EOF needs a newline before its first key.
 if($Section -and $start -gt 0 -and $Text[$start-1] -ne "`n"){$body=$newline+$body}
 return $Text.Remove($start,$length).Insert($start,$body)
}
# Read-only compatibility with a separately installed renderer; no preset writes.
function Test-ExternalRenderer {
 $journal=Join-Path $env:LOCALAPPDATA 'CVRLink/install.json'
 if(-not [IO.File]::Exists($journal)){return $false}
 $bin=(Get-Content -Raw -LiteralPath $journal | ConvertFrom-Json).game
 $path=Join-Path $bin 'dlss5-bridge.cfg'
 if(-not [IO.File]::Exists($path)){return $false}
 $text=[IO.File]::ReadAllText($path)
 if($text.Length -gt 65536){throw 'External renderer settings are too large.'}
 $values=@{}
 foreach($key in 'synth','synth_after'){
  $entries=[regex]::Matches($text,('(?m)^'+$key+'=([^\r\n]+)\r?$'))
  if($entries.Count -ne 1){throw 'Cannot read the external renderer state. Close the game before resizing.'}
  $values[$key]=$entries[0].Groups[1].Value
 }
 return $values.synth -ne '0' -or $values.synth_after -ne '0'
}
# Embedded in the helper; display changes have a separate confirmation transaction.
$displayFields=@('token','until','action','vsync','fps','mode','width','height')
$displayGameSettingsPath=Join-Path $env:LOCALAPPDATA 'Contractors_UE4_22/Saved/Config/WindowsNoEditor/GameUserSettings.ini'
function Protect-DisplayGameSettings {
 $backup=Join-Path $directory 'display-game-original.ini'
 if(-not [IO.File]::Exists($backup)){
  if(-not [IO.File]::Exists($displayGameSettingsPath)){throw 'Start Contractors once before changing its display settings.'}
  [IO.File]::Copy($displayGameSettingsPath,$backup)
 }
}
function Restore-DisplayGameSettings {
 $backup=Join-Path $directory 'display-game-original.ini'
 if(-not [IO.File]::Exists($backup) -or (Get-Process Contractors,Contractors_UE4_22_Steam-Win64-Shipping -ErrorAction SilentlyContinue)){return}
 $original=[IO.File]::ReadAllText($backup);$current=[IO.File]::ReadAllText($displayGameSettingsPath)
 $section='/Script/Engine.GameUserSettings'
 $body=[regex]::Match($original,'(?ms)^\[/Script/Engine.GameUserSettings\]\r?\n(.*?)(?=^\[|\z)').Groups[1].Value
 $values=@{}
 foreach($key in 'bUseVSync','FrameRateLimit','ResolutionSizeX','ResolutionSizeY','FullscreenMode','LastConfirmedFullscreenMode','PreferredFullscreenMode','LastUserConfirmedResolutionSizeX','LastUserConfirmedResolutionSizeY'){
  $found=[regex]::Matches($body,('(?m)^'+$key+'=([^\r\n]*)'))
  if($found.Count -ne 1){throw 'The original display settings backup is incomplete.'}
  $values[$key]=$found[0].Groups[1].Value
 }
 $restored=Set-DisplayIniText $current $section $values
 if($restored -cne $current){Write-Atomic $displayGameSettingsPath $restored}
 Remove-Item -LiteralPath $backup
}
function Read-DisplaySettings([string]$Text){
 if($Text.Length -gt 1024){throw 'Display request is too large.'}
 $value=@{};$ranges=@{token=@(1,9000000000000000);until=@(0,4102444800);vsync=@(0,1);fps=@(0,500);mode=@(1,2);width=@(640,7680);height=@(480,4320)}
 foreach($line in ($Text -split '\r?\n' | Where-Object {$_ -ne ''})){
  if($line -cnotmatch '^([a-z]+)=([a-z0-9]+)$' -or $value.ContainsKey($Matches[1])){throw 'Bad or repeated display entry.'}
  $name=$Matches[1];$raw=$Matches[2]
  if($name -ceq 'action'){
   if($raw -cnotin @('apply','keep','revert')){throw 'Bad display action.'};$value[$name]=$raw
  }elseif($ranges.ContainsKey($name)){
   $n=0L;if(-not [long]::TryParse($raw,[ref]$n) -or $n -lt $ranges[$name][0] -or $n -gt $ranges[$name][1]){throw ('Bad display value: '+$name)}
   $value[$name]=$n
  }else{throw 'Unknown display entry.'}
 }
 foreach($name in $displayFields){if(-not $value.ContainsKey($name)){throw ('Missing display entry: '+$name)}}
 if($value.fps -gt 0 -and $value.fps -lt 20){throw 'FPS must be Unlimited (0), or 20 to 500.'}
 return $value
}
function Encode-DisplaySettings($Value){
 $text=(($displayFields | ForEach-Object {$_+'='+$Value[$_]}) -join "`n")+"`n"
 $null=Read-DisplaySettings $text;return $text
}
function Get-DisplayLaunchFlags([string]$ProfileFolder=$directory){
 $choice=$null
 foreach($name in 'display-request.ini','display.ini'){
  $path=Join-Path $ProfileFolder $name
  if(-not [IO.File]::Exists($path)){continue}
  $value=Read-DisplaySettings ([IO.File]::ReadAllText($path))
  if($value.action -eq 'apply' -and ($value.until -eq 0 -or $value.until -ge [DateTimeOffset]::UtcNow.ToUnixTimeSeconds())){$choice=$value;break}
 }
 if(-not $choice){return ''}
 $bounds=[Windows.Forms.Screen]::PrimaryScreen.Bounds
 if($choice.mode -eq 1){$choice.width=$bounds.Width;$choice.height=$bounds.Height}
 if($choice.width -gt $bounds.Width -or $choice.height -gt $bounds.Height){throw 'Choose a resolution that fits this monitor.'}
 return (' -ResX='+$choice.width+' -ResY='+$choice.height)
}
function Assert-DisplayLiveChange($Choice,$Readback,[bool]$DlssOn){
 if(-not $DlssOn){return}
 if(-not $Readback -or [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-$script:displayStamp -gt 4){throw 'Wait for the game display readback before applying changes.'}
 if($Choice.mode -ne [int]$Readback.mode -or $Choice.width -ne [int]$Readback.width -or $Choice.height -ne [int]$Readback.height){
  throw 'An external neural renderer is on. Close Contractors, apply the new resolution, then use Save and start Contractors in Experimental. V-Sync and FPS can change during play.'
 }
}
function Get-DisplayChoice {
 $size=([string]$displayResolution.SelectedItem) -split ' x '
 return @{token=[DateTimeOffset]::UtcNow.ToUnixTimeMilliseconds();until=0;action='apply';vsync=[int]$displayVsync.Checked;fps=[int]$displayFps.Value;mode=($displayMode.SelectedIndex+1);width=[int]$size[0];height=[int]$size[1]}
}
function Show-DisplayChoice($Value){
 $displayVsync.Checked=$Value.vsync -eq 1;$displayFps.Value=$Value.fps;$displayMode.SelectedIndex=[int]$Value.mode-1
 $size=([string]$Value.width+' x '+$Value.height)
 if($displayResolution.Items.Contains($size)){$displayResolution.SelectedItem=$size}
}
function Send-DisplayAction([string]$Action){
 if(-not $script:displayRequest){return}
 $script:displayRequest.action=$Action;$script:displayRequest.until=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+30
 Write-Atomic (Join-Path $directory 'display-request.ini') (Encode-DisplaySettings $script:displayRequest)
}
function Close-DisplayConfirm {
 if($script:displayConfirm){
  $script:closingDisplayConfirm=$true
  $script:displayConfirm.Close();$script:displayConfirm.Dispose();$script:displayConfirm=$null
  $script:closingDisplayConfirm=$false
 }
}
function Show-DisplayConfirm {
 if($script:displayConfirm){return}
 $dialog=[Windows.Forms.Form]::new();$dialog.Text='Keep this display mode?';$dialog.ClientSize=[Drawing.Size]::new(410,140)
 $dialog.FormBorderStyle='FixedDialog';$dialog.StartPosition='CenterParent';$dialog.MaximizeBox=$false;$dialog.MinimizeBox=$false;$dialog.TopMost=$true
 $dialog.BackColor=$form.BackColor;$dialog.ForeColor=$form.ForeColor;$dialog.Font=$form.Font
 $script:displayCountdown=[Windows.Forms.Label]::new();$script:displayCountdown.Location=[Drawing.Point]::new(18,18);$script:displayCountdown.Size=[Drawing.Size]::new(375,50)
 $dialog.Controls.Add($script:displayCountdown)
 foreach($entry in @(@('Keep','keep',18),@('Revert','revert',210))){
  $button=[Windows.Forms.Button]::new();$button.Text=$entry[0];$button.Tag=$entry[1];$button.AccessibleName=$entry[0]+' display mode'
  $button.Location=[Drawing.Point]::new($entry[2],85);$button.Size=[Drawing.Size]::new(175,35);$button.FlatStyle='Flat'
  $button.Add_Click({param($sender) try{Send-DisplayAction ([string]$sender.Tag);Close-DisplayConfirm}catch{$displayStatus.Text=$_.Exception.Message}})
  $dialog.Controls.Add($button)
 }
 $dialog.Add_FormClosing({if(-not $script:closingDisplayConfirm){try{Send-DisplayAction 'revert'}catch{$displayStatus.Text=$_.Exception.Message}}})
 $script:displayConfirm=$dialog;$dialog.Show($form)
}
function Apply-DisplaySettings {
 $choice=Get-DisplayChoice;$text=Encode-DisplaySettings $choice
 if(Get-Process Contractors,Contractors_UE4_22_Steam-Win64-Shipping -ErrorAction SilentlyContinue){
  $dlssOn=Test-ExternalRenderer
  Assert-DisplayLiveChange $choice $script:displayReadback $dlssOn
  $choice.until=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+30;$text=Encode-DisplaySettings $choice
 }
 Protect-DisplayGameSettings
 Write-Atomic (Join-Path $directory 'display-request.ini') $text
 $script:displayRequest=$choice;$script:displayNotice=$null;$displayApply.Enabled=$false
 $displayStatus.Text=if($choice.until -eq 0){'Saved for the next headset-free start. Keep CVR Link enabled.'}else{'Waiting for Contractors to apply the display change.'}
}
function Refresh-Display {
 try{
  Restore-DisplayGameSettings
  if(([IO.File]::Exists((Join-Path $directory 'display.ini')) -or $script:displayRequest) -and (Get-Process Contractors,Contractors_UE4_22_Steam-Win64-Shipping -ErrorAction SilentlyContinue)){Protect-DisplayGameSettings}
 }catch{$displayStatus.Text='Could not protect the original game display settings. '+$_.Exception.Message;return}
 if($script:displayRequest -and $script:displayRequest.until -ne 0 -and [DateTimeOffset]::UtcNow.ToUnixTimeSeconds() -gt $script:displayRequest.until+2){
  Close-DisplayConfirm;$script:displayRequest=$null;$displayApply.Enabled=$true
  $displayStatus.Text='Display request expired. Enable the link in a headset-free game and try again.'
 }
 try{
  $parts=[IO.File]::ReadAllText((Join-Path $directory 'display-status.txt')).Trim() -split '\|';$stamp=0L
  if(-not [long]::TryParse($parts[0],[ref]$stamp)){return}
  $age=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-$stamp
  if($age -lt 0 -or $age -gt 4){$displayStatus.Text='Waiting for a headset-free game. Saved display choices are kept.';return}
  $readback=@{};foreach($part in $parts[1..($parts.Length-1)]){if($part -match '^([a-z_]+)=(.*)$'){$readback[$Matches[1]]=$Matches[2]}}
  $script:displayReadback=$readback;$script:displayStamp=$stamp
  $displayText=if($script:displayNotice){$script:displayNotice}elseif($script:displayRequest -and $readback.token -ne [string]$script:displayRequest.token){'Waiting for Contractors to apply the display change.'}else{$readback.message}
  if($readback.ContainsKey('actual_fps')){
   $cap=if([double]$readback.actual_fps -eq 0){'Unlimited'}else{$readback.actual_fps+' FPS'}
   $sync=if($readback.actual_vsync -eq '1'){'On'}else{'Off'}
   $modeText=if($readback.mode -eq '1'){'Borderless'}else{'Windowed'}
   $displayText+="`nGame readback: V-Sync $sync | $cap`n$modeText | $($readback.width) x $($readback.height)"
  }
  # One text change per new readback. Intermediate one-line text made the
  # autosized panel shrink and grow on every timer tick, moving FOV too.
  if($displayStatus.Text -ne $displayText){$displayStatus.Text=$displayText}
  if($script:displayRequest -and $readback.token -eq [string]$script:displayRequest.token){
   if($readback.state -eq 'confirm'){
    if($script:displayRequest.action -eq 'apply'){Show-DisplayConfirm}
    if($script:displayConfirm){$remaining=[Math]::Max(0,[long]$readback.deadline-[DateTimeOffset]::UtcNow.ToUnixTimeSeconds());$script:displayCountdown.Text="Keep this picture?`nThe previous mode returns in $remaining seconds."}
   }elseif($readback.state -in @('applied','reverted','error','paused')){
    Close-DisplayConfirm
    if($readback.state -eq 'applied'){
     $saved=$script:displayRequest.Clone();$saved.action='apply';$saved.until=0
     foreach($name in 'width','height','mode','vsync','fps'){$saved[$name]=[long]$readback[$name]}
     Write-Atomic (Join-Path $directory 'display.ini') (Encode-DisplaySettings $saved);Show-DisplayChoice $saved
    }else{
     $profile=Join-Path $directory 'display.ini'
     if(Test-Path -LiteralPath $profile){Show-DisplayChoice (Read-DisplaySettings ([IO.File]::ReadAllText($profile)))}
    }
    Remove-Item -LiteralPath (Join-Path $directory 'display-request.ini') -ErrorAction SilentlyContinue
    $script:displayRequest=$null;$displayApply.Enabled=$true
   }
  }
 }catch{$displayStatus.Text='Waiting for Contractors to report its display settings.'}
}
$displayPanel=[Windows.Forms.TableLayoutPanel]::new();$displayPanel.AutoSize=$true;$displayPanel.Dock='Top';$displayPanel.ColumnCount=2;$displayPanel.Margin=[Windows.Forms.Padding]::new(0,24,0,28)
$displayPanel.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',50))|Out-Null;$displayPanel.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',50))|Out-Null
$displayTitle=[Windows.Forms.Label]::new();$displayTitle.Text='PC display';$displayTitle.AutoSize=$true;$displayTitle.Font=[Drawing.Font]::new($form.Font,[Drawing.FontStyle]::Bold)
$displayPanel.Controls.Add($displayTitle,0,0);$displayPanel.SetColumnSpan($displayTitle,2)
$displayVsync=[Windows.Forms.CheckBox]::new();$displayVsync.Text='V-Sync';$displayVsync.Checked=$true;$displayVsync.AutoSize=$true;$displayVsync.AccessibleName='V-Sync'
$displayMode=[Windows.Forms.ComboBox]::new();$displayMode.DropDownStyle='DropDownList';$displayMode.Dock='Fill';$displayMode.AccessibleName='Display mode';$displayMode.Items.AddRange(@('Borderless','Windowed'))
$displayResolution=[Windows.Forms.ComboBox]::new();$displayResolution.DropDownStyle='DropDownList';$displayResolution.Dock='Fill';$displayResolution.AccessibleName='Game resolution'
$displayFps=[Windows.Forms.NumericUpDown]::new();$displayFps.Minimum=0;$displayFps.Maximum=500;$displayFps.Increment=5;$displayFps.Dock='Fill';$displayFps.AccessibleName='FPS limit (0 is Unlimited)'
$displayPanel.Controls.Add($displayVsync,0,1);$displayPanel.SetColumnSpan($displayVsync,2)
foreach($row in @(@('Display mode',$displayMode,2),@('Resolution',$displayResolution,3),@('FPS limit (0 = Unlimited)',$displayFps,4))){
 $label=[Windows.Forms.Label]::new();$label.Text=$row[0];$label.AutoSize=$true;$label.Anchor='Left'
 $displayPanel.Controls.Add($label,0,$row[2]);$displayPanel.Controls.Add($row[1],1,$row[2])
}
$displayMode.Add_SelectedIndexChanged({
 $prior=[string]$displayResolution.SelectedItem;$displayResolution.Items.Clear();$bounds=[Windows.Forms.Screen]::PrimaryScreen.Bounds
 if($displayMode.SelectedIndex -eq 0){[void]$displayResolution.Items.Add(($bounds.Width.ToString()+' x '+$bounds.Height));$displayResolution.Enabled=$false}
 else{
  $displayResolution.Enabled=$true
  foreach($size in @('640 x 480','800 x 600','1024 x 768','1152 x 720','1280 x 720','1280 x 800','1600 x 900','1920 x 1080','2560 x 1440','3840 x 2160')){
   $xy=$size -split ' x ';if([int]$xy[0] -le $bounds.Width-16 -and [int]$xy[1] -le $bounds.Height-64){[void]$displayResolution.Items.Add($size)}
  }
 }
 if($displayResolution.Items.Contains($prior)){$displayResolution.SelectedItem=$prior}else{$displayResolution.SelectedIndex=$displayResolution.Items.Count-1}
})
$displayMode.SelectedIndex=0
$displayApply=[Windows.Forms.Button]::new();$displayApply.Text='Apply display settings';$displayApply.AccessibleName=$displayApply.Text;$displayApply.Width=200;$displayApply.Height=35;$displayApply.FlatStyle='Flat';$displayApply.BackColor=[Drawing.Color]::FromArgb(155,12,24)
$displayApply.Add_Click({try{Apply-DisplaySettings}catch{$script:displayNotice=$_.Exception.Message;$displayStatus.Text=$script:displayNotice}})
$displayPanel.Controls.Add($displayApply,0,5);$displayPanel.SetColumnSpan($displayApply,2)
$displayStatus=[Windows.Forms.Label]::new();$displayStatus.AutoSize=$true;$displayStatus.MaximumSize=[Drawing.Size]::new(470,0);$displayStatus.Text='Choose your PC display settings, then click Apply display settings.'
$displayPanel.Controls.Add($displayStatus,0,6);$displayPanel.SetColumnSpan($displayStatus,2)
$displayHint=[Windows.Forms.Label]::new();$displayHint.AutoSize=$true;$displayHint.MaximumSize=[Drawing.Size]::new(470,0);$displayHint.Margin=[Windows.Forms.Padding]::new(0,10,0,12)
$displayHint.Text="For headset-free play. Borderless uses your desktop resolution.`nWith an external neural renderer on, close the game before changing resolution. Then use the start button in Experimental.`nKeep a new display mode within 15 seconds, or it returns to the old mode.`nAn FPS limit sets a maximum; it cannot raise a low frame rate."
$displayPanel.Controls.Add($displayHint,0,7);$displayPanel.SetColumnSpan($displayHint,2)
$uiRows.Controls.Add($displayPanel,0,4);$uiRows.SetColumnSpan($displayPanel,2);$uiTab.AutoScroll=$true
$script:displayRequest=$null;$script:displayConfirm=$null;$script:closingDisplayConfirm=$false
$script:displayReadback=$null;$script:displayStamp=0L
$script:displayNotice=$null
if(-not $Check){
 try{
  Restore-DisplayGameSettings
  $profile=Join-Path $directory 'display.ini';$request=Join-Path $directory 'display-request.ini'
  if(Test-Path -LiteralPath $profile){Show-DisplayChoice (Read-DisplaySettings ([IO.File]::ReadAllText($profile)))}
  if(Test-Path -LiteralPath $request){
   $savedRequest=Read-DisplaySettings ([IO.File]::ReadAllText($request))
   if($savedRequest.until -eq 0 -or $savedRequest.until -ge [DateTimeOffset]::UtcNow.ToUnixTimeSeconds()){$script:displayRequest=$savedRequest;Show-DisplayChoice $savedRequest}
  }
 }catch{$displayStatus.Text='Could not read display choices. '+$_.Exception.Message}
}
