# Shared installer code. Dot sourcing defines functions; it never installs.
$script:GameExe='Contractors_UE4_22_Steam-Win64-Shipping.exe'
$script:GameHash='65E63AB2AED1F723DF3BAFB58527A3F32C47B880D14EEB5A433D444B570B1467'
$script:LuaFiles=@('main.lua','Controls.lua','Inventory.lua','Ammo.lua','HUD.lua','ItemActions.lua','Placement.lua','Menu.lua','Room.lua','Settings.lua')
function Get-Hash([string]$Path) {
    if(Test-Path -LiteralPath $Path -PathType Leaf){return (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash}
    return ''
}
function Get-SteamGames {
    $roots=@()
    foreach($key in 'HKCU:\Software\Valve\Steam','HKLM:\SOFTWARE\WOW6432Node\Valve\Steam'){
        $item=Get-ItemProperty -LiteralPath $key -ErrorAction SilentlyContinue
        if($item.SteamPath){$roots+=$item.SteamPath};if($item.InstallPath){$roots+=$item.InstallPath}
    }
    $roots+=Join-Path ${env:ProgramFiles(x86)} 'Steam'
    foreach($root in @($roots | Select-Object -Unique)){
        $vdf=Join-Path $root 'steamapps\libraryfolders.vdf'
        if(Test-Path -LiteralPath $vdf){$roots+=Get-LibraryPaths ([IO.File]::ReadAllText($vdf))}
    }
    foreach($root in @($roots | Select-Object -Unique)){
        $manifest=Join-Path $root 'steamapps\appmanifest_963930.acf'
        if(Test-Path -LiteralPath $manifest){
            $text=[IO.File]::ReadAllText($manifest)
            if($text -match '"installdir"\s+"([^"\\/]+)"'){
                $path=Join-Path $root ('steamapps\common\'+$Matches[1]+'\Contractors_UE4_22\Binaries\Win64')
                if(Test-Path -LiteralPath (Join-Path $path $script:GameExe)){[IO.Path]::GetFullPath($path)}
            }
        }
    }
}
function Get-LibraryPaths([string]$Text){
    foreach($match in [regex]::Matches($Text,'"path"\s+"([^"\r\n]+)"')){$match.Groups[1].Value.Replace('\\','\')}
}
function Assert-GameClosed {
    if(Get-Process -Name 'Contractors_UE4_22_Steam-Win64-Shipping' -ErrorAction SilentlyContinue){throw 'Close Contractors, then click Install again.'}
}
function Safe-Child([string]$Root,[string]$Relative){
    $base=[IO.Path]::GetFullPath($Root).TrimEnd('\')+'\'
    $path=[IO.Path]::GetFullPath((Join-Path $base $Relative))
    if(-not $path.StartsWith($base,[StringComparison]::OrdinalIgnoreCase)){throw 'File path is outside the install folder.'}
    # Do not follow a user-created junction into a different game or folder.
    $cursor=$path
    while($cursor.Length -ge $base.TrimEnd('\').Length){
        if(Test-Path -LiteralPath $cursor){if((Get-Item -Force -LiteralPath $cursor).Attributes -band [IO.FileAttributes]::ReparsePoint){throw 'Choose a game folder without file links or junctions.'}}
        $cursor=Split-Path -Parent $cursor
    }
    return $path
}
function Set-IniValue([string]$Text,[string]$Section,[string]$Key,[string]$Value){
    $lines=[Collections.Generic.List[string]]::new();$lines.AddRange([string[]]($Text -split '\r?\n'))
    $start=-1;$end=$lines.Count
    for($i=0;$i -lt $lines.Count;$i++){
        if($lines[$i] -match '^\s*\[([^]]+)\]'){
            if($start -ge 0){$end=$i;break}
            if($Matches[1] -eq $Section){$start=$i}
        }
    }
    if($start -lt 0){$lines.Add('['+$Section+']');$lines.Add($Key+' = '+$Value)}
    else{
        $found=$false
        for($i=$start+1;$i -lt $end;$i++){if($lines[$i] -match ('^\s*'+[regex]::Escape($Key)+'\s*=')){$lines[$i]=$Key+' = '+$Value;$found=$true}}
        if(-not $found){$lines.Insert($end,$Key+' = '+$Value)}
    }
    return ($lines -join "`r`n")
}
function Get-InstallFiles([string]$Payload,[string]$GameBin){
    $game=Safe-Child $GameBin $script:GameExe
    if((Get-Hash $game) -ne $script:GameHash){throw 'This game version has not been tested with CVR Link. Install the supported Steam build or check the download page for an update.'}
    if(Test-Path -LiteralPath (Safe-Child $GameBin 'xinput1_3.dll')){throw 'An older mod loader is installed (xinput1_3.dll). Remove that loader before using CVR Link.'}
    $files=[ordered]@{}
    foreach($dll in 'dwmapi.dll','UE4SS.dll'){
        $source=Join-Path $Payload ('loader\'+$dll);$target=Safe-Child $GameBin $dll
        if((Test-Path -LiteralPath $target) -and (Get-Hash $target) -ne (Get-Hash $source)){throw ('A different mod loader already uses '+$dll+'. CVR Link kept it in place. Remove or update that loader first.')}
        $files[$dll]=[IO.File]::ReadAllBytes($source)
    }
    $ini=Safe-Child $GameBin 'UE4SS-settings.ini'
    $text=if(Test-Path -LiteralPath $ini){[IO.File]::ReadAllText($ini)}else{[IO.File]::ReadAllText((Join-Path $Payload 'loader\UE4SS-settings.ini'))}
    if($text -match '(?m)^[ \t]*ModsFolderPath[ \t]*=[ \t]*([^;\r\n\s][^\r\n]*)'){throw 'This loader uses a custom Mods folder. CVR Link kept it in place. Use the default Mods folder before installing.'}
    foreach($row in @(@('General','EnableHotReloadSystem','0'),@('General','bUseUObjectArrayCache','false'),@('Debug','ConsoleEnabled','0'),@('Debug','GuiConsoleEnabled','0'),@('Debug','GuiConsoleVisible','0'))){$text=Set-IniValue $text $row[0] $row[1] $row[2]}
    $files['UE4SS-settings.ini']=[Text.UTF8Encoding]::new($false).GetBytes($text)
    foreach($lua in $script:LuaFiles){$files['Mods\Flatscreen\Scripts\'+$lua]=[IO.File]::ReadAllBytes((Join-Path $Payload ('runtime\'+$lua)))}
    $files['Mods\Flatscreen\enabled.txt']=[byte[]]@()
    # A nonempty mods.txt entry overrides enabled.txt in some loader setups.
    $mods=Safe-Child $GameBin 'Mods\mods.txt'
    if(Test-Path -LiteralPath $mods){
        $list=[IO.File]::ReadAllText($mods)
        if($list -match '(?m)^\s*Flatscreen\s*:'){$list=[regex]::Replace($list,'(?m)^\s*Flatscreen\s*:[^\r\n]*','Flatscreen : 1')}
        else{$list+="`r`nFlatscreen : 1`r`n"}
        $files['Mods\mods.txt']=[Text.UTF8Encoding]::new($false).GetBytes($list)
    }else{$files['Mods\mods.txt']=[Text.Encoding]::ASCII.GetBytes("Flatscreen : 1`r`n")}
    foreach($name in $files.Keys){$target=Safe-Child $GameBin $name;if(Test-Path -LiteralPath $target -PathType Container){throw 'A folder blocks a required game file. No files were changed.'}}
    return $files
}
function Install-Link([string]$Payload,[string]$GameBin,[string]$StateRoot){
    Assert-GameClosed
    $files=Get-InstallFiles $Payload $GameBin
    $journal=Join-Path $StateRoot 'install.json';$previous=$null
    if(Test-Path -LiteralPath $journal){
        $previous=Get-Content -Raw -LiteralPath $journal | ConvertFrom-Json
        if($previous.game -ne [IO.Path]::GetFullPath($GameBin)){throw 'CVR Link is installed in another game folder. Remove that install before choosing a new folder.'}
    }
    $backup=Join-Path $StateRoot ('backups\'+[guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Path $backup -Force | Out-Null
    $changed=[Collections.Generic.List[object]]::new();$records=@()
    try{
        foreach($relative in $files.Keys){
            $target=Safe-Child $GameBin $relative;$existed=Test-Path -LiteralPath $target
            $before=Join-Path $backup ([string]$changed.Count)
            if($existed){Copy-Item -LiteralPath $target -Destination $before}
            $item=[pscustomobject]@{path=$relative;existed=$existed;backup=$before;sha256=''}
            $changed.Add($item)
            New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
            [IO.File]::WriteAllBytes($target,$files[$relative]);$item.sha256=Get-Hash $target
            $old=if($previous){@($previous.files | Where-Object path -EQ $relative) | Select-Object -First 1}
            if($old -and (Get-Hash $before) -eq $old.sha256){$records+=[pscustomobject]@{path=$relative;existed=$old.existed;backup=$old.backup;sha256=$item.sha256}}
            else{$records+=$item}
        }
        $record=[ordered]@{version='0.2.9';game=[IO.Path]::GetFullPath($GameBin);files=$records}
        $temp=$journal+'.tmp';[IO.File]::WriteAllText($temp,($record | ConvertTo-Json -Depth 5))
        if(Test-Path -LiteralPath $journal){[IO.File]::Replace($temp,$journal,$journal+'.bak')}else{[IO.File]::Move($temp,$journal)}
    }catch{
        for($i=$changed.Count-1;$i -ge 0;$i--){$item=$changed[$i];$target=Safe-Child $GameBin $item.path;if($item.existed){Copy-Item -LiteralPath $item.backup -Destination $target -Force}else{if(Test-Path -LiteralPath $target){Remove-Item -LiteralPath $target}}}
        throw
    }
    return $record
}
function Test-LinkInstalled([string]$Payload,[string]$StateRoot){
    $journal=Join-Path $StateRoot 'install.json'
    if(-not(Test-Path -LiteralPath $journal)){return $false}
    try{
        $record=Get-Content -Raw -LiteralPath $journal | ConvertFrom-Json
        if($record.version -ne '0.2.9'){return $false}
        if((Get-Hash (Safe-Child $record.game $script:GameExe)) -ne $script:GameHash){return $false}
        foreach($file in $record.files){if((Get-Hash (Safe-Child $record.game $file.path)) -ne $file.sha256){return $false}}
        foreach($lua in $script:LuaFiles){if((Get-Hash (Join-Path $Payload ('runtime\'+$lua))) -ne (Get-Hash (Safe-Child $record.game ('Mods\Flatscreen\Scripts\'+$lua)))){return $false}}
        return $true
    }catch{return $false}
}
function Remove-Link([string]$StateRoot){
    Assert-GameClosed
    $journal=Join-Path $StateRoot 'install.json'
    if(-not(Test-Path -LiteralPath $journal)){return @()}
    $record=Get-Content -Raw -LiteralPath $journal | ConvertFrom-Json;$kept=@()
    if(-not(Test-Path -LiteralPath (Safe-Child $record.game $script:GameExe) -PathType Leaf)){throw 'The saved game folder was not found. No files were removed.'}
    $allowed=@('dwmapi.dll','UE4SS.dll','UE4SS-settings.ini','Mods\mods.txt','Mods\Flatscreen\enabled.txt')
    $allowed+=@($script:LuaFiles | ForEach-Object {'Mods\Flatscreen\Scripts\'+$_})
    foreach($file in $record.files){if($file.path -notin $allowed){throw 'The install record lists an unknown file. No files were removed.'}}
    $others=@(Get-ChildItem -LiteralPath (Join-Path $record.game 'Mods') -Directory -ErrorAction SilentlyContinue | Where-Object Name -NE 'Flatscreen')
    foreach($file in $record.files){
        $target=Safe-Child $record.game $file.path
        if(-not(Test-Path -LiteralPath $target)){continue}
        if((Get-Hash $target) -ne $file.sha256){$kept+=$file.path;continue}
        if(-not $file.existed -and $others.Count -gt 0 -and $file.path -in 'dwmapi.dll','UE4SS.dll','UE4SS-settings.ini','Mods\mods.txt'){$kept+=$file.path;continue}
        if($file.existed){
            $base=[IO.Path]::GetFullPath($StateRoot).TrimEnd('\')+'\'
            if(-not ([IO.Path]::GetFullPath($file.backup)).StartsWith($base,[StringComparison]::OrdinalIgnoreCase)){throw 'The backup path is outside CVR Link.'}
            $backup=Safe-Child $StateRoot ([IO.Path]::GetFullPath($file.backup).Substring($base.Length))
            if(-not(Test-Path -LiteralPath $backup)){throw 'The saved backup is missing. Kept the current game file.'}
            Copy-Item -LiteralPath $backup -Destination $target -Force
        }else{Remove-Item -LiteralPath $target}
    }
    # Keep the journal/backups if anything needs manual review. No recursive deletes.
    if($kept.Count -eq 0){Remove-Item -LiteralPath $journal}
    return $kept
}
