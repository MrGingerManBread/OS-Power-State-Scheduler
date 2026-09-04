#Requires AutoHotkey v2+ 64-bit
#NoTrayIcon
#SingleInstance Force ; forces a single instance of this script
#Warn All, Off

; Setup
SetPowerPrivilege() ; Enable SeShutdownPrivilege


; Create Main GUI
myGui:= Gui("+AlwaysOnTop +Border +ToolWindow", SubStr(A_ScriptName, 1, -4))
myGui.BackColor:= "Black"
myGui.SetFont("Bold cRed")
myGui.OnEvent("Close", (*) => ExitApp())
myGui.OnEvent("Escape", (*) => ExitApp())

myGui.AddGroupBox("Section w250 h55", "Power State:")
myGui.AddButton("vPS2 xs+10 ys+20 w55 Center Disabled", "&SLEEP").OnEvent("Click", HandleButton)
myGui.AddButton("vPS1 xp+65 yp w85 Center", "SH&UTDOWN").OnEvent("Click", HandleButton)
myGui.AddButton("vPS4 xp+95 yp w70 Center", "&RESTART").OnEvent("Click", HandleButton)

myGui.AddGroupBox("Section xs w250 h118", "Wait Type:")
myGui.AddButton("vWT1000 xs+40 ys+20 w80 Center Disabled", "S&econds").OnEvent("Click", HandleButton)
myGui.AddButton("vWT60000 xp+90 yp w80 Center", "&Minutes").OnEvent("Click", HandleButton)
myGui.AddButton("vWT3600000 xs+40 yp+32 w80 Center", "&Hours").OnEvent("Click", HandleButton)
myGui.AddButton("vWT86400000 xp+90 yp w80 Center", "&Days").OnEvent("Click", HandleButton)
myGui.AddButton("vWTP xs+40 yp+32 w170 Center", "&PARTICULAR  DATE-TIME").OnEvent("Click", HandleButton)

myGui.AddGroupBox("Section xs w250 h55", "Wait Amount:")
myEDIT:= myGui.AddEdit("vWA1 xs+40 ys+20 w170 Center Number")
myDT:= myGui.AddDateTime("vWA2 xs+40 ys+20 w170 Hidden 1 Range" A_Now, "   yyyy/MM/dd       HH:mm:ss")

myGui.AddButton("xp y+25 w170 Center Default", "─→   ENTER   ←─").OnEvent("Click", SubmitGui)


; Show GUI
myGui.Show()
myEDIT.Focus()
Return

HandleButton(Button, *) {
	; Button.Name = variable name //// Button.Text = label
	test:= SubStr(Button.Name, 1, 2) ; get first two characters of variable name
	for control in myGui {
		if SubStr(control.Name, 1, 2) == test
			control.Enabled:= (control.Name == Button.Name) ? 0 : 1 ; toggle all buttons in same section
	}
	if (test == "WT") {
		if (Button.Name == "WTP") {
			myDT.Value:= A_Now
			myEDIT.Visible:= 0
			myDT.Visible:= 1
		} else {
			myEDIT.Visible:= 1
			myDT.Visible:= 0
		}
	}
	foc:= myEDIT.Visible ? "EDIT" : "DT"
	my%foc%.Focus()
}

SetPowerPrivilege(*) {
	PID:= ProcessExist() ; Sets PID of this running script
	h:= DllCall("OpenProcess", "UInt", 0x0400, "Int", false, "UInt", PID, "Ptr")
	DllCall("Advapi32.dll\OpenProcessToken", "Ptr", h, "UInt", 32, "Ptr*", &t:= 0)
	ti:= Buffer(16, 0)
	NumPut("UInt", 1, ti, 0)  ; One entry in the privileges array
	DllCall("Advapi32.dll\LookupPrivilegeValue", "Ptr", 0, "Str", "SeShutdownPrivilege", "Int64*", &luid:= 0)
	NumPut("Int64", luid, ti, 4)
	NumPut("UInt", 2, ti, 12)  ; SE_PRIVILEGE_ENABLED = 2
	DllCall("Advapi32.dll\AdjustTokenPrivileges", "Ptr", t, "Int", false, "Ptr", ti, "UInt", 0, "Ptr", 0, "Ptr", 0)
	DllCall("CloseHandle", "Ptr", t)
	DllCall("CloseHandle", "Ptr", h)
}

SubmitGui(*) {
    myGui.Submit()
    global AMOUNT:= myDT.Visible ? myDT.Value : (!myEDIT.Value ? 0 : myEDIT.Value) ; set to DT or EDIT (and if EDIT blank, set to 0)
	for control in myGui {
        test:= SubStr(control.Name, 1, 2) ; get first two characters of variable name
		if (test == "PS") && !control.Enabled {
			global COMMAND:= SubStr(control.Name, -1) ; set to last digit of control's name
            PowerState:= StrReplace(control.Text, "&")
        }
		if (test == "WT") && !control.Enabled
			global UnitType:= SubStr(control.Name, 3) ; set to last digits of control's name
	}
    global Milliseconds
    if (UnitType == "P")
        Milliseconds:= DateDiff(AMOUNT, A_Now, "Seconds") * 1000
    else
        Milliseconds:= AMOUNT * UnitType ; total wait time in milliseconds
    if (Milliseconds < 1) { ; if wait is 0 or negative, immediately initiate
        InitiatePowerAction(COMMAND)
        Return
    }

    ; Create Countdown GUI
    myGui2:= Gui("+AlwaysOnTop +Border +ToolWindow", "OS will " PowerState " in:")
    myGui2.BackColor:= "Black"
    myGui2.SetFont("Bold cRed")
    myGui2.OnEvent("Close", (*) => ExitApp())
    myGui2.OnEvent("Escape", (*) => ExitApp())
    myGui2.AddText(, "DAYS       HOURS       MINUTES       SECONDS")
    myGui2.AddText("x52 yp", ":")
    myGui2.AddText("x118 yp", ":")
    myGui2.AddText("x194 yp", ":")
    myGui2.AddText("x52 y+2", ":")
    myGui2.AddText("x118 yp", ":")
    myGui2.AddText("x194 yp", ":")
    global myDays:= myGui2.AddText("x21 yp", "00")
    global myHours:= myGui2.AddText("x81 yp", "00")
    global myMinutes:= myGui2.AddText("x152 yp", "00")
    global mySeconds:= myGui2.AddText("x230 yp", "00")
    myGui2.AddButton("xs y+7 w75 Center Default", "&Edit").OnEvent("Click", (*) => Reload())
    myGui2.AddButton("xp+180 yp w75 Center", "&CANCEL").OnEvent("Click", (*) => ExitApp())
    myGui2.Show()

    ; Begin Timers
    CountdownTimer() ; immediately execute timer so no awkwardness
    SetTimer(CountdownTimer, 1000)
}


CountdownTimer(*) {
    global Milliseconds, myDays, myHours, myMinutes, mySeconds
    if (Milliseconds < 1) {
        InitiatePowerAction(COMMAND)
        Return
    }

    ; Calc and display time components
    RemainingMs:= Milliseconds
    myDays.Text:= Format("{:02}", Floor(RemainingMs // 86400000))
    RemainingMs-= myDays.Text * 86400000
    myHours.Text:= Format("{:02}", Floor(RemainingMs // 3600000))
    RemainingMs-= myHours.Text * 3600000
    myMinutes.Text:= Format("{:02}", Floor(RemainingMs // 60000))
    RemainingMs-= myMinutes.Text * 60000
    mySeconds.Text:= Format("{:02}", Floor(RemainingMs // 1000))

    Milliseconds -= 1000
}


InitiatePowerAction(COMMAND) {
    ; Call ZwInitiatePowerAction (MUST enable SeShutdownPrivilege BEFORE this call)
    ; COMMAND Action type: 1=Shutdown, 2=StandbyS3/Sleep, 3=Hibernate, 4=Reboot/Restart
    DllCall("ntdll\ZwInitiatePowerAction", "int", COMMAND, "int", 4, "int", 0x80000000, "int", 1)
    ExitApp
}
