Option Explicit

Dim fso, shell, scriptDir, readerScript, markdownPath, command

If WScript.Arguments.Count < 1 Then
    MsgBox "No Markdown file path was provided.", vbExclamation, "MarkLens"
    WScript.Quit 1
End If

Set fso = CreateObject("Scripting.FileSystemObject")
Set shell = CreateObject("WScript.Shell")
scriptDir = fso.GetParentFolderName(WScript.ScriptFullName)
readerScript = fso.BuildPath(scriptDir, "MarkLens.ps1")
markdownPath = WScript.Arguments(0)

command = "powershell.exe -NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File " & _
          Chr(34) & readerScript & Chr(34) & " -Path " & Chr(34) & markdownPath & Chr(34)

shell.Run command, 0, False
