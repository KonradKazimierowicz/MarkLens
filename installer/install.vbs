Option Explicit

Dim fso, shell, scriptDir, installerScript, payloadZip, command, exitCode
Dim isQuiet, installRoot, skipRegistration
Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
isQuiet = WScript.Arguments.Named.Exists("quiet")
skipRegistration = WScript.Arguments.Named.Exists("skipregistration")
installRoot = ""
If WScript.Arguments.Named.Exists("installroot") Then
    installRoot = WScript.Arguments.Named.Item("installroot")
End If
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
installerScript = fso.BuildPath(scriptDir, "Install-MarkLens.ps1")
payloadZip = fso.BuildPath(scriptDir, "payload.zip")
command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & _
          Chr(34) & installerScript & Chr(34) & " -PayloadZip " & Chr(34) & payloadZip & Chr(34) & " -Quiet"
If Len(installRoot) > 0 Then
    command = command & " -InstallRoot " & Chr(34) & installRoot & Chr(34)
End If
If skipRegistration Then
    command = command & " -SkipRegistration"
End If
exitCode = shell.Run(command, 0, True)

If Not isQuiet Then
    If exitCode = 0 Then
        shell.Popup "Installation completed." & vbCrLf & vbCrLf & _
                    "Double-click a .md or .markdown file to read it with MarkLens.", _
                    10, "MarkLens", 64
    Else
        shell.Popup "Installation failed with exit code " & exitCode & ".", _
                    30, "MarkLens installation error", 16
    End If
End If

WScript.Quit exitCode
