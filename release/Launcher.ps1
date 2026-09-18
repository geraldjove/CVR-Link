param([string]$Executable,[string]$Mode='open',[string]$GameBin,[string]$StateRoot)
$ErrorActionPreference='Stop'
Add-Type -AssemblyName System.Windows.Forms,System.Drawing
. (Join-Path $PSScriptRoot 'Setup.ps1')
if(-not $StateRoot){$StateRoot=Join-Path $env:LOCALAPPDATA 'CVRLink'}
if($Mode -eq '--check'){
    & (Join-Path $PSScriptRoot 'Control.ps1') -Check
    return
}
if($Mode -eq '--install-elevated'){
    $null=Install-Link $PSScriptRoot $GameBin $StateRoot
    return
}
$registration='HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\CVRLink'
function Add-Shortcuts {
    $shell=New-Object -ComObject WScript.Shell
    foreach($folder in [Environment]::GetFolderPath('DesktopDirectory'),[Environment]::GetFolderPath('Programs')){
        $link=$shell.CreateShortcut((Join-Path $folder 'CVR Link.lnk'))
        $link.TargetPath=$Executable;$link.WorkingDirectory=Split-Path -Parent $Executable;$link.IconLocation=$Executable+',0';$link.Description='CVRFlatscreen keys, mouse and HUD settings';$link.Save()
    }
    New-Item -Path $registration -Force | Out-Null
    foreach($entry in @{DisplayName='CVR Link';DisplayVersion='0.2.41';Publisher='_mintyfishy';DisplayIcon=$Executable;UninstallString=('"'+$Executable+'" --uninstall');URLInfoAbout='https://github.com/geraldjove/CVR-Link'}.GetEnumerator()){
        New-ItemProperty -LiteralPath $registration -Name $entry.Key -Value $entry.Value -PropertyType String -Force | Out-Null
    }
}
if($Mode -eq '--uninstall'){
    if([Windows.Forms.MessageBox]::Show('Remove CVR Link from Contractors? Your key and mouse settings will be kept.','CVR Link','YesNo','Question') -ne 'Yes'){return}
    $kept=@(Remove-Link $StateRoot)
    if($kept.Count){[void][Windows.Forms.MessageBox]::Show('Removed the unchanged mod files. Kept files used or changed by other mods. Backups are in '+$StateRoot,'CVR Link');return}
    foreach($folder in [Environment]::GetFolderPath('DesktopDirectory'),[Environment]::GetFolderPath('Programs')){
        $shortcut=Join-Path $folder 'CVR Link.lnk';if(Test-Path -LiteralPath $shortcut){Remove-Item -LiteralPath $shortcut}
    }
    if(Test-Path -LiteralPath $registration){Remove-Item -LiteralPath $registration}
    [void][Windows.Forms.MessageBox]::Show('CVR Link was removed from the game. Your saved settings and backup files were kept.','CVR Link')
    return
}
if(-not (Test-LinkInstalled $PSScriptRoot $StateRoot)){
    Add-Type -TypeDefinition 'using System; using System.Runtime.InteropServices; public static class CVRSetupWindow { [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr window, int mode); }'
    $form=[Windows.Forms.Form]::new();$form.Text='Install CVR Link';$form.ClientSize=[Drawing.Size]::new(610,425)
    $form.Icon=[Drawing.Icon]::new((Join-Path $PSScriptRoot 'CVRLink.ico'))
    $form.StartPosition='CenterScreen';$form.FormBorderStyle='FixedDialog';$form.MaximizeBox=$false
    $form.BackColor=[Drawing.Color]::FromArgb(18,18,20);$form.ForeColor=[Drawing.Color]::White;$form.Font=[Drawing.Font]::new('Segoe UI',10)
    $form.Add_Shown({[void][CVRSetupWindow]::ShowWindow($form.Handle,5);$form.Activate()})
    $title=[Windows.Forms.Label]::new();$title.Text='CVR Link';$title.Font=[Drawing.Font]::new('Segoe UI',26,[Drawing.FontStyle]::Bold);$title.SetBounds(24,18,550,52)
    $help=[Windows.Forms.Label]::new();$help.Text="One click sets up the app and game files.`nStart in VR. Choose Flatscreen in a CVRFlatscreen room.";$help.SetBounds(28,80,550,56)
    $path=[Windows.Forms.TextBox]::new();$path.ReadOnly=$true;$path.SetBounds(28,153,449,30)
    $games=@(Get-SteamGames);if($games.Count){$path.Text=$games[0]}
    $browse=[Windows.Forms.Button]::new();$browse.Text='Find game';$browse.SetBounds(485,151,96,32);$browse.FlatStyle='Flat'
    $browse.Add_Click({$pick=[Windows.Forms.OpenFileDialog]::new();$pick.Title='Choose the Contractors game file';$pick.Filter='Contractors game|Contractors_UE4_22_Steam-Win64-Shipping.exe';try{if($pick.ShowDialog() -eq 'OK'){$path.Text=Split-Path -Parent $pick.FileName}}finally{$pick.Dispose()}})
    $message=[Windows.Forms.Label]::new();$message.SetBounds(28,202,550,88);$message.Text='Close Contractors before setup. Your other mods and saved settings stay in place.'
    $install=[Windows.Forms.Button]::new();$install.Text='Install CVR Link';$install.SetBounds(28,300,553,46);$install.FlatStyle='Flat';$install.BackColor=[Drawing.Color]::FromArgb(155,12,24)
    $credit=[Windows.Forms.Label]::new();$credit.Text='Author: _mintyfishy | Free community mod | Windows Steam version';$credit.SetBounds(28,372,550,30)
    $script:installed=$false
    $install.Add_Click({
        $install.Enabled=$false;$browse.Enabled=$false;$message.Text='Checking and installing files...';$form.Refresh()
        try{
            if(-not $path.Text){throw 'Steam did not find the game. Click Find game and choose its Win64 game file.'}
            Assert-GameClosed
            $null=Get-InstallFiles $PSScriptRoot $path.Text
            try{
                $probe=Safe-Child $path.Text ('cvr-link-write-check-'+[guid]::NewGuid().ToString('N'))
                [IO.File]::WriteAllText($probe,'');Remove-Item -LiteralPath $probe
                $null=Install-Link $PSScriptRoot $path.Text $StateRoot
            }catch [UnauthorizedAccessException]{
                $message.Text='Windows needs permission to write to the game folder.';$form.Refresh()
                $args='--install-elevated "{0}" "{1}"' -f $path.Text,$StateRoot
                $child=Start-Process -FilePath $Executable -ArgumentList $args -Verb RunAs -PassThru
                while(-not $child.HasExited){[Windows.Forms.Application]::DoEvents();[Threading.Thread]::Sleep(50)}
                if($child.ExitCode -ne 0 -or -not (Test-LinkInstalled $PSScriptRoot $StateRoot)){throw 'Setup did not finish. Allow the Windows permission prompt and try again.'}
            }
            Add-Shortcuts;$script:installed=$true;$form.Close()
        }catch{$message.Text=$_.Exception.Message;$install.Enabled=$true;$browse.Enabled=$true}
    })
    $form.Controls.AddRange(@($title,$help,$path,$browse,$message,$install,$credit))
    [void]$form.ShowDialog();$form.Dispose()
    if(-not $script:installed){return}
}
& (Join-Path $PSScriptRoot 'Control.ps1')
