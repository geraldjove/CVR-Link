# Authored scope assets. Keep an ownership journal under this app state.
$script:ScopeFiles=@('CVRScope.pak','CVRScope.json')
function Get-ScopeFolder([string]$GameBin){
    if((Split-Path -Leaf $GameBin) -ne 'Win64' -or (Split-Path -Leaf (Split-Path -Parent $GameBin)) -ne 'Binaries'){throw 'Unexpected Contractors binary folder.'}
    $root=Split-Path -Parent (Split-Path -Parent ([IO.Path]::GetFullPath($GameBin)))
    return Safe-Child $root 'ModsTest/CVRScope'
}
function Assert-ScopePackage([string]$Payload,[string]$GameBin,[string]$StateRoot){
    $folder=Get-ScopeFolder $GameBin
    $journal=Join-Path $StateRoot 'scope-install.json'
    $old=if(Test-Path -LiteralPath $journal){Get-Content -Raw -LiteralPath $journal | ConvertFrom-Json}else{$null}
    if($old -and $old.folder -ne $folder){throw 'Scope assets belong to another game folder.'}
    foreach($name in $script:ScopeFiles){
        if(-not(Test-Path -LiteralPath (Join-Path $Payload ('scope/'+$name)) -PathType Leaf)){throw 'Scope payload is missing.'}
        $target=Safe-Child $folder $name
        if(Test-Path -LiteralPath $target){
            $entry=@($old.files | Where-Object name -eq $name)
            if($entry.Count -ne 1 -or (Get-Hash $target) -ne $entry[0].sha256){throw "A changed scope file was kept: $name"}
        }
    }
}
function Install-ScopePackage([string]$Payload,[string]$GameBin,[string]$StateRoot){
    Assert-GameClosed
    Assert-ScopePackage $Payload $GameBin $StateRoot
    $folder=Get-ScopeFolder $GameBin
    New-Item -ItemType Directory -Path $folder -Force | Out-Null
    $files=foreach($name in $script:ScopeFiles){
        $source=Join-Path $Payload ('scope/'+$name);$target=Safe-Child $folder $name
        Copy-Item -LiteralPath $source -Destination $target -Force
        if((Get-Hash $source) -ne (Get-Hash $target)){throw 'Scope copy did not verify.'}
        [ordered]@{name=$name;sha256=(Get-Hash $source)}
    }
    [ordered]@{folder=$folder;files=@($files)} | ConvertTo-Json -Depth 4 | Set-Content -LiteralPath (Join-Path $StateRoot 'scope-install.json')
}
function Test-ScopePackage([string]$Payload,[string]$GameBin,[string]$StateRoot){
    try{
        Assert-ScopePackage $Payload $GameBin $StateRoot
        $folder=Get-ScopeFolder $GameBin
        foreach($name in $script:ScopeFiles){if((Get-Hash (Join-Path $Payload ('scope/'+$name))) -ne (Get-Hash (Safe-Child $folder $name))){return $false}}
        return $true
    }catch{return $false}
}
function Remove-ScopePackage([string]$GameBin,[string]$StateRoot){
    Assert-GameClosed
    $journal=Join-Path $StateRoot 'scope-install.json'
    if(-not(Test-Path -LiteralPath $journal)){return}
    $record=Get-Content -Raw -LiteralPath $journal | ConvertFrom-Json
    $folder=Get-ScopeFolder $GameBin
    if($record.folder -ne $folder -or @($record.files).Count -ne 2 -or @($record.files.name | Select-Object -Unique).Count -ne 2){throw 'Unknown scope install record.'}
    foreach($entry in $record.files){if($entry.name -notin $script:ScopeFiles){throw 'Unknown scope file in install record.'}}
    $kept=@()
    foreach($entry in $record.files){
        $path=Safe-Child $folder $entry.name
        if(-not(Test-Path -LiteralPath $path)){continue}
        if((Get-Hash $path) -ne $entry.sha256){$kept+=$path;continue}
        Remove-Item -LiteralPath $path
    }
    if($kept.Count -eq 0){Remove-Item -LiteralPath $journal}
    return $kept
}
