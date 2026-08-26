Option Explicit

Dim fso, shell, scriptDir, installerScript, payloadZip, command, exitCode
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
installerScript = fso.BuildPath(scriptDir, "Install-MarkLens.ps1")
payloadZip = fso.BuildPath(scriptDir, "payload.zip")
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & _
          Chr(34) & installerScript & Chr(34) & " -PayloadZip " & Chr(34) & payloadZip & Chr(34)
exitCode = shell.Run(command, 0, True)
WScript.Quit exitCode
