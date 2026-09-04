<#
    Self-check for Tweaks.ps1. No framework, no elevation, no system changes:
    it only exercises the definition table and the backup/restore plumbing
    against a scratch key under HKCU.

    Run:  pwsh -File .\Tweaks.Tests.ps1
#>
Set-StrictMode -Version 2.0
$ErrorActionPreference = 'Stop'

# Dot-source in -List mode so the functions and $Tweaks land in scope without the
# script touching anything. Running it with no arguments would open the picker.
. (Join-Path $PSScriptRoot 'Tweaks.ps1') -List | Out-Null

$failed = 0
function Check([string]$Name, [scriptblock]$Body) {
    try {
        & $Body
        Write-Host "  ok    $Name" -ForegroundColor Green
    }
    catch {
        Write-Host "  FAIL  $Name -- $($_.Exception.Message)" -ForegroundColor Red
        $script:failed++
    }
}

Write-Host 'Tweaks.ps1 self-check' -ForegroundColor Cyan

Check 'every tweak has the required metadata' {
    foreach ($t in $Tweaks) {
        foreach ($key in 'Id', 'Category', 'Title', 'Why', 'Risk', 'Evidence', 'Reboot') {
            if (-not $t.ContainsKey($key)) { throw "$($t.Id) is missing '$key'" }
        }
        if ($t.Risk -notin 'Low', 'Medium', 'High') { throw "$($t.Id) has risk '$($t.Risk)'" }
    }
}

Check 'every tweak is either declarative or fully imperative' {
    foreach ($t in $Tweaks) {
        if ($t.ContainsKey('Reg')) {
            foreach ($r in $t.Reg) {
                foreach ($key in 'Path', 'Name', 'Type', 'Value') {
                    if (-not $r.ContainsKey($key)) { throw "$($t.Id) has a Reg entry missing '$key'" }
                }
            }
        }
        else {
            # An imperative tweak without an Undo is a one-way door.
            foreach ($key in 'Capture', 'Set', 'Undo', 'Test') {
                if (-not $t.ContainsKey($key)) { throw "$($t.Id) is imperative but missing '$key'" }
            }
        }
    }
}

Check 'ids are unique' {
    $dupes = $Tweaks.Id | Group-Object | Where-Object Count -gt 1
    if ($dupes) { throw "duplicate id(s): $($dupes.Name -join ', ')" }
}

Check 'Resolve-Selection matches by id, by category and by all' {
    $byId = @(Resolve-Selection @('net.nagle'))
    if ($byId.Count -ne 1 -or $byId[0].Id -ne 'net.nagle') { throw 'id lookup broken' }

    $byCategory = @(Resolve-Selection @('privacy'))
    $expected = @($Tweaks | Where-Object Category -eq 'privacy').Count
    if ($byCategory.Count -ne $expected) { throw "category lookup returned $($byCategory.Count), expected $expected" }

    if (@(Resolve-Selection @('all')).Count -ne $Tweaks.Count) { throw "'all' did not return everything" }
}

Check 'Resolve-Selection rejects an unknown name instead of silently doing nothing' {
    try {
        Resolve-Selection @('net.nagel') | Out-Null
        throw 'no error was raised'
    }
    catch {
        if ($_.Exception.Message -notmatch 'Unknown tweak') { throw $_ }
    }
}

Check 'Format-Fit pads short text and truncates long text to the exact width' {
    if ((Format-Fit 'abc' 6) -ne 'abc   ') { throw 'short text was not padded' }
    if ((Format-Fit 'abcdefgh' 4).Length -ne 4) { throw 'long text was not cut to width' }
    if ((Format-Fit 'abcdefgh' 4) -ne 'abc…') { throw 'no ellipsis on truncation' }
    if ((Format-Fit 'abc' 0) -ne '') { throw 'zero width should give an empty string' }
}

Check 'the UI row list covers every tweak exactly once' {
    $rows = @(New-UIRow)
    $ids = @($rows | Where-Object Kind -eq 'Tweak' | ForEach-Object { $_.Tweak.Id })
    if ($ids.Count -ne $Tweaks.Count) { throw "$($ids.Count) rows for $($Tweaks.Count) tweaks" }
    if (@($ids | Sort-Object -Unique).Count -ne $Tweaks.Count) { throw 'a tweak appears twice' }
}

Check 'the UI row list starts on a header and ends on a tweak' {
    $rows = @(New-UIRow)
    # The cursor seeks forward from 0 to the first tweak, and End jumps to the last
    # row without stepping. Both assume this shape.
    if ($rows[0].Kind -ne 'Header') { throw 'first row is not a header' }
    if ($rows[-1].Kind -ne 'Tweak') { throw 'last row is not a tweak' }
}

Check 'no category header is left without tweaks under it' {
    $rows = @(New-UIRow)
    for ($i = 0; $i -lt $rows.Count; $i++) {
        if ($rows[$i].Kind -ne 'Header') { continue }
        if ($i + 1 -ge $rows.Count -or $rows[$i + 1].Kind -ne 'Tweak') {
            throw "header '$($rows[$i].Category)' has no tweaks"
        }
    }
}

Check 'every risk level maps to a console colour' {
    foreach ($t in $Tweaks) {
        $c = Get-RiskColor $t.Risk
        if ($c -notin [enum]::GetNames([ConsoleColor])) { throw "$($t.Risk) mapped to '$c'" }
    }
}

Check 'the relaunch command line quotes a script path containing spaces' {
    # The repo lives in "Tweak Collection" on the author's machine; an unquoted path
    # would silently relaunch with the wrong file.
    $line = Get-RelaunchArgument 'D:\Dev\Tweak Collection\scripts\Tweaks.ps1' @{}
    if ($line -notmatch '-File "D:\\Dev\\Tweak Collection\\scripts\\Tweaks\.ps1"') {
        throw "script path was not quoted: $line"
    }
    if ($line -notmatch '-ExecutionPolicy Bypass') { throw 'execution policy not bypassed' }
}

Check 'the relaunch command line carries switches, values and arrays through' {
    $bound = @{
        Apply          = @('privacy', 'latency')
        BackupPath     = 'D:\my backups\state.json'
        NoRestorePoint = [switch]$true
    }
    $line = Get-RelaunchArgument 'C:\t.ps1' $bound

    if ($line -notmatch '-Apply "privacy,latency"') { throw "array not passed: $line" }
    if ($line -notmatch '-BackupPath "D:\\my backups\\state\.json"') { throw "path not quoted: $line" }
    if ($line -notmatch '-NoRestorePoint(\s|$)') { throw "switch not passed: $line" }
    # A switch must not be followed by a value, or the next parameter binds to it.
    if ($line -match '-NoRestorePoint "') { throw "switch got a value: $line" }
}

Check 'a switch that is present but false is not passed on' {
    $line = Get-RelaunchArgument 'C:\t.ps1' @{ NoRestorePoint = [switch]$false }
    if ($line -match 'NoRestorePoint') { throw "an off switch was forwarded: $line" }
}

Check 'the frame layout never reaches the last row or column' {
    # Painting the bottom-right cell scrolls the console and breaks the whole frame.
    foreach ($w in 62, 63, 80, 100, 120, 200) {
        foreach ($h in 16, 17, 24, 30, 50) {
            $l = Get-FrameLayout $w $h 27 0
            if ($l.Left -lt 0) { throw "${w}x${h}: negative left" }
            if ($l.Left + $l.BoxW - 1 -gt $w - 2) { throw "${w}x${h}: box reaches the last column" }
            if ($l.Top -lt 0) { throw "${w}x${h}: negative top" }
            if ($l.Top + $l.BoxH - 1 -gt $h - 2) { throw "${w}x${h}: box reaches the last row" }
            if ($l.IdW -lt 1) { throw "${w}x${h}: no room left for the tweak id" }
        }
    }
}

# Swap the renderer's output primitive for a collector, so a frame can be drawn and
# inspected without a console.
$script:Painted = @()
function Write-Seg([int]$X, [int]$Y, [string]$Text, $Fg, $Bg) {
    $script:Painted += [PSCustomObject]@{ X = $X; Y = $Y; Width = $Text.Length }
}

Check 'a drawn frame stays inside its own box at every terminal size' {
    $rows = @(New-UIRow)
    $selected = @{}
    $status = @{}
    $i = 0
    foreach ($t in $Tweaks) {
        $selected[$t.Id] = ($i % 3 -eq 0)
        # Cover all three status branches: applied, not applied, and unreadable.
        $status[$t.Id] = switch ($i % 3) { 0 { $true } 1 { $false } default { $null } }
        $i++
    }

    $cursors = @(0..($rows.Count - 1) | Where-Object { $rows[$_].Kind -eq 'Tweak' })

    foreach ($w in 62, 80, 120) {
        foreach ($h in 16, 24, 50) {
            $l = Get-FrameLayout $w $h $rows.Count 0
            foreach ($cursor in $cursors) {
                $offset = [Math]::Max(0, [Math]::Min($cursor, $rows.Count - $l.ViewH))
                $script:Painted = @()
                Write-TweakFrame $rows $cursor $offset $selected $status $l

                foreach ($p in $script:Painted) {
                    if ($p.X -lt $l.Left -or $p.X + $p.Width -gt $l.Left + $l.BoxW) {
                        throw "${w}x${h} cursor ${cursor}: write at x=$($p.X) w=$($p.Width) escapes the box"
                    }
                    if ($p.Y -lt $l.Top -or $p.Y -gt $l.Top + $l.BoxH - 1) {
                        throw "${w}x${h} cursor ${cursor}: write at y=$($p.Y) escapes the box"
                    }
                }
                $painted = @($script:Painted | ForEach-Object { $_.Y } | Sort-Object -Unique)
                if ($painted.Count -ne $l.BoxH) {
                    throw "${w}x${h}: painted $($painted.Count) rows, box is $($l.BoxH) tall"
                }
            }
        }
    }
}

$scratch = 'HKCU:\Software\WindowsTweaksSelfCheck'
try {
    Check 'restoring a value that did not exist deletes it again' {
        Set-RegValue $scratch 'Fresh' 'DWord' 1
        if ((Get-RegValue $scratch 'Fresh') -ne 1) { throw 'the value was not written' }
        Restore-RegValue $scratch 'Fresh' 'DWord' $null
        if ($null -ne (Get-RegValue $scratch 'Fresh')) { throw 'the value survived the restore' }
    }

    Check 'restoring a value that existed puts the old one back' {
        Set-RegValue $scratch 'Existing' 'DWord' 7
        $captured = Get-RegValue $scratch 'Existing'
        Set-RegValue $scratch 'Existing' 'DWord' 99
        Restore-RegValue $scratch 'Existing' 'DWord' $captured
        if ((Get-RegValue $scratch 'Existing') -ne 7) { throw 'the old value was not restored' }
    }

    Check 'a 0xFFFFFFFF DWord reads as applied on both PowerShell editions' {
        # NetworkThrottlingIndex is written as -1; PS 7 reads it back as [uint32].
        Set-RegValue $scratch 'Max' 'DWord' 0xFFFFFFFF
        if (-not (Test-RegValueEqual 'DWord' (Get-RegValue $scratch 'Max') 0xFFFFFFFF)) { throw 'max DWord compared unequal' }
        if (-not (Test-RegValueEqual 'DWord' ([uint32]::MaxValue) -1)) { throw 'uint32 vs int32 compared unequal' }
        if (Test-RegValueEqual 'DWord' 10 20) { throw 'different values compared equal' }
        if (Test-RegValueEqual 'DWord' $null 0) { throw 'missing value compared equal' }
    }

    Check 'string values survive a round trip' {
        Set-RegValue $scratch 'Text' 'String' 'High'
        if ((Get-RegValue $scratch 'Text') -ne 'High') { throw 'string value was mangled' }
    }
}
finally {
    Remove-Item -Path $scratch -Recurse -Force -ErrorAction SilentlyContinue
}

$tempBackup = Join-Path ([IO.Path]::GetTempPath()) ("tweaks-selfcheck-{0}.json" -f [guid]::NewGuid())
try {
    Check 'the backup file round-trips nested state' {
        $map = @{
            'net.nagle' = @{
                CapturedAt = '2026-01-01T00:00:00.0000000+00:00'
                State      = @{ Interfaces = @(@{ Path = 'HKLM:\x'; TcpAckFrequency = $null; TCPNoDelay = 2 }) }
            }
        }
        Export-Backup $map $tempBackup
        $read = Import-Backup $tempBackup
        if (-not $read.ContainsKey('net.nagle')) { throw 'the entry was lost' }
        $iface = $read['net.nagle'].State.Interfaces[0]
        if ($iface.TCPNoDelay -ne 2) { throw 'a value was mangled' }
        # $null means "did not exist" and drives a delete on revert, so it must survive.
        if ($null -ne $iface.TcpAckFrequency) { throw 'a null was not preserved' }
    }

    Check 'a missing backup file reads as empty rather than throwing' {
        $absent = Join-Path ([IO.Path]::GetTempPath()) ("tweaks-absent-{0}.json" -f [guid]::NewGuid())
        if ((Import-Backup $absent).Count -ne 0) { throw 'expected an empty map' }
    }
}
finally {
    Remove-Item -Path $tempBackup -Force -ErrorAction SilentlyContinue
}

if ($failed -gt 0) {
    Write-Host "$failed check(s) failed." -ForegroundColor Red
    exit 1
}
Write-Host 'All checks passed.' -ForegroundColor Green
