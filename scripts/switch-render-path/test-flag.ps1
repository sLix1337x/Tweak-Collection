<#
.SYNOPSIS
    Self-check for the per-exe compatibility-flag writer (Kind = 'Flag').

.DESCRIPTION
    The flag writer edits ONE word inside a space-separated list that belongs to
    Windows and carries other people's settings (RUNASADMIN, HIGHDPIAWARE, ...).
    Getting it wrong silently destroys compatibility settings the user set by
    hand, so it gets a test.

    Writes only to a scratch key of its own - HKCU:\Software\render-path-test -
    and removes it at the end. Touches nothing the tool manages. No elevation.

    Exit code 0 = all checks passed, 1 = a check failed.
#>
#requires -Version 5.1
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
Set-StrictMode -Version Latest

# Load the tool's functions without running it: dot-source everything above the
# entry point. Guarded so the script's own parameters and menu never execute.
$src   = Get-Content -LiteralPath (Join-Path $PSScriptRoot 'Switch-RenderPath.ps1') -Raw
$start = $src.IndexOf('# SCREEN')
$end   = $src.IndexOf('# ENTRY POINT')
if ($start -lt 0 -or $end -lt 0) { throw 'Switch-RenderPath.ps1 markers moved - update this test.' }
# From the SCREEN banner to the entry point: every definition, none of the
# startup code. The part skipped is the param block, $ScriptDir and $BackupRoot,
# which belong to a run and would need a real invocation to resolve.
. ([scriptblock]::Create($src.Substring($start, $end - $start)))

$Key    = 'HKCU:\Software\render-path-test'
$Exe    = 'C:\test\game.exe'
$failed = 0

function Check {
    param([string]$What, $Expected, $Actual)
    $e = if ($null -eq $Expected) { '<absent>' } else { "$Expected" }
    $a = if ($null -eq $Actual)   { '<absent>' } else { "$Actual" }
    if ($e -ceq $a) { Write-Host "  ok    $What" -ForegroundColor Green }
    else {
        Write-Host "  FAIL  $What" -ForegroundColor Red
        Write-Host "        expected: $e" -ForegroundColor Red
        Write-Host "        actual:   $a" -ForegroundColor Red
        $script:failed++
    }
}

function Seed {
    param($Value)
    if (Test-Path -LiteralPath $Key) { Remove-Item -LiteralPath $Key -Recurse -Force }
    New-Item -Path $Key -Force | Out-Null
    if ($null -ne $Value) {
        New-ItemProperty -LiteralPath $Key -Name $Exe -PropertyType String -Value $Value -Force | Out-Null
    }
}
function Raw { (Get-RawValue -Path $Key -Name $Exe) }
function SetFlag { param($Target) Set-FlagValue -Path $Key -Name $Exe -Token $FsoFlag -Target $Target }
function GetFlag { Get-FlagValue -Path $Key -Name $Exe -Token $FsoFlag }

Write-Host ''
Write-Host 'per-exe compatibility flag writer' -ForegroundColor Cyan
Write-Host ''

try {
    # Setting the flag on an exe Windows has no entry for creates the entry,
    # with the '~' marker Windows itself writes.
    Seed $null
    SetFlag $FsoFlag
    Check 'set on an exe with no entry' "~ $FsoFlag" (Raw)
    Check 'reads back as set'           $FsoFlag     (GetFlag)

    # THE ONE THAT MATTERS: other flags on the same exe must survive.
    Seed '~ RUNASADMIN HIGHDPIAWARE'
    SetFlag $FsoFlag
    Check 'siblings survive the set' "~ RUNASADMIN HIGHDPIAWARE $FsoFlag" (Raw)
    SetFlag $null
    Check 'siblings survive the clear' '~ RUNASADMIN HIGHDPIAWARE' (Raw)
    Check 'reads back as absent'       $null                       (GetFlag)

    # Clearing the last real flag removes the value: a lone '~' is an empty
    # list, and leaving it behind means an exe listed as "customised" forever.
    Seed "~ $FsoFlag"
    SetFlag $null
    Check 'lone flag cleared removes the value' $null (Raw)

    # Setting what is already set must not duplicate the word.
    Seed "~ $FsoFlag"
    SetFlag $FsoFlag
    Check 'no duplicate on re-set' "~ $FsoFlag" (Raw)

    # An entry Windows wrote without the marker stays valid; the marker is added.
    Seed 'RUNASADMIN'
    SetFlag $FsoFlag
    Check 'marker added when missing' "~ RUNASADMIN $FsoFlag" (Raw)

    # Substring must not count as the flag.
    Seed '~ DISABLEDXMAXIMIZEDWINDOWEDMODEX'
    Check 'longer word is not the flag' $null (GetFlag)

    # Entry-level round trip through the same interface the tool uses.
    Seed '~ RUNASADMIN'
    $entry = New-GameEntry -Exe $Exe
    $entry.Path = $Key
    Check 'entry reads On when absent'  $true (Test-EntryIs -Entry $entry -State 'On')
    Set-EntryTo -Entry $entry -State 'Off'
    Check 'entry verifies Off after write' $true (Test-EntryIs -Entry $entry -State 'Off')
    Set-EntryTo -Entry $entry -State 'On'
    Check 'entry verifies On after clear'  $true (Test-EntryIs -Entry $entry -State 'On')
    Check 'round trip left siblings alone' '~ RUNASADMIN' (Raw)
}
finally {
    if (Test-Path -LiteralPath $Key) { Remove-Item -LiteralPath $Key -Recurse -Force }
}

Write-Host ''
if ($failed -gt 0) {
    Write-Host "$failed check(s) FAILED." -ForegroundColor Red
    Write-Host ''
    exit 1
}
Write-Host 'All checks passed. Scratch key removed.' -ForegroundColor Green
Write-Host ''
