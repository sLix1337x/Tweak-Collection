Option Explicit

Dim fso, sh, dir, ps, script, args
Set fso = CreateObject("Scripting.FileSystemObject")
Set sh  = CreateObject("WScript.Shell")

dir    = fso.GetParentFolderName(WScript.ScriptFullName)
script = dir & "\USB-LatencySuite.ps1"
ps     = sh.ExpandEnvironmentStrings("%SystemRoot%") & "\System32\WindowsPowerShell\v1.0\powershell.exe"

If Not fso.FileExists(script) Then
    MsgBox "USB-LatencySuite.ps1 was not found next to this launcher.", 16, "USB Latency Suite"
    WScript.Quit 1
End If

args = "-NoProfile -STA -WindowStyle Hidden -ExecutionPolicy Bypass -File """ & script & """"

On Error Resume Next
CreateObject("Shell.Application").ShellExecute ps, args, dir, "runas", 0
If Err.Number <> 0 Then
    MsgBox "USB Latency Suite needs administrator rights to run.", 16, "USB Latency Suite"
End If
