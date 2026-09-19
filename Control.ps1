param([ValidateRange(0,3600)][int]$Seconds=0, [switch]$Enable, [switch]$Check)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
Add-Type -TypeDefinition @"
using System.Runtime.InteropServices;
public static class CVRLinkKeys {
 [DllImport("user32.dll")] public static extern short GetAsyncKeyState(int key);
 [DllImport("user32.dll")] public static extern bool ShowWindow(System.IntPtr window,int mode);
}
"@
[Windows.Forms.Application]::EnableVisualStyles()
$directory=Join-Path $env:LOCALAPPDATA 'ContractorsFlatscreen'
$settingsPath=Join-Path $directory 'settings.ini'
$invariant=[Globalization.CultureInfo]::InvariantCulture
$actions=[ordered]@{
 W='Move forward'; S='Move back'; A='Move left'; D='Move right'; Tab='Game menu'
 E='Interact'; G='Drop'; One='Main gun / cycle'; Two='Sidearm'; Three='Gadget 1'
 Four='Gadget 2'; Five='Gadget 3'; V='Melee'; LeftMouseButton='Fire / use'
 RightMouseButton='Aim'; R='Reload'; B='Fire mode'; LeftShift='Sprint'
 LeftControl='Crouch'; C='Crouch (second key)'
 MiddleMouseButton='Turn Claymore'; LeftAlt='Tilt Claymore'; RightAlt='Tilt (second key)'
 F9='Pointer / mouse look'
}
$keyCodes=[ordered]@{LeftMouseButton=1;RightMouseButton=2;MiddleMouseButton=4;ThumbMouseButton=5;ThumbMouseButton2=6;BackSpace=8;Tab=9;Enter=13;SpaceBar=32;PageUp=33;PageDown=34;End=35;Home=36;Left=37;Up=38;Right=39;Down=40;Insert=45;Delete=46;LeftShift=160;RightShift=161;LeftControl=162;RightControl=163;LeftAlt=164;RightAlt=165}
foreach($code in 65..90){$keyCodes[[string][char]$code]=$code}
$digits='Zero','One','Two','Three','Four','Five','Six','Seven','Eight','Nine'
foreach($index in 0..9){$keyCodes[$digits[$index]]=48+$index}
foreach($index in 1..12){if($index -notin 7,8){$keyCodes['F'+$index]=111+$index}}
$bindings=[ordered]@{};foreach($key in $actions.Keys){$bindings[$key]=$key}
function Format-Key([string]$Key){
 if($Key -in $digits){return [string][array]::IndexOf($digits,$Key)}
 return ($Key -creplace '([a-z])([A-Z])','$1 $2')
}
function Start-Contractors([bool]$HeadsetFree){
 if(Get-Process Contractors,Contractors_UE4_22_Steam-Win64-Shipping -ErrorAction SilentlyContinue){throw 'Contractors is already running. Close it normally before starting a new mode.'}
 Restore-DisplayGameSettings
 if($HeadsetFree){
  $steamExe=(Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam').SteamExe
  if(-not $steamExe -or -not(Test-Path -LiteralPath $steamExe -PathType Leaf)){throw 'Open Steam and sign in before starting Contractors.'}
  $displayFlags=Get-DisplayLaunchFlags
  if($displayFlags){Protect-DisplayGameSettings}
  Start-Process -FilePath $steamExe -ArgumentList ('-applaunch 963930 -nohmd -windowed'+$displayFlags) -WindowStyle Hidden
 }else{Start-Process -FilePath 'steam://rungameid/963930'}
}
function Encode-Settings([decimal]$Mouse,[decimal]$Aim,$Keys,[decimal]$Scale=1,[decimal]$Opacity=1,[bool]$ExperimentalStart=$false,[decimal]$Fov=80){
 if($Mouse -lt .1 -or $Mouse -gt 10 -or $Aim -lt .1 -or $Aim -gt 10){throw 'Mouse and aim speeds must be from 0.1 to 10.'}
 if($Scale -lt .5 -or $Scale -gt 1.5 -or $Opacity -lt .1 -or $Opacity -gt 1){throw 'HUD size must be 50% to 150%, and transparency 0% to 90%.'}
 if($Fov -lt 80 -or $Fov -gt 120){throw 'Field of view must be from 80 to 120 degrees.'}
 $used=@{}
 $lines=@(('mouse='+$Mouse.ToString('0.##',$invariant)),('aim='+$Aim.ToString('0.##',$invariant)),('fov='+$Fov.ToString('0.##',$invariant)),('ui_scale='+$Scale.ToString('0.##',$invariant)),('ui_opacity='+$Opacity.ToString('0.##',$invariant)),('experimental_start='+[int]$ExperimentalStart))
 foreach($action in $actions.Keys){
  $key=[string]$Keys[$action]
  if($key -cnotin @($keyCodes.Keys)){throw 'Choose a keyboard or mouse key. F7, F8 and Escape stay fixed.'}
  if($used.ContainsKey($key)){throw ('Two actions use '+(Format-Key $key)+'. Change one before saving.')}
  $used[$key]=$true;$lines+=($action+'='+$key)
 }
 return (($lines -join "`n")+"`n")
}
function Read-Settings([string]$Text){
 if($Text.Length -gt 8192){throw 'Settings file is too large.'}
 $keys=[ordered]@{};foreach($key in $actions.Keys){$keys[$key]=$key}
 $mouse=[decimal]2.5;$aim=[decimal]1;$fov=[decimal]80;$scale=[decimal]1;$opacity=[decimal]1;$experimentalStart=$false;$seen=@{}
 foreach($line in ($Text -split '\r?\n' | Where-Object {$_ -ne ''})){
  if($line -cnotmatch '^([\w_]+)=([\w_.]+)$' -or $seen.ContainsKey($Matches[1])){throw 'Settings file has a bad or repeated entry.'}
  $name=$Matches[1];$value=$Matches[2];$seen[$name]=$true
  if($name -ceq 'mouse'){$mouse=[decimal]::Parse($value,$invariant)}
  elseif($name -ceq 'aim'){$aim=[decimal]::Parse($value,$invariant)}
  elseif($name -ceq 'fov'){$fov=[decimal]::Parse($value,$invariant)}
  elseif($name -ceq 'ui_scale'){$scale=[decimal]::Parse($value,$invariant)}
  elseif($name -ceq 'ui_opacity'){$opacity=[decimal]::Parse($value,$invariant)}
  elseif($name -ceq 'experimental_start'){if($value -cnotin @('0','1')){throw 'Experimental start must be 0 or 1.'};$experimentalStart=$value -ceq '1'}
  elseif($name -ceq 'F6'){if($value -cnotin @($keyCodes.Keys)){throw 'Bad retired scope key.'}}
  elseif($name -cin @($keys.Keys)){$keys[$name]=$value}else{throw 'Settings file has an unknown entry.'}
 }
 if(-not $seen.ContainsKey('F9')){
  $used=@{};foreach($action in $keys.Keys){if($action -ne 'F9'){$used[$keys[$action]]=$true}}
  foreach($key in @('F9','F10','F11','F12','F1','F2','F3','F4','F5','F6','Home','End','Insert','Zero','One','Two','Three','Four','Five','Six','Seven','Eight','Nine','Up','Down','Left','Right')){
   if(-not $used.ContainsKey($key)){$keys.F9=$key;break}
  }
 }
 $null=Encode-Settings $mouse $aim $keys $scale $opacity $experimentalStart $fov
 return @{Mouse=$mouse;Aim=$aim;Fov=$fov;Keys=$keys;Scale=$scale;Opacity=$opacity;ExperimentalStart=$experimentalStart}
}
function Write-Atomic([string]$Path,[string]$Text){
 $temp=$Path+'.tmp';[IO.File]::WriteAllText($temp,$Text,[Text.UTF8Encoding]::new($false))
 if(Test-Path -LiteralPath $Path){[IO.File]::Replace($temp,$Path,$Path+'.bak')}else{[IO.File]::Move($temp,$Path)}
}
# Embedded update checks. Download metadata only from the public release API.
function Read-LinkRelease([string]$Text,[version]$CurrentVersion){
 if($Text.Length -gt 1048576){throw 'Update information is too large.'}
 $release=$Text|ConvertFrom-Json
 if($release.draft -ne $false -or $release.prerelease -ne $false -or $release.tag_name -cnotmatch '^v(0|[1-9][0-9]{0,4})\.(0|[1-9][0-9]{0,4})\.(0|[1-9][0-9]{0,4})$'){throw 'The update is not a stable CVR Link release.'}
 $version=[version]$release.tag_name.Substring(1)
 $base='https://github.com/geraldjove/CVR-Link/releases/'
 if($release.html_url -cne ($base+'tag/'+$release.tag_name)){throw 'Unexpected release page.'}
 $assets=@($release.assets|Where-Object {$_.name -ceq 'CVRLink.exe'})
 if($assets.Count -ne 1){throw 'The release must have one CVR Link installer.'}
 $asset=$assets[0]
 if($asset.state -cne 'uploaded' -or $asset.browser_download_url -cne ($base+'download/'+$release.tag_name+'/CVRLink.exe')){throw 'Unexpected installer download.'}
 if($asset.size -lt 1 -or $asset.size -gt 33554432 -or $asset.digest -cnotmatch '^sha256:[a-f0-9]{64}$'){throw 'The installer size or checksum is missing.'}
 return [pscustomobject]@{Version=$version;Newer=($version -gt $CurrentVersion);Url=$asset.browser_download_url;Sha256=$asset.digest.Substring(7);Size=[long]$asset.size}
}
function Assert-LinkUpdateClosed {
 if(Get-Process Contractors,Contractors_UE4_22_Steam-Win64-Shipping -ErrorAction SilentlyContinue){throw 'Close Contractors normally before installing an update.'}
}
function Save-LinkUpdate([byte[]]$Bytes,$Release,[string]$Folder){
 if($Bytes.Length -ne $Release.Size){throw 'The installer download is incomplete. Try again.'}
 $sha=[Security.Cryptography.SHA256]::Create()
 try{$hash=[BitConverter]::ToString($sha.ComputeHash($Bytes)).Replace('-','').ToLowerInvariant()}finally{$sha.Dispose()}
 if($hash -cne $Release.Sha256){throw 'The installer checksum did not match. Try again.'}
 $folderPath=[IO.Path]::GetFullPath($Folder)
 for($parent=$folderPath;$parent;$parent=[IO.Path]::GetDirectoryName($parent)){
  if([IO.Directory]::Exists($parent) -and ([IO.File]::GetAttributes($parent) -band [IO.FileAttributes]::ReparsePoint)){throw 'An update folder cannot be a link or junction.'}
 }
 [IO.Directory]::CreateDirectory($folderPath)|Out-Null
 $path=Join-Path $folderPath 'CVRLink.exe'
 # Each attempt gets its own folder; never overwrite an existing executable.
 $stream=[IO.File]::Open($path,[IO.FileMode]::CreateNew,[IO.FileAccess]::Write,[IO.FileShare]::None)
 try{$stream.Write($Bytes,0,$Bytes.Length)}finally{$stream.Dispose()}
 if([Reflection.AssemblyName]::GetAssemblyName($path).Version.ToString(3) -cne $Release.Version.ToString(3)){throw 'The installer version did not match the release.'}
 return $path
}
function Close-LinkUpdateRequest {
 if($script:linkUpdate.Client){$script:linkUpdate.Client.CancelPendingRequests();$script:linkUpdate.Client.Dispose()}
 $script:linkUpdate.Client=$null;$script:linkUpdate.Task=$null
}
function Start-LinkUpdateRequest([string]$Kind,[string]$Url){
 Add-Type -AssemblyName System.Net.Http
 $client=[Net.Http.HttpClient]::new()
 $client.Timeout=[TimeSpan]::FromSeconds($(if($Kind -eq 'check'){12}else{120}))
 $client.MaxResponseContentBufferSize=if($Kind -eq 'check'){1048576}else{33554432}
 $client.DefaultRequestHeaders.UserAgent.ParseAdd('CVRLink-Updater')
 $client.DefaultRequestHeaders.Accept.ParseAdd('application/vnd.github+json')
 $script:linkUpdate.Client=$client;$script:linkUpdate.Kind=$Kind
 $script:linkUpdate.Task=$client.GetByteArrayAsync($Url)
}
function Start-LinkUpdateCheck {
 if($script:linkUpdate.Task){return}
 $script:linkUpdate.Release=$null;$script:linkUpdate.ReadyFile=$null
 $updateInstall.Enabled=$false;$updateCheck.Enabled=$false
 $updateStatus.Text='Checking for updates...';$updateTab.Text='Updates'
 try{Start-LinkUpdateRequest 'check' 'https://api.github.com/repos/geraldjove/CVR-Link/releases/latest'}
 catch{Close-LinkUpdateRequest;$updateCheck.Enabled=$true;$updateStatus.Text='Could not check for updates. Check your connection and try again.'}
}
function Complete-LinkUpdateInstall {
 if($script:linkUpdate.PreviewOnly){throw 'This Dev preview does not install public releases.'}
 Assert-LinkUpdateClosed
 Save-Settings
 $script:pendingLinkUpdate=[pscustomobject]@{Path=$script:linkUpdate.ReadyFile;Sha256=$script:linkUpdate.Release.Sha256}
 $form.Close()
}
function Start-LinkUpdateInstall {
 try{
  if($script:linkUpdate.PreviewOnly){throw 'This Dev preview does not install public releases.'}
  if($script:linkUpdate.Task -or -not $script:linkUpdate.Release.Newer){return}
  Assert-LinkUpdateClosed
  if($script:linkUpdate.ReadyFile){Complete-LinkUpdateInstall;return}
  $updateInstall.Enabled=$false;$updateCheck.Enabled=$false
  $updateStatus.Text='Downloading and checking the update...'
  Start-LinkUpdateRequest 'download' $script:linkUpdate.Release.Url
 }catch{Close-LinkUpdateRequest;$updateCheck.Enabled=$true;$updateStatus.Text=$_.Exception.Message}
}
function Poll-LinkUpdate {
 if(-not $script:linkUpdate.Task -or -not $script:linkUpdate.Task.IsCompleted){return}
 $kind=$script:linkUpdate.Kind
 try{
  $bytes=$script:linkUpdate.Task.GetAwaiter().GetResult()
  Close-LinkUpdateRequest
  if($kind -eq 'check'){
   $release=Read-LinkRelease ([Text.Encoding]::UTF8.GetString($bytes)) $script:linkUpdate.CurrentVersion
   $script:linkUpdate.Release=$release
   if($script:linkUpdate.PreviewOnly){$updateStatus.Text='Latest public release: '+$release.Version+'. This Dev preview keeps your private build.'}
   elseif($release.Newer){$updateStatus.Text='CVR Link '+$release.Version+' is available.';$updateInstall.Enabled=$true;$updateTab.Text='Updates (new)'}
   else{$updateStatus.Text='You are up to date.'}
   $updateChecked.Text='Last checked: '+(Get-Date -Format 'g')
  }else{
   $folder=Join-Path ([IO.Path]::GetTempPath()) ('CVRLink-update-'+[guid]::NewGuid().ToString('N'))
   $script:linkUpdate.ReadyFile=Save-LinkUpdate $bytes $script:linkUpdate.Release $folder
   $updateInstall.Enabled=$true
   $updateStatus.Text='Update verified. Close Contractors, then click Install update.'
   Complete-LinkUpdateInstall
  }
 }catch{
  Close-LinkUpdateRequest
  $updateStatus.Text=if($kind -eq 'check'){'Could not check for updates. Check your connection and try again.'}else{$_.Exception.Message}
  $updateInstall.Enabled=(-not $script:linkUpdate.PreviewOnly -and $script:linkUpdate.Release.Newer)
 }finally{$updateCheck.Enabled=$true}
}

$form=[Windows.Forms.Form]::new();$form.Text='CVR Link'
$iconPath=Join-Path $PSScriptRoot 'CVRLink.ico'
if(-not(Test-Path -LiteralPath $iconPath)){$iconPath=Join-Path $PSScriptRoot 'release/CVRLink.ico'}
$form.Icon=[Drawing.Icon]::new($iconPath)
$form.ClientSize=[Drawing.Size]::new(620,870);$form.MinimumSize=[Drawing.Size]::new(560,650)
$form.StartPosition='CenterScreen';$form.BackColor=[Drawing.Color]::FromArgb(18,18,20)
$form.ForeColor=[Drawing.Color]::White;$form.Font=[Drawing.Font]::new('Segoe UI',10)
$form.Add_Shown({[void][CVRLinkKeys]::ShowWindow($form.Handle,5);$form.Activate()})
$layout=[Windows.Forms.TableLayoutPanel]::new();$layout.Dock='Fill';$layout.ColumnCount=1;$layout.RowCount=6
foreach($height in 115,125,0,52,86,50){$style=[Windows.Forms.RowStyle]::new();if($height -eq 0){$style.SizeType='Percent';$style.Height=100}else{$style.SizeType='Absolute';$style.Height=$height};[void]$layout.RowStyles.Add($style)}
$form.Controls.Add($layout)
$header=[Windows.Forms.Panel]::new();$header.Dock='Fill';$header.Margin=[Windows.Forms.Padding]::new(0)
$header.Add_Paint({param($sender,$event) $brush=[Drawing.Drawing2D.LinearGradientBrush]::new($sender.ClientRectangle,[Drawing.Color]::Black,[Drawing.Color]::FromArgb(120,8,15),90);try{$event.Graphics.FillRectangle($brush,$sender.ClientRectangle)}finally{$brush.Dispose()}})
$title=[Windows.Forms.Label]::new();$title.Text='CVR Link';$title.Font=[Drawing.Font]::new('Segoe UI',26,[Drawing.FontStyle]::Bold);$title.AutoSize=$true;$title.Location=[Drawing.Point]::new(20,10);$title.BackColor=[Drawing.Color]::Transparent
$subtitle=[Windows.Forms.Label]::new();$subtitle.Text="Your keys. Your aim. Your way to play.`nChoose your mode in game, or try Experimental start.";$subtitle.AutoSize=$true;$subtitle.Location=[Drawing.Point]::new(23,62);$subtitle.BackColor=[Drawing.Color]::Transparent
$header.Controls.AddRange(@($title,$subtitle));$layout.Controls.Add($header,0,0)
$options=[Windows.Forms.TableLayoutPanel]::new();$options.Dock='Fill';$options.ColumnCount=2;$options.RowCount=3;$options.Padding=[Windows.Forms.Padding]::new(18,4,18,0)
$options.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',65))|Out-Null;$options.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',35))|Out-Null
$active=[Windows.Forms.CheckBox]::new();$active.Text='Enable CVR Link (F7)';$active.Checked=$true;$active.AutoSize=$true;$options.Controls.Add($active,0,0);$options.SetColumnSpan($active,2)
$speeds=@{}
foreach($entry in @(@('Mouse','Mouse sensitivity',2.5),@('Aim','Aim sensitivity',1))){
 $label=[Windows.Forms.Label]::new();$label.Text=$entry[1];$label.AutoSize=$true;$label.Anchor='Left'
 $input=[Windows.Forms.NumericUpDown]::new();$input.DecimalPlaces=2;$input.Minimum=.1;$input.Maximum=10;$input.Increment=.1;$input.Value=$entry[2];$input.Dock='Fill';$input.AccessibleName=$entry[1]
 $row=$speeds.Count+1;$options.Controls.Add($label,0,$row);$options.Controls.Add($input,1,$row);$speeds[$entry[0]]=$input
}
$layout.Controls.Add($options,0,1)
$scroll=[Windows.Forms.Panel]::new();$scroll.Dock='Fill';$scroll.AutoScroll=$true;$scroll.Padding=[Windows.Forms.Padding]::new(18,0,18,0)
$rows=[Windows.Forms.TableLayoutPanel]::new();$rows.Dock='Top';$rows.AutoSize=$true;$rows.ColumnCount=2;$rows.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',52))|Out-Null;$rows.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',48))|Out-Null
$keyButtons=@{};$script:capture=$null;$script:pressed=@{};$script:savedText=$null
foreach($key in $actions.Keys){
 $row=$rows.RowCount;$rows.RowCount++
 $label=[Windows.Forms.Label]::new();$label.Text=$actions[$key];$label.AutoSize=$true;$label.Anchor='Left';$rows.Controls.Add($label,0,$row)
 $button=[Windows.Forms.Button]::new();$button.Text=Format-Key $key;$button.Tag=$key;$button.Dock='Fill';$button.Height=30;$button.FlatStyle='Flat';$button.BackColor=[Drawing.Color]::FromArgb(40,40,43);$button.AccessibleName=$actions[$key]+' key'
 $button.Add_Click({param($sender) if($script:capture){$keyButtons[$script:capture].Text=Format-Key $bindings[$script:capture]};$script:capture=[string]$sender.Tag;$sender.Text='Press a key or mouse button';$message.Text='Press the new key. Escape cancels. F7 and F8 stay fixed.'})
 $rows.Controls.Add($button,1,$row);$keyButtons[$key]=$button
}
$tabs=[Windows.Forms.TabControl]::new();$tabs.Dock='Fill'
$keyTab=[Windows.Forms.TabPage]::new('Keybinds');$keyTab.BackColor=$form.BackColor;$keyTab.ForeColor=$form.ForeColor
$uiTab=[Windows.Forms.TabPage]::new('UI Settings');$uiTab.BackColor=$form.BackColor;$uiTab.ForeColor=$form.ForeColor
$experimentalTab=[Windows.Forms.TabPage]::new('Experimental');$experimentalTab.BackColor=$form.BackColor;$experimentalTab.ForeColor=$form.ForeColor
$tabs.TabPages.AddRange(@($keyTab,$uiTab,$experimentalTab));$layout.Controls.Add($tabs,0,2)
$scroll.Controls.Add($rows);$keyTab.Controls.Add($scroll)
$uiRows=[Windows.Forms.TableLayoutPanel]::new();$uiRows.Dock='Top';$uiRows.AutoSize=$true;$uiRows.ColumnCount=2;$uiRows.Padding=[Windows.Forms.Padding]::new(18)
$uiRows.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',65))|Out-Null;$uiRows.ColumnStyles.Add([Windows.Forms.ColumnStyle]::new('Percent',35))|Out-Null
$uiInputs=@{}
foreach($entry in @(@('Scale','HUD size (%)',50,150,100),@('Transparency','HUD transparency (%)',0,90,0))){
 $label=[Windows.Forms.Label]::new();$label.Text=$entry[1];$label.AutoSize=$true;$label.Anchor='Left'
 $input=[Windows.Forms.NumericUpDown]::new();$input.Minimum=$entry[2];$input.Maximum=$entry[3];$input.Value=$entry[4];$input.Increment=5;$input.Dock='Fill';$input.AccessibleName=$entry[1]
 $row=$uiInputs.Count;$uiRows.Controls.Add($label,0,$row);$uiRows.Controls.Add($input,1,$row);$uiInputs[$entry[0]]=$input
}
$fovLabel=[Windows.Forms.Label]::new();$fovLabel.Text='Field of view: 80 degrees';$fovLabel.AutoSize=$true;$fovLabel.Anchor='Left'
$fovInput=[Windows.Forms.TrackBar]::new();$fovInput.Minimum=80;$fovInput.Maximum=120;$fovInput.Value=80;$fovInput.TickFrequency=10;$fovInput.SmallChange=1;$fovInput.LargeChange=5;$fovInput.Dock='Fill';$fovInput.AccessibleName='Field of view (80 to 120 degrees)'
$fovInput.Add_ValueChanged({$fovLabel.Text='Field of view: '+$fovInput.Value+' degrees'})
$uiRows.Controls.Add($fovLabel,0,2);$uiRows.Controls.Add($fovInput,1,2)
$uiHint=[Windows.Forms.Label]::new();$uiHint.Text="Set your HUD and flatscreen view.`nFOV starts at 80 degrees. Higher values show more around you.`n0% transparency is solid. 90% is almost clear.`nClick Save settings to apply changes in the game.";$uiHint.AutoSize=$true;$uiHint.MaximumSize=[Drawing.Size]::new(490,0);$uiHint.Margin=[Windows.Forms.Padding]::new(0,20,0,0)
$uiRows.Controls.Add($uiHint,0,3);$uiRows.SetColumnSpan($uiHint,2);$uiTab.Controls.Add($uiRows)
$experimentalRows=[Windows.Forms.FlowLayoutPanel]::new();$experimentalRows.Dock='Fill';$experimentalRows.FlowDirection='TopDown';$experimentalRows.WrapContents=$false;$experimentalRows.AutoScroll=$true;$experimentalRows.Padding=[Windows.Forms.Padding]::new(18)
$experimental=[Windows.Forms.CheckBox]::new();$experimental.Text='Start in Flatscreen (experimental)';$experimental.AutoSize=$true;$experimental.AccessibleName='Start in Flatscreen (experimental)'
$experimentalHint=[Windows.Forms.Label]::new();$experimentalHint.Text="Start Contractors with a mouse and keyboard. No headset is needed when you use the start button below.`n`nPlay from the local HQ and join matches using CVRFlatscreen Standard, CVRFlatscreen WW2 or CVRFlatscreen Ninja, on any map. Other matches return you to HQ.`n`nKeep CVR Link open and enabled. Close the game before starting this mode. To play in VR, close the game, turn this option off, and start again.`n`nSave settings alone cannot change how a running game was started.";$experimentalHint.AutoSize=$true;$experimentalHint.MaximumSize=[Drawing.Size]::new(470,0);$experimentalHint.Margin=[Windows.Forms.Padding]::new(0,16,0,16)
$startGame=[Windows.Forms.Button]::new();$startGame.Text='Save and start Contractors';$startGame.Width=260;$startGame.Height=38;$startGame.FlatStyle='Flat';$startGame.BackColor=[Drawing.Color]::FromArgb(155,12,24);$startGame.AccessibleName=$startGame.Text
$startGame.Add_Click({try{Save-Settings;$active.Checked=$true;Start-Contractors $experimental.Checked;$message.Text='Starting Contractors through Steam. Keep CVR Link enabled.'}catch{$message.Text=$_.Exception.Message}})
$experimentalRows.Controls.AddRange(@($experimental,$experimentalHint,$startGame));$experimentalTab.Controls.Add($experimentalRows)
$script:linkUpdate=@{CurrentVersion=[version]'0.2.73';PreviewOnly=$false;Client=$null;Task=$null;Release=$null;ReadyFile=$null}
$script:pendingLinkUpdate=$null
$updateTab=[Windows.Forms.TabPage]::new('Updates');$updateTab.BackColor=$form.BackColor;$updateTab.ForeColor=$form.ForeColor
$tabs.TabPages.Add($updateTab)
$updateRows=[Windows.Forms.FlowLayoutPanel]::new();$updateRows.Dock='Fill';$updateRows.FlowDirection='TopDown';$updateRows.WrapContents=$false;$updateRows.AutoScroll=$true;$updateRows.Padding=[Windows.Forms.Padding]::new(18)
$updateVersion=[Windows.Forms.Label]::new();$updateVersion.AutoSize=$true;$updateVersion.Text='Installed version: '+$script:linkUpdate.CurrentVersion
$updateStatus=[Windows.Forms.Label]::new();$updateStatus.AutoSize=$true;$updateStatus.MaximumSize=[Drawing.Size]::new(470,0);$updateStatus.Margin=[Windows.Forms.Padding]::new(0,16,0,8);$updateStatus.Text='Updates are checked when the app opens.'
$updateChecked=[Windows.Forms.Label]::new();$updateChecked.AutoSize=$true;$updateChecked.Text='Not checked yet.'
$updateCheck=[Windows.Forms.Button]::new();$updateCheck.Text='Check for updates';$updateCheck.AccessibleName=$updateCheck.Text;$updateCheck.Width=240;$updateCheck.Height=36;$updateCheck.FlatStyle='Flat';$updateCheck.Margin=[Windows.Forms.Padding]::new(0,20,0,8)
$updateCheck.Add_Click({Start-LinkUpdateCheck})
$updateInstall=[Windows.Forms.Button]::new();$updateInstall.Text='Install update';$updateInstall.AccessibleName=$updateInstall.Text;$updateInstall.Width=240;$updateInstall.Height=36;$updateInstall.FlatStyle='Flat';$updateInstall.BackColor=[Drawing.Color]::FromArgb(155,12,24);$updateInstall.Enabled=$false
$updateInstall.Add_Click({Start-LinkUpdateInstall})
$updateHint=[Windows.Forms.Label]::new();$updateHint.AutoSize=$true;$updateHint.MaximumSize=[Drawing.Size]::new(470,0);$updateHint.Margin=[Windows.Forms.Padding]::new(0,20,0,0)
$updateHint.Text="Checks run in the background. You can keep playing.`n`nClose Contractors before installing an update. Your settings are saved, then this app closes and the new installer opens.`n`nLoadout mods still update through Contractors."
if($script:linkUpdate.PreviewOnly){$updateHint.Text="This private preview checks the public release feed. Installing a public release here is disabled so your Dev build stays in place.`n`nLoadout mods still update through Contractors."}
$updateRows.Controls.AddRange(@($updateVersion,$updateStatus,$updateChecked,$updateCheck,$updateInstall,$updateHint));$updateTab.Controls.Add($updateRows)
$updateTimer=[Windows.Forms.Timer]::new();$updateTimer.Interval=200;$updateTimer.Add_Tick({Poll-LinkUpdate})
$form.Add_Shown({if(-not $Check){$updateTimer.Start();Start-LinkUpdateCheck}})
$form.Add_FormClosed({$updateTimer.Stop();$updateTimer.Dispose();Close-LinkUpdateRequest})

$tabs.Add_SelectedIndexChanged({if($script:capture){$script:capture=$null;Refresh-Keys;$message.Text='Key change cancelled.'}})
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

$footer=[Windows.Forms.FlowLayoutPanel]::new();$footer.Dock='Fill';$footer.Padding=[Windows.Forms.Padding]::new(18,3,0,0)
$save=[Windows.Forms.Button]::new();$save.Text='Save settings';$save.Width=180;$save.Height=35;$save.FlatStyle='Flat';$save.BackColor=[Drawing.Color]::FromArgb(155,12,24)
$reset=[Windows.Forms.Button]::new();$reset.Text='Restore defaults';$reset.Width=180;$reset.Height=35;$reset.FlatStyle='Flat'
$footer.Controls.AddRange(@($save,$reset));$layout.Controls.Add($footer,0,3)
$bottom=[Windows.Forms.TableLayoutPanel]::new();$bottom.Dock='Fill';$bottom.Padding=[Windows.Forms.Padding]::new(18,0,18,4);$bottom.RowCount=2
$status=[Windows.Forms.Label]::new();$status.Text='Ready. Enter CVRFlatscreen in VR.';$status.Dock='Fill';$status.AutoSize=$true
$message=[Windows.Forms.Label]::new();$message.Text='Save applies changes in the game. Keep this window open while playing.';$message.Dock='Fill';$message.AutoSize=$true;$message.ForeColor=[Drawing.Color]::Silver
$bottom.Controls.Add($status,0,0);$bottom.Controls.Add($message,0,1);$layout.Controls.Add($bottom,0,4)
$community=[Windows.Forms.FlowLayoutPanel]::new();$community.Dock='Fill';$community.Padding=[Windows.Forms.Padding]::new(18,4,0,0)
$author=[Windows.Forms.Label]::new();$author.Text='Author: _mintyfishy';$author.AutoSize=$true;$author.Margin=[Windows.Forms.Padding]::new(0,3,16,0);$community.Controls.Add($author)
foreach($entry in @(@('Discord updates','https://discord.gg/432n3NTq9f'),@('Download CVR Link','https://github.com/geraldjove/CVR-Link/releases/latest'))){
 $link=[Windows.Forms.LinkLabel]::new();$link.Text=$entry[0];$link.Tag=$entry[1];$link.AutoSize=$true;$link.LinkColor=[Drawing.Color]::FromArgb(255,145,150);$link.Margin=[Windows.Forms.Padding]::new(0,3,16,0)
 $link.Add_LinkClicked({param($sender) try{Start-Process -FilePath ([string]$sender.Tag)}catch{$message.Text='Could not open the browser. Visit the link from our GitHub page.'}});$community.Controls.Add($link)
}
$layout.Controls.Add($community,0,5)
function Refresh-Keys {foreach($key in $actions.Keys){$keyButtons[$key].Text=Format-Key $bindings[$key]}}
function Save-Settings {$text=Encode-Settings $speeds.Mouse.Value $speeds.Aim.Value $bindings ($uiInputs.Scale.Value/100) (1-$uiInputs.Transparency.Value/100) $experimental.Checked $fovInput.Value;Write-Atomic $settingsPath $text;$script:savedText=$text;$message.Text='Saved. Waiting for the game to apply your settings.'}
$save.Add_Click({try{Save-Settings}catch{$message.Text=$_.Exception.Message}})
$reset.Add_Click({$speeds.Mouse.Value=2.5;$speeds.Aim.Value=1;$uiInputs.Scale.Value=100;$uiInputs.Transparency.Value=0;$fovInput.Value=80;$experimental.Checked=$false;foreach($key in $actions.Keys){$bindings[$key]=$key};$script:capture=$null;Refresh-Keys;$message.Text='Defaults are ready. Click Save settings to apply them.'})
if(Test-Path -LiteralPath $settingsPath){try{$loaded=Read-Settings ([IO.File]::ReadAllText($settingsPath));$speeds.Mouse.Value=$loaded.Mouse;$speeds.Aim.Value=$loaded.Aim;$fovInput.Value=$loaded.Fov;$uiInputs.Scale.Value=$loaded.Scale*100;$uiInputs.Transparency.Value=(1-$loaded.Opacity)*100;$experimental.Checked=$loaded.ExperimentalStart;foreach($key in $actions.Keys){$bindings[$key]=$loaded.Keys[$key]};Refresh-Keys}catch{$message.Text='Could not read saved settings. Defaults are shown. '+$_.Exception.Message}}
if($Check){
 $sample=Get-DisplayChoice;$sample.vsync=1;$sample.fps=60;$sample.mode=2;$sample.width=1280;$sample.height=720
 $encoded=Encode-DisplaySettings $sample;$roundtrip=Read-DisplaySettings $encoded
 if($roundtrip.fps -ne 60 -or $roundtrip.width -ne 1280 -or $displayPanel.Parent -ne $uiRows -or -not $uiTab.AutoScroll){throw 'Display UI or settings round trip failed'}
 foreach($bad in @($encoded.Replace('fps=60','fps=19'),$encoded.Replace('mode=2','mode=0'),$encoded.Replace('vsync=1','vsync=2'),($encoded+"fps=60`n"),($encoded+"code=run`n"))){
  $rejected=$false;try{$null=Read-DisplaySettings $bad}catch{$rejected=$true};if(-not $rejected){throw 'Invalid display request accepted'}
 }
 $scratch=Join-Path $PSScriptRoot '.deps';New-Item -ItemType Directory -Path $scratch -Force|Out-Null
 Write-Atomic (Join-Path $scratch 'gui-display.ini') $encoded
 $displayScratch=Join-Path $scratch 'display-launch-check';New-Item -ItemType Directory -Path $displayScratch -Force|Out-Null
 Write-Atomic (Join-Path $displayScratch 'display.ini') $encoded
 if((Get-DisplayLaunchFlags $displayScratch) -ne ' -ResX=1280 -ResY=720'){throw 'Display resolution launch flags are wrong'}
 $script:displayStamp=[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()
 Assert-DisplayLiveChange $sample $sample $true
 $different=$sample.Clone();$different.width=1600
 Assert-DisplayLiveChange $different $sample $false
 $rejected=$false;try{Assert-DisplayLiveChange $different $sample $true}catch{$rejected=$true};if(-not $rejected){throw 'Live DLSS resize was not blocked'}
 $text=Encode-Settings 2.5 1 $bindings .8 .65 $true 120;$parsed=Read-Settings $text
 if($tabs.TabPages.Count -ne 4 -or $parsed.Scale -ne .8 -or $parsed.Opacity -ne .65 -or -not $parsed.ExperimentalStart -or $parsed.Fov -ne 120){throw 'Tabs or settings did not round trip'}
 foreach($badFov in @('79','121','nope','NaN')){$rejected=$false;try{$null=Read-Settings ('fov='+$badFov)}catch{$rejected=$true};if(-not $rejected){throw 'Invalid FOV accepted'}}
 foreach($bad in @('true','false','2','-1','0.5','01')){$rejected=$false;try{$null=Read-Settings ('experimental_start='+$bad)}catch{$rejected=$true};if(-not $rejected){throw 'Invalid Experimental setting accepted'}}
 foreach($badUi in @(@(.49,1),@(1.51,1),@(1,.09),@(1,1.01))){$rejected=$false;try{$null=Encode-Settings 2.5 1 $bindings $badUi[0] $badUi[1]}catch{$rejected=$true};if(-not $rejected){throw 'Invalid HUD settings accepted'}}
 $old=Read-Settings "mouse=0.8`naim=1`n";if($old.Scale -ne 1 -or $old.Opacity -ne 1 -or $old.Mouse -ne .8 -or $old.ExperimentalStart -or $old.Fov -ne 80){throw 'Old settings did not retain defaults'}
 $retired=Read-Settings "F6=F12`nE=F6`n"
 if($retired.Keys.Contains('F6') -or $retired.Keys.E -ne 'F6'){throw 'Retired scope action did not migrate'}
 if($keyButtons.Count -ne 24 -or $parsed.Keys.Count -ne 24){throw 'Missing control'}
 $custom=Read-Settings "E=F9`n";if($custom.Keys.E -ne 'F9' -or $custom.Keys.F9 -ne 'F10'){throw 'Old custom F9 binding was changed'}
 $bad=[ordered]@{};foreach($key in $actions.Keys){$bad[$key]=$key};$bad.E='G';$rejected=$false
 try{$null=Encode-Settings 2.5 1 $bad}catch{$rejected=$true};if(-not $rejected){throw 'Duplicate keys accepted'}
 $bad.E='F7';$rejected=$false;try{$null=Encode-Settings 2.5 1 $bad}catch{$rejected=$true};if(-not $rejected){throw 'Reserved key accepted'}
 $scratch=Join-Path $PSScriptRoot '.deps';New-Item -ItemType Directory -Path $scratch -Force|Out-Null
 Write-Atomic (Join-Path $scratch 'gui-settings.ini') $text;Write-Atomic (Join-Path $scratch 'gui-settings.ini') $text
 function Get-DisplayLaunchFlags {return ''}
 function Restore-DisplayGameSettings {}
 $script:launch=$null;$script:testRunning=$false
 function Get-Process {if($script:testRunning){return @{Id=1}}}
 function Get-ItemProperty {return @{SteamExe='C:\Steam\steam.exe'}}
 function Test-Path {return $true}
 function Start-Process {param($FilePath,$ArgumentList,$WindowStyle);$script:launch=@($FilePath,$ArgumentList)}
 Start-Contractors $true
 if($script:launch[0] -ne 'C:\Steam\steam.exe' -or $script:launch[1] -ne '-applaunch 963930 -nohmd -windowed'){throw 'Headset-free Steam launch is wrong'}
 Start-Contractors $false
 if($script:launch[0] -ne 'steam://rungameid/963930' -or $script:launch[1]){throw 'Normal VR launch was changed'}
 $script:testRunning=$true;$script:launch=$null;$rejected=$false
 try{Start-Contractors $true}catch{$rejected=$true}
 if(-not $rejected -or $script:launch){throw 'A second game launch was not blocked'}
 $script:testRunning=$false;function Test-Path {return $false};$rejected=$false
 try{Start-Contractors $true}catch{$rejected=$true}
 if(-not $rejected -or $script:launch){throw 'Missing Steam executable was not handled'}
 $form.Dispose();'CVR Link: native form, 24 controls, four tabs, settings round trip, atomic save, and Steam launch checks passed.';return
}
New-Item -ItemType Directory -Path $directory -Force|Out-Null
$mutex=[Threading.Mutex]::new($false,'Local\ContractorsFlatscreenControl')
if(-not $mutex.WaitOne(0)){[void][Windows.Forms.MessageBox]::Show('CVR Link is already running. Close its other window first.','CVR Link');$form.Dispose();$mutex.Dispose();return}
$watch=[Diagnostics.Stopwatch]::StartNew();$script:lastLease=-1000;$script:lastStatus=-1000;$script:f7=$false
$timer=[Windows.Forms.Timer]::new();$timer.Interval=50
$timer.Add_Tick({
 $now=$watch.ElapsedMilliseconds
 if($Seconds -gt 0 -and $watch.Elapsed.TotalSeconds -ge $Seconds){$form.Close();return}
 $f7=([CVRLinkKeys]::GetAsyncKeyState(118) -band 0x8000) -ne 0
 if($f7 -and -not $script:f7 -and -not $script:capture){$active.Checked=-not $active.Checked};$script:f7=$f7
 $down=@{};foreach($key in $keyCodes.Keys){if(([CVRLinkKeys]::GetAsyncKeyState($keyCodes[$key]) -band 0x8000) -ne 0){$down[$key]=$true}}
 if($script:capture -and $form.ContainsFocus){
  if(([CVRLinkKeys]::GetAsyncKeyState(27) -band 0x8000) -ne 0){$script:capture=$null;Refresh-Keys;$message.Text='Key change cancelled.'}
  else{foreach($key in $down.Keys){if(-not $script:pressed.ContainsKey($key)){$bindings[$script:capture]=$key;$script:capture=$null;Refresh-Keys;$message.Text='Key changed. Click Save settings to apply it.';break}}}
 }
 $script:pressed=$down
 if($now-$script:lastLease -ge 250){
  $script:lastLease=$now
  try{$deadline=if($active.Checked){[DateTimeOffset]::UtcNow.ToUnixTimeSeconds()+2}else{0};Write-Atomic (Join-Path $directory 'control.txt') ([string]$deadline)}catch{$status.Text='Link interrupted. Flatscreen controls will stop.'}
 }
 if($now-$script:lastStatus -ge 500){
  $script:lastStatus=$now
  Refresh-Display
  try{
   $line=[IO.File]::ReadAllText((Join-Path $directory 'status.txt')).Trim();$parts=$line -split '\|';$stamp=0L;$fresh=[long]::TryParse($parts[0],[ref]$stamp) -and ([DateTimeOffset]::UtcNow.ToUnixTimeSeconds()-$stamp -le 4)
   if(-not $active.Checked){$status.Text='CVR Link is off. F7 turns it on.'}
   elseif($parts[1] -eq 'ERROR'){$status.Text='The mod stopped after an error. Restart Contractors.'}
   elseif(-not $fresh){$status.Text='Waiting for Contractors. Start the game through Steam.'}
   elseif($parts[1] -eq 'RETURNING'){$status.Text='This match needs CVRFlatscreen. Returning to HQ.'}
   elseif($parts[1] -eq 'WAITING'){$status.Text='Waiting for your player to finish loading. Flatscreen will start on its own.'}
   elseif($parts[1] -eq 'ON'){$status.Text=if($line.Contains('|headset_free=true')){'Flatscreen is on. Click the game window to play.'}else{'Flatscreen is on. Use Virtual Desktop Desktop view.'}}
   elseif($line.Contains('|headset_free=true')){$status.Text='Headset-free start. Flatscreen is paused; enable the link or restart for VR.'}
   elseif($line.Contains('|cvr_room=true')){$status.Text='CVRFlatscreen is ready. Choose your play mode in the game.'}
   else{$status.Text='VR is on. This match needs the CVRFlatscreen loadout for flatscreen.'}
   if($fresh -and $script:savedText -and $line.Contains('|settings='+($script:savedText -replace "`n",','))){$message.Text='Settings applied in game.';$script:savedText=$null}
  }catch{$status.Text='Waiting for Contractors. Start the game through Steam.'}
 }
})
try{$timer.Start();[void]$form.ShowDialog()}
finally{Close-DisplayConfirm;$timer.Stop();$timer.Dispose();try{Write-Atomic (Join-Path $directory 'control.txt') '0'}finally{$mutex.ReleaseMutex();$mutex.Dispose();$form.Dispose()}}

if($script:pendingLinkUpdate){$script:pendingLinkUpdate}
