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

myGui.AddGroupBox("Section xs w250 h150", "Wait Type:")
myGui.AddButton("vWT1000 xs+40 ys+20 w80 Center Disabled", "S&econds").OnEvent("Click", HandleButton)
myGui.AddButton("vWT60000 xp+90 yp w80 Center", "&Minutes").OnEvent("Click", HandleButton)
myGui.AddButton("vWT3600000 xs+40 yp+32 w80 Center", "&Hours").OnEvent("Click", HandleButton)
myGui.AddButton("vWT86400000 xp+90 yp w80 Center", "&Days").OnEvent("Click", HandleButton)
myGui.AddButton("vWTP xs+40 yp+32 w170 Center", "&PARTICULAR  DATE-TIME").OnEvent("Click", HandleButton)
myGui.AddButton("vWTX xs+40 yp+32 w80 Center", "E&XE").OnEvent("Click", HandleButton)
myGui.AddButton("vWTW xp+90 yp w80 Center", "H&WND").OnEvent("Click", HandleButton)

myGui.AddGroupBox("Section xs w250 h55", "Wait Amount:")
myEDIT:= myGui.AddEdit("vWA1 xs+40 ys+20 w170 Center Number")
myDT:= myGui.AddDateTime("vWA2 xp yp wp Hidden 1 Range" A_Now, "   yyyy/MM/dd       HH:mm:ss")
myDDL:= myGui.AddDropDownList("vWA3 xp yp wp r7 Hidden Sort")
PostMessage(0x0160, 500, 0, myDDL.Hwnd) ; expand DDL dropped width
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
		if (SubStr(Button.Name, -1) == "P") {
			myDDL.Visible:= 0
			myDT.Visible:= 1
			myEDIT.Visible:= 0
			myDT.Value:= A_Now
		} else if ((SubStr(Button.Name, -1) == "W") || (SubStr(Button.Name, -1) == "X")) {
			myDDL.Delete() ; clear array
			myDDL.Visible:= 1
			myDT.Visible:= 0
			myEDIT.Visible:= 0
			if (SubStr(Button.Name, -1) == "W") {
				for id in WinGetList() {
					winProcName:= WinGetProcessName("ahk_id " id)
					winTitle:= WinGetTitle("ahk_id " id) ? (" ||| " WinGetTitle("ahk_id " id)) : ""
					myDDL.Add([winProcName winTitle " ||| {" id "}"])
				}
			} else {
				for proc in ComObjGet("winmgmts:").ExecQuery("Select * from Win32_Process") {
					Try pidTitle:= " ||| " WinGetTitle("ahk_pid " proc.ProcessId)
					Catch
						pidTitle:= ""
					myDDL.Add([proc.Name pidTitle " ||| {" proc.ProcessId "}"])
				}
			}
		} else { ; if it's a unit of time
			myDDL.Visible:= 0
			myDT.Visible:= 0
			myEDIT.Visible:= 1
		}
	}
	foc:= (myEDIT.Visible ? "EDIT" : (myDT.Visible ? "DT" : "DDL"))
	my%foc%.Focus()
	(myDDL.Visible ? ControlShowDropDown(myDDL.Hwnd) : "")
}

SubmitGui(*) {
	myGui.Submit()
	global COMMAND, Milliseconds, myDays, myHours, myMinutes, mySeconds, myText1, myText2, myText3, UnitType
	AMOUNT:= myDT.Visible ? myDT.Value : (!myEDIT.Value ? 0 : myEDIT.Value) ; set to DT or EDIT (and if EDIT blank, set to 0)
	for control in myGui { ; find the disabled controls and get their names/values
		test:= SubStr(control.Name, 1, 2) ; get first two characters of variable name
		if (test == "PS") && !control.Enabled {
			COMMAND:= SubStr(control.Name, -1) ; set to last digit of control's name
			PowerState:= StrReplace(control.Text, "&") ; get power state name
		}
		if (test == "WT") && !control.Enabled
			UnitType:= SubStr(control.Name, 3) ; set to last digits of control's name
	}
	Milliseconds:= (((UnitType == "W") || (UnitType == "X")) ? (myDDL.Text) : ((UnitType == "P") ? (DateDiff(AMOUNT, A_Now, "Seconds") * 1000) : (AMOUNT * UnitType))) ; calculate total time
	if (Milliseconds = "") {
		myGui.Show()
		foc:= (myEDIT.Visible ? "EDIT" : (myDT.Visible ? "DT" : "DDL"))
		my%foc%.Focus()
		(myDDL.Visible ? ControlShowDropDown(myDDL.Hwnd) : "")
		Return
	}

	; Create Countdown GUI
	art:= (!myDDL.Visible ? " in:" : (" after " ((UnitType == "W") ? "WINDOW" : "EXE") " closure:"))
	myGui2:= Gui("+AlwaysOnTop +Border +ToolWindow", "OS will " PowerState art)
	myGui2.BackColor:= "Black"
	myGui2.SetFont("Bold cRed")
	myGui2.OnEvent("Close", (*) => ExitApp())
	myGui2.OnEvent("Escape", (*) => ExitApp())
	if myDDL.Visible {
		myGui2.AddText("y+15", "PROCESS:")
		myText1:= myGui2.AddEdit("x75 yp w190 BackgroundBlack cYellow ReadOnly -E0x200")
		myGui2.AddText("xs+45 y+2", "ID:")
		myText2:= myGui2.AddEdit("x75 yp w190 BackgroundBlack cYellow ReadOnly -E0x200")
		myGui2.AddText("xs y+2", "WINTITLE:")
		myText3:= myGui2.AddEdit("x75 yp w190 BackgroundBlack cYellow ReadOnly -E0x200")
	} else {
		myGui2.AddText(, "DAYS       HOURS       MINUTES       SECONDS")
		myGui2.AddText("x52 yp", ":")
		myGui2.AddText("x118 yp", ":")
		myGui2.AddText("x194 yp", ":")
		myGui2.AddText("x52 y+2", ":")
		myGui2.AddText("x118 yp", ":")
		myGui2.AddText("x194 yp", ":")
		myDays:= myGui2.AddText("x21 yp", "00")
		myHours:= myGui2.AddText("x81 yp", "00")
		myMinutes:= myGui2.AddText("x152 yp", "00")
		mySeconds:= myGui2.AddText("x230 yp", "00")
	}
	myGui2.AddButton("xs y+7 w75 Center Default", "&Edit").OnEvent("Click", (*) => Reload())
	myGui2.AddButton("xp+180 yp w75 Center", "&CANCEL").OnEvent("Click", (*) => ExitApp())
	myGui2.AddButton("xs+90 yp w75 Center", "&show proc?").OnEvent("Click", ShowProc)
	myGui2.Show()

	; Begin Timer
	CountdownTimer() ; immediately execute timer so no awkwardness
	if IsNumber(Milliseconds) ; ignore starting timer if waiting on EXE / HWND
		SetTimer(CountdownTimer, 1000)
}


CountdownTimer(*) {
	global Milliseconds, myDays, myHours, myMinutes, mySeconds, myText1, myText2, myText3, UnitType, winID
	if (!IsNumber(Milliseconds) || (Milliseconds < 1)) { ; if wait is 0 or negative or a string
		if !IsNumber(Milliseconds) {
			myText2.Text:= winID:= RegExReplace(Milliseconds, "m)^.*{(\d+)}$", "$1")
			myText1.Text:= WinGetProcessName(((UnitType == "W") ? "ahk_id " : "ahk_pid ") winID)
			Try myText3.Text:= WinGetTitle(((UnitType == "W") ? "ahk_id " : "ahk_pid ") winID)
			ControlFocus(myText3)
			((UnitType == "W") ? WinWaitClose("ahk_id " winID) : ProcessWaitClose(winID))
		}
		InitiatePowerAction(COMMAND)
		Return
	} else {
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
}


ShowProc(*) {
	Try WinActivate(((UnitType == "W") ? "ahk_id " : "ahk_pid ") winID)
}


InitiatePowerAction(COMMAND) {
	; Call ZwInitiatePowerAction (MUST enable SeShutdownPrivilege BEFORE this call)
	; COMMAND Action type: 1=Shutdown, 2=StandbyS3/Sleep, 3=Hibernate, 4=Reboot/Restart
	DllCall("ntdll\ZwInitiatePowerAction", "int", COMMAND, "int", 4, "int", 0x80000000, "int", 1)
	ExitApp
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
