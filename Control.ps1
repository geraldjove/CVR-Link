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
 LeftControl='Crouch'; C='Crouch (second key)'; F6='Scope / zoom'
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
 if($HeadsetFree){
  $steamExe=(Get-ItemProperty -LiteralPath 'HKCU:\Software\Valve\Steam').SteamExe
  if(-not $steamExe -or -not(Test-Path -LiteralPath $steamExe -PathType Leaf)){throw 'Open Steam and sign in before starting Contractors.'}
  Start-Process -FilePath $steamExe -ArgumentList '-applaunch 963930 -nohmd -windowed' -WindowStyle Hidden
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
$experimentalHint=[Windows.Forms.Label]::new();$experimentalHint.Text="Start Contractors with a mouse and keyboard. No headset is needed when you use the start button below.`n`nPlay from the local HQ and join matches using the exact CVRFlatscreen loadout, on any map. Other matches return you to HQ.`n`nKeep CVR Link open and enabled. Close the game before starting this mode. To play in VR, close the game, turn this option off, and start again.`n`nSave settings alone cannot change how a running game was started.";$experimentalHint.AutoSize=$true;$experimentalHint.MaximumSize=[Drawing.Size]::new(470,0);$experimentalHint.Margin=[Windows.Forms.Padding]::new(0,16,0,16)
$startGame=[Windows.Forms.Button]::new();$startGame.Text='Save and start Contractors';$startGame.Width=260;$startGame.Height=38;$startGame.FlatStyle='Flat';$startGame.BackColor=[Drawing.Color]::FromArgb(155,12,24);$startGame.AccessibleName=$startGame.Text
$startGame.Add_Click({try{Save-Settings;$active.Checked=$true;Start-Contractors $experimental.Checked;$message.Text='Starting Contractors through Steam. Keep CVR Link enabled.'}catch{$message.Text=$_.Exception.Message}})
$experimentalRows.Controls.AddRange(@($experimental,$experimentalHint,$startGame));$experimentalTab.Controls.Add($experimentalRows)
$tabs.Add_SelectedIndexChanged({if($script:capture){$script:capture=$null;Refresh-Keys;$message.Text='Key change cancelled.'}})
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
 $text=Encode-Settings 2.5 1 $bindings .8 .65 $true 120;$parsed=Read-Settings $text
 if($tabs.TabPages.Count -ne 3 -or $parsed.Scale -ne .8 -or $parsed.Opacity -ne .65 -or -not $parsed.ExperimentalStart -or $parsed.Fov -ne 120){throw 'Tabs or settings did not round trip'}
 foreach($badFov in @('79','121','nope','NaN')){$rejected=$false;try{$null=Read-Settings ('fov='+$badFov)}catch{$rejected=$true};if(-not $rejected){throw 'Invalid FOV accepted'}}
 foreach($bad in @('true','false','2','-1','0.5','01')){$rejected=$false;try{$null=Read-Settings ('experimental_start='+$bad)}catch{$rejected=$true};if(-not $rejected){throw 'Invalid Experimental setting accepted'}}
 foreach($badUi in @(@(.49,1),@(1.51,1),@(1,.09),@(1,1.01))){$rejected=$false;try{$null=Encode-Settings 2.5 1 $bindings $badUi[0] $badUi[1]}catch{$rejected=$true};if(-not $rejected){throw 'Invalid HUD settings accepted'}}
 $old=Read-Settings "mouse=0.8`naim=1`n";if($old.Scale -ne 1 -or $old.Opacity -ne 1 -or $old.Mouse -ne .8 -or $old.ExperimentalStart -or $old.Fov -ne 80){throw 'Old settings did not retain defaults'}
 if($keyButtons.Count -ne 25 -or $parsed.Keys.Count -ne 25){throw 'Missing control'}
 $custom=Read-Settings "E=F9`n";if($custom.Keys.E -ne 'F9' -or $custom.Keys.F9 -ne 'F10'){throw 'Old custom F9 binding was changed'}
 $bad=[ordered]@{};foreach($key in $actions.Keys){$bad[$key]=$key};$bad.E='G';$rejected=$false
 try{$null=Encode-Settings 2.5 1 $bad}catch{$rejected=$true};if(-not $rejected){throw 'Duplicate keys accepted'}
 $bad.E='F7';$rejected=$false;try{$null=Encode-Settings 2.5 1 $bad}catch{$rejected=$true};if(-not $rejected){throw 'Reserved key accepted'}
 $scratch=Join-Path $PSScriptRoot '.deps';New-Item -ItemType Directory -Path $scratch -Force|Out-Null
 Write-Atomic (Join-Path $scratch 'gui-settings.ini') $text;Write-Atomic (Join-Path $scratch 'gui-settings.ini') $text
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
 $form.Dispose();'CVR Link: native form, 25 controls, three tabs, settings round trip, atomic save, and Steam launch checks passed.';return
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
finally{$timer.Stop();$timer.Dispose();try{Write-Atomic (Join-Path $directory 'control.txt') '0'}finally{$mutex.ReleaseMutex();$mutex.Dispose();$form.Dispose()}}
