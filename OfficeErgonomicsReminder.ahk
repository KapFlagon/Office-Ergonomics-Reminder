; ***** Script Settings ***** ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.
#SingleInstance Force           ; Force single instance of the script so User cannot have multiple running
DetectHiddenWindows, On 
#Persistent  

; If Script is exited by any means, call the L_exitSub label
OnExit, L_exitSub

; Tell script to expect a system level message, and what function to call if it is met
; Commented out temporarily
OnMessage(0x218, "F_WM_POWERBROADCAST")
OnMessage(0x11, "F_WM_QUERYENDSESSION")
OnMessage(0x02B1, "F_WM_WTSSESSION_CHANGE")

; ***** Auto Execute block ***** ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Icon for test file
; Menu, Tray, Icon, ; path to icon here
Menu, Tray, Add
Menu, Tray, Add, Current Timer, L_openTimerCount
Menu, Tray, Add, Open TLog file folder, L_openLogfileFolder
Menu, Tray, Add, Open TLog file, L_openLogfile
Menu, Tray, Add, Read TLog file, L_logFileReaderGUI

; Triggers a "run as admin" check, prompts user to run as admin
; must be at top of script
if not A_IsAdmin
{
   Run *RunAs "%A_ScriptFullPath%"  
   ExitApp
}


;#Include %A_ScriptDir%\Lib\SecondCounter.ahk   ; works, explicitly calls the file
#Include %A_ScriptDir%\Lib\MySecondCounter.ahk   ; works, explicitly calls the file
#Include %A_ScriptDir%\Lib\TimeCalculator.ahk   ; 

; ***** Global Script Variables ***** ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Variables for detecting screen lock and unlock (system session info)
hw_ahk = 
NOTIFY_FOR_THIS_SESSION =
result =

secondCounter := new MySecondCounter
secondCounter.F_start()
timeCalculator := new TimeCalculator


TotalNumberOfBreaks := 0
TotalSystemTime := 0
TotalLoggedOnTime := 0
TotalLoggedOffTime := 0
LongestWorkPeriod := 0
LongestBreakPeriod := 0
UserLoggedOn := true
AllLogonPeriods := []
AllLogoffPeriods := []

Threshold_1_warning := 3000
Threshold_2_break := 3600
Threshold_3_postBreak := 600
 
logfileDirectory := timeCalculator.F_generateLogDirectory()
logFileName := timeCalculator.F_generateLogfileName()

GoSub, L_buildSessionInfo

F_checkRegistry_Initial()

F_readSettingsINI()


; ***** Hotkeys ***** ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

; Key lexicon: 
;   #   Win (Windows logo key)
;   !   Alt
;   ^   Control
;   +   Shift

Hotkey, +!r, L_reloadScript                ;  reload the script
Hotkey, ^+!#b, L_testLogging
Hotkey, #L, L_logoffLog             ;  Winkey+L, Creates log entries, calcs data, logs you out, locks screen

F_checkForLogDirectory(logfileDirectory)
F_checkForLogFile()

SetTimer, L_checkBreakThresholds, 1000


; Ensure that there is a return statement here so that the auto-execute block ends
; In order to designate hotkeys in this way, it is actually part of the auto-execute block
return

; ***** Functions ***** ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

F_checkForLogFile() {
  Global
  timestamp := timeCalculator.F_generateTimestamp()
  fullPath := logfileDirectory . "\" . logFileName
  ;fullPath := test.txt
  logMessage := timestamp . "`t|`tTLog file created.`n"
  
  if FileExist(fullPath) {
    ; MsgBox, The logs folder exists
    F_parseExistingLogFile(fullPath)
    ;MsgBox, TotalLoggedOnTime: %TotalLoggedOnTime% `n`nTotalLoggedOffTime: %TotalLoggedOffTime% `n`nLongestWorkPeriod: %LongestWorkPeriod% `n`nLongestBreakPeriod: %LongestBreakPeriod%
    logMessage := timestamp . "`t|`tTLog file re-opened for continued use...`n"
    FileAppend, %logMessage%, %fullPath%
  } else {
    ;Msgbox, no log file
    FileAppend, %logMessage%, %fullPath%
    ;MsgBox, error level post writing: %ErrorLevel%
  }
}

F_checkForLogDirectory(logDirectoryPath:="logs") {
  if FileExist(logDirectoryPath) {
    ;MsgBox, The directory '%logDirectoryPath%' exists
  } else {
    ;MsgBox, The directory '%logDirectoryPath%' does not exist
    FileCreateDir, %logDirectoryPath%
  }
}

F_parseExistingLogFile(fullFilePath) {
  Global
  
  fullFileContent := ""
  endFlag := "secs ->"
  FileRead, fullFileContent, %fullFilePath%
  if errorlevel {
  	MsgBox, Error while reading existing log file. Code: %A_LastError%
    Return
  }
  ; (TLONT): " . TotalLoggedOnTime
  ; (TLOFT): " . TotalLoggedOffTime
  ; (LWP): " . LongestWorkPeriod
  ; (LBP): " . LongestBreakPeriod
  
  ;; resume
  s_pos_TLONT := InStr(fullFileContent, "(TLONT): ", false,0)
  s_pos_TLOFT := InStr(fullFileContent, "(TLOFT): ", false,0)
  s_pos_LWP := InStr(fullFileContent, "(LWP): ", false,0)
  s_pos_LBP := InStr(fullFileContent, "(LBP): ", false,0)
  s_pos_TNOB := InStr(fullFileContent, "(TNOB): ", false,0)
  s_pos_TST := InStr(fullFileContent, "(TST): ", false,0)
  
  e_pos_TLONT := InStr(fullFileContent, endFlag,false,s_pos_TLONT)
  e_pos_TLOFT := InStr(fullFileContent, endFlag,false,s_pos_TLOFT)
  e_pos_LWP := InStr(fullFileContent, endFlag,false,s_pos_LWP)
  e_pos_LBP := InStr(fullFileContent, endFlag,false,s_pos_LBP)
  e_pos_TNOB := InStr(fullFileContent, " - ",false,s_pos_TNOB)
  e_pos_TST := InStr(fullFileContent, endFlag,false,s_pos_TST)
  
  va_s_pos_TLONT := s_pos_TLONT + 9
  va_s_pos_TLOFT := s_pos_TLOFT + 9
  va_s_pos_LWP := s_pos_LWP + 7
  va_s_pos_LBP := s_pos_LBP + 7
  va_s_pos_TNOB := s_pos_TNOB + 8
  va_s_pos_TST := s_pos_TST + 7
  
  l_TLONT := e_pos_TLONT - va_s_pos_TLONT
  l_TLOFT := e_pos_TLOFT - va_s_pos_TLOFT
  l_LWP := e_pos_LWP - va_s_pos_LWP
  l_LBP := e_pos_LBP - va_s_pos_LBP
  l_TNOB := e_pos_TNOB - va_s_pos_TNOB
  l_TST := e_pos_TST - va_s_pos_TST
  
  ;MsgBox, s_pos_LBP: %s_pos_LBP% `ne_pos_LBP: %e_pos_LBP% `nva_s_pos_LBP: %va_s_pos_LBP% `nl_LBP: %l_LBP%
  
  
  TotalLoggedOnTime := SubStr(fullFileContent, va_s_pos_TLONT, l_TLONT)
  TotalLoggedOffTime := SubStr(fullFileContent, va_s_pos_TLOFT, l_TLOFT)
  LongestWorkPeriod := SubStr(fullFileContent, va_s_pos_LWP, l_LWP)
  LongestBreakPeriod := SubStr(fullFileContent, va_s_pos_LBP, l_LBP)
  TotalNumberOfBreaks := SubStr(fullFileContent, va_s_pos_TNOB, l_TNOB)
  TotalSystemTime := SubStr(fullFileContent, va_s_pos_TST, l_TST)
  
  ;MsgBox, vTotalLoggedOnTime: %vTotalLoggedOnTime% `n`nvTotalLoggedOffTime: %vTotalLoggedOffTime% `n`nvLongestWorkPeriod: %vLongestWorkPeriod% `n`nvLongestBreakPeriod: %vLongestBreakPeriod%
  
}

F_addToLogFile(logfileDirectory, logFileName, timestamp, messageText) {
    fullPath := logfileDirectory . "\" . logFileName
    logMessage := timestamp . "`t|`t" . messageText . "`n"
    FileAppend, %logMessage%, %fullPath%
}

; Detect a "Sleep" trigger from the start menu
F_WM_POWERBROADCAST(wParam, lParam) {
  Global 
  ; 0x0004 is PBT_APMSUSPEND, which notifies the system of a pending suspension of operation, 0x0005 is another related event
  if (wParam = 0x0004 OR wParam = 0x0005){
    F_logoffLogging()
    F_cycleWorkstationLock()
  }
  else {
    ; Some other power event not worthy of a screen lock
  }
}

; If system shutdown is triggered, script should perform the L_exitSub label
F_WM_QUERYENDSESSION(wParam, lParam) {
  ENDSESSION_LOGOFF = 0x80000000
  ;Gosub, L_exitSub_B
  ;Gosub, L_exitSub
  F_scriptCloseDown()
  return true ; tells the Windows OS to allow the shutdown
}

; If system status changes from lock / unlock, this function is executed to perform checks and actions
F_WM_WTSSESSION_CHANGE(p_w, p_l, p_m, p_hw) {
  ; Make global variables accessible 
  Global
  ;
  ;Msgbox, in F_WM_WTSSESSION_CHANGE method
  ; Session variables interpreted 
  ; WTS_SESSION_LOCK (0x7)
  ; WTS_SESSION_UNLOCK (0x8)
  WTS_SESSION_LOCK := 0x7
  WTS_SESSION_UNLOCK := 0x8
  ; need this to catch the logoff data, and refresh the session info
  if (p_w = WTS_SESSION_LOCK) {
    ; Screen locked,
    ; logic to log data already taken care of by hotkey label
    ; Simply rebuild session data
    ;MsgBox, screen lock detected by F_WM_WTSSESSION_CHANGE
    ;MsgBox, p_w : %p_w%
    GoSub, L_buildSessionInfo
  }
  ; This catches the logon session info
  else if (p_w = WTS_SESSION_UNLOCK) {
    ; Screen unlocked
    
    ; Logic to log logoff time here etc.
    F_logonLogging()
    ;MsgBox, p_w : %p_w%
    ;MsgBox, screen unlock detected by F_WM_WTSSESSION_CHANGE
    
    ; call subroutine to rebuild the session info
    GoSub, L_buildSessionInfo
  }
  ; Catch all other session codes, and simply rebuild the session info
  else {
    ; Other session status detected, do nothing
    ; Rebuild the session info
    ;MsgBox, p_w : %p_w%
    ;MsgBox, all other session events
    GoSub, L_buildSessionInfo
  }
}

; On the script startup, access the registry and override the screen lock by making the registry entry
F_checkRegistry_Initial() {
  Try {
    ; This registry entry disallows locking the workstation via built in windows hotkeys
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System, DisableLockWorkstation, 1
  } catch, e1 {
    Msgbox % "Error: " e1.What "`nCould not access Registry during F_checkRegistry_Initial()...`nCalled at line number: " e1.Line "`nError code: " e1.Message "`nPlease ensure that you run the script as an Administrator.`nWARNING: Script will not function correctly when not run as Administrator."
  }
}

F_cycleWorkstationLock() {
  ; Use a try for any such actions
  ;MsgBox, in outer element of cycleWorkstationLock method
  try {
    ;MsgBox, here 0
    ; Turns off the 'disable lock workstation' regedit entry
    RegWrite, REG_DWORD, HKEY_CURRENT_USER\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System, DisableLockWorkstation, 0
    ;MsgBox, in inner element of cycleWorkstationLock method, post reg edit 1
    ; Lock the workstation with the dll
    DllCall("LockWorkStation")
    ;MsgBox, here 2
    sleep, 1000
    ; turn back on the 'disable lock workstation' regedit entry
    RegWrite, REG_DWORD, HKEY_CURRENT_USER, SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System, DisableLockWorkstation, 1
    ;MsgBox, in inner element of cycleWorkstationLock method, post reg edit 2
  } catch e2 {
    ; Catch the error and display a message
    Msgbox % "Error: " e2.What "`nCould not cycle registry values.`nCalled at line number: " e2.Line "`nError code: " e2.Message 
  }
}

F_scriptCloseDown() {
  Global
  LoggedOnTime := secondCounter.F_getCount()
  TotalLoggedOnTime := TotalLoggedOnTime + LoggedOnTime
  if(LoggedOnTime > LongestWorkPeriod) {
    LongestWorkPeriod := LoggedOnTime
  }
  F_addToLogFile(logfileDirectory, logFileName, timeCalculator.F_generateTimestamp(), "Log program closed")
  
  TotalSystemTime := TotalLoggedOnTime + TotalLoggedOffTime
  
  message_TotalLoggedOnTime := "Total time logged on (TLONT): " . TotalLoggedOnTime . " secs -> " . timeCalculator.F_convertSecsToHHMMSS(TotalLoggedOnTime)
  message_TotalLoggedOffTime := "Total time logged off (TLOFT): " . TotalLoggedOffTime . " secs -> " . timeCalculator.F_convertSecsToHHMMSS(TotalLoggedOffTime)
  message_LongestWorkPeriod := "Longest work period without break (LWP): " . LongestWorkPeriod . " secs -> " . timeCalculator.F_convertSecsToHHMMSS(LongestWorkPeriod)
  message_LongestBreakPeriod := "Longest break period (LBP): " . LongestBreakPeriod . " secs -> " . timeCalculator.F_convertSecsToHHMMSS(LongestBreakPeriod)
  message_TotalNumberOfBreaks := "Total number of breaks (TNOB): " . TotalNumberOfBreaks . " - "
  message_TotalSystemTime := "Total system time (TST): " . TotalSystemTime . " secs -> " . timeCalculator.F_convertSecsToHHMMSS(TotalSystemTime)
  
  F_addToLogFile(logfileDirectory, logFileName, timeCalculator.F_generateTimestamp(), message_TotalLoggedOnTime)
  F_addToLogFile(logfileDirectory, logFileName, timeCalculator.F_generateTimestamp(), message_TotalLoggedOffTime)
  F_addToLogFile(logfileDirectory, logFileName, timeCalculator.F_generateTimestamp(), message_LongestWorkPeriod)
  F_addToLogFile(logfileDirectory, logFileName, timeCalculator.F_generateTimestamp(), message_LongestBreakPeriod)
  F_addToLogFile(logfileDirectory, logFileName, timeCalculator.F_generateTimestamp(), message_TotalNumberOfBreaks)
  F_addToLogFile(logfileDirectory, logFileName, timeCalculator.F_generateTimestamp(), message_TotalSystemTime)
  
}

F_checkBreakThresholds(passedSecs) {
  Global
  ;10mins_s := 600
  ;15mins_s := 900
  ;50mins_s := 3000
  ;60mins_s := 3600
  
  messageType := ""
  messageText := ""
  createLog := false
    
  if (UserLoggedOn) {
    if(passedSecs >= Threshold_1_warning) {
      modValue_firstThreshold := Mod(passedSecs, (Threshold_1_warning))
      if(modValue_firstThreshold == 0) {
        messageType := "Warning: " . timeCalculator.F_convertSecsToHHMMSS(Threshold_1_warning)
        timeLeft_s := Threshold_2_break - Threshold_1_warning
        timeLeft_timestamp := timeCalculator.F_convertSecsToHHMMSS(timeLeft_s)
        messageText := "1st warning notification.`n" . timeLeft_timestamp . " remaining"
        createLog := true
        TrayTip, %messageType%, %messageText%, 1, 1
        ;MsgBox, passedSecs: %passedSecs% `nmessage text: %messageText%
      } else if (passedSecs == Threshold_2_break) {
        messageType := "Alert: " . timeCalculator.F_convertSecsToHHMMSS(Threshold_2_break) 
        messageText := "Alert notification. Take a break!"
        createLog := true
        TrayTip, %messageType%, %messageText%, 1, 2
        ;MsgBox, passedSecs: %passedSecs% `nmessage text: %messageText%
      }
    }
    if(passedSecs > Threshold_2_break) {
      modValue_postBreakThreshold := Mod(passedSecs, Threshold_3_postBreak)
      if(modValue_postBreakThreshold == 0) {
        createLog := true
        messageText := "Post alert notification. Take a break!"
        messageType := "Alert: " . timeCalculator.F_convertSecsToHHMMSS(passedSecs)
        TrayTip, %messageType%, %messageText%, 1, 3
        ;MsgBox, passedSecs: %passedSecs% `nmessage text: %messageText%
      }
    }
    
    if(createLog) {
      logMessage := messageType . "`t" . messageText
      F_addToLogFile(logfileDirectory, logFileName, timeCalculator.F_generateTimestamp(), logMessage)
    }
  }
}
 
F_logoffLogging() {
  Global
  ; logoff logging logic here
  UserLoggedOn := false
  LoggedOnTime := secondCounter.F_getCount()
  TotalLoggedOnTime := TotalLoggedOnTime + LoggedOnTime
  if(LoggedOnTime > LongestWorkPeriod) {
    LongestWorkPeriod := LoggedOnTime
  }
  TotalNumberOfBreaks := ++TotalNumberOfBreaks
  secondCounter.F_resetCounter()
  F_addToLogFile(logfileDirectory, logFileName, timeCalculator.F_generateTimestamp(), "Screen Locked. Last Work period:`t" . LoggedOnTime " secs -> " . timeCalculator.F_convertSecsToHHMMSS(LoggedOnTime))
}

F_logonLogging() {
  Global
  ; logon logic here
  UserLoggedOn := true
  LoggedOffTime := secondCounter.F_getCount()
  TotalLoggedOffTime := TotalLoggedOffTime + LoggedOffTime
  if(LoggedOffTime > LongestBreakPeriod) {
    LongestBreakPeriod := LoggedOffTime
  }
  secondCounter.F_resetCounter()
  F_addToLogFile(logfileDirectory, logFileName, timeCalculator.F_generateTimestamp(), "Screen Unlocked. Last Break period:`t" . LoggedOffTime . " secs -> " . timeCalculator.F_convertSecsToHHMMSS(LoggedOffTime))
}

F_readSettingsINI() {
  Global
  
  ; If the ini file does exist, read the data within
  IfExist, %directoryPath%\Settings.ini 
  {
    IniRead, Threshold_1_warning, %A_ScriptDir%\Settings.ini, section1, Threshold_1_warning, %Threshold_1_warning%
    IniRead, Threshold_2_break, %A_ScriptDir%\Settings.ini, section1, Threshold_2_break, %Threshold_2_break%
    IniRead, Threshold_3_postBreak, %A_ScriptDir%\Settings.ini, section1, Threshold_3_postBreak, %Threshold_3_postBreak%
  }
  
  ; If the ini file does not exist, create with the default values
  ifNotExist, %directoryPath%\Settings.ini 
  {
    ; Create ini file with default settings for future
    IniWrite, %Threshold_1_warning%, %A_ScriptDir%\Settings.ini, section1, Threshold_1_warning
    IniWrite, %Threshold_2_break%, %A_ScriptDir%\Settings.ini, section1, Threshold_2_break
    IniWrite, %Threshold_3_postBreak%, %A_ScriptDir%\Settings.ini, section1, Threshold_3_postBreak
  }
}

F_writeToSettingsINI() {
  
}


; ***** Labels ***** ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;


L_checkBreakThresholds: 
  passedSecs := secondCounter.F_getCount()
  F_checkBreakThresholds(passedSecs)
Return

L_testLogging:
  ;Global
 
  F_logoffLogging()
  
  Sleep, 5000
  
  F_logonLogging()
  
  Sleep, 5000

  F_scriptCloseDown()
Return

L_buildSessionInfo:
  ; create a variable for the handle of the window to receive session change notifications, passed to DLL call
  hw_ahk := WinExist("ahk_pid " DllCall("GetCurrentProcessId"))
  ; This value will be passed to DLL call, specifies which session notifications will be received (all sessions used to avoid situation where only session notifications about this window are used)
  NOTIFY_FOR_THIS_SESSION = 0
  ; Need to call this DLL so that the session Notifications can be seen by the script
  result := DllCall( "Wtsapi32.dll\WTSRegisterSessionNotification", "uint", hw_ahk, "uint", NOTIFY_FOR_ALL_SESSIONS )
return

L_logoffLog:
  ; Access to global variables
  ;Global
  
  ; Ensure that the # key has been released to prevent "Sticking key" issues with BlockInput
  KeyWait LWin
  KeyWait RWin 
  
  ; Block user input during log off attempts
  BlockInput, on
  
  ; logoff logging logic here
  F_logoffLogging()
 
  ; Give control back to User
  BlockInput, off
  
  ; Lock the screen AFTER all checks have been performed, and it is certain that window is closed
  ;MsgBox, in L_logoffLog, before cycleWorkstationLock
  F_cycleWorkstationLock()
  ;MsgBox, in L_logoffLog, after cycleWorkstationLock
Return

L_openTimerCount:
  currentCountVar := secondCounter.F_getCount()
  messageOutput := "Current count:`n" . currentCountVar . " secs`n" . timeCalculator.F_convertSecsToHHMMSS(currentCountVar)
  MsgBox, %messageOutput% 
Return

L_openLogfileFolder:
  run, %logfileDirectory%
Return

L_openLogfile:
  fullPath := logfileDirectory . "\" . logFileName
  run, %fullPath%
Return

L_logFileReaderGUI:
  ; Prepping data
  v_TLogFileContents := ""
  
  fullPath := logfileDirectory . "\" . logFileName
  try {
    FileRead, v_TLogFileContents, %fullPath%
  } catch e{
    MsgBox, An exception was thrown!`nSpecifically: %e%
  }
  
  temp_LongestBreakPeriod := timeCalculator.F_convertSecsToHHMMSS(LongestBreakPeriod)
  temp_LongestWorkPeriod := timeCalculator.F_convertSecsToHHMMSS(LongestWorkPeriod)
  
  Gui, TlogGui:New, +Resize, Todays TLog
  Gui, Add, Tab3,,Data Reader|Settings   ; Add tabs
  
  ; Add to tab 1 "Data Reader"
  Gui, Tab, 1   
  
  Gui, Add, Edit, Multi h500 w600 ReadOnly -Wrap VScroll vMyEdit
  GuiControl,, MyEdit, %v_TLogFileContents%
  Gui, Add, Text,,Number of breaks: %TotalNumberOfBreaks%
  Gui, Add, Text,,Longest break: %temp_LongestBreakPeriod%
  Gui, Add, Text,,Longest session: %temp_LongestWorkPeriod%
  
  ; Add to tab 2 "Settings"
  Gui, Tab, 2
  
  Gui, Add, Text, section,Threshold for first warning (seconds):
  Gui, Add, Text,,Threshold for break alert (seconds):
  Gui, Add, Text,,Threshold for post-break alerts (seconds):
  
  Gui, Add, Edit, vThreshold_1_warning ys w50, %Threshold_1_warning%
  Gui, Add, Edit, vThreshold_2_break w50, %Threshold_2_break%
  Gui, Add, Edit, vThreshold_3_postBreak w50, %Threshold_3_postBreak%
  
  Gui, Show
Return

; Whenever the script is exited, this will always run because of the 'OnExit' entry in the executable part of the script
L_exitSub:

  F_scriptCloseDown()
  
  ; Try and delete the RegEdit entry for the 'Disable lock workstation', so that the device can be locked as normal again
  
  ; Do not actually need try/catch block
  ; If reg entry exists, it will be deleted, if not, nothing happens
    RegDelete, HKEY_CURRENT_USER, SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System, DisableLockWorkstation

  ExitApp
return

L_reloadScript:
  Reload
  Sleep 1000 ; If successful, the reload will close this instance during the Sleep, so the line below will never be reached.
  MsgBox, The script could not be reloaded.`nPlease exit the script and re-execute it manually.
return
