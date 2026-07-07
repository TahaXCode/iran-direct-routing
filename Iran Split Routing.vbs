' Double-click launcher: opens the Iran Split Routing app with no console flash.
' The PowerShell GUI itself asks for admin (UAC) since adding routes needs it.
Set sh = CreateObject("WScript.Shell")
p = Left(WScript.ScriptFullName, InStrRev(WScript.ScriptFullName, "\"))
sh.Run "powershell -NoProfile -ExecutionPolicy Bypass -Sta -WindowStyle Hidden -File """ & p & "IranSplitRouting.ps1""", 0, False
