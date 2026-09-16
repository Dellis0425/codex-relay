#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; CODEX CONTINUATION SCHEDULER
;
; Ctrl + Alt + K = Open scheduler
;
; Defaults:
;   Reset time    = 5 hours from now
;   Safety buffer = 10 minutes
;
; Example:
;   Current time: 11:48 PM
;   Default reset: 4:48 AM
;   Buffer:        10 minutes
;   Actual run:    4:58 AM
; ============================================================


; ============================================================
; GLOBAL VARIABLES
; ============================================================

global SchedulerGui := 0

global HourDropdown := 0
global MinuteDropdown := 0
global AmPmDropdown := 0
global BufferDropdown := 0
global SendCheckbox := 0

global PreviewText := 0
global StatusText := 0

global IsArmed := false
global ShouldSend := false

global TargetTime := ""
global ScheduledCallback := 0


; ============================================================
; HOTKEY
;
; Ctrl + Alt + K
; ============================================================

^!k::ShowScheduler()


; ============================================================
; SHOW SCHEDULER
; ============================================================

ShowScheduler()
{
    global SchedulerGui
    global IsArmed

    if !SchedulerGui
        BuildSchedulerGui()

    ; If there isn't currently an armed timer,
    ; create a fresh default based on 5 hours from now.
    ;
    ; If a timer IS already armed, don't overwrite the user's
    ; controls just because they reopened the GUI.
    if !IsArmed
    {
        UpdateDefaultTime()
    }

    UpdatePreview()

    SchedulerGui.Show("AutoSize Center")
}


; ============================================================
; BUILD GUI
; ============================================================

BuildSchedulerGui()
{
    global SchedulerGui

    global HourDropdown
    global MinuteDropdown
    global AmPmDropdown
    global BufferDropdown

    global SendCheckbox

    global PreviewText
    global StatusText


    SchedulerGui := Gui(
        "+AlwaysOnTop",
        "Codex Continuation Scheduler"
    )

    SchedulerGui.SetFont("s10")


    SchedulerGui.AddText(
        "w410",
        "Schedule Codex to continue after your usage resets."
    )


    ; ========================================================
    ; BUILD DROPDOWN LISTS
    ; ========================================================

    hours := []

    Loop 12
    {
        hours.Push(
            String(A_Index)
        )
    }


    minutes := []

    Loop 60
    {
        minutes.Push(
            Format(
                "{:02}",
                A_Index - 1
            )
        )
    }


    buffers := [
        "0",
        "5",
        "10",
        "15",
        "20",
        "30"
    ]


    ; ========================================================
    ; RESET TIME
    ; ========================================================

    SchedulerGui.AddText(
        "xm y+20",
        "Reset time:"
    )


    HourDropdown := SchedulerGui.AddDropDownList(
        "x+12 yp-3 w60",
        hours
    )


    SchedulerGui.AddText(
        "x+5 yp+4",
        ":"
    )


    MinuteDropdown := SchedulerGui.AddDropDownList(
        "x+5 yp-4 w65",
        minutes
    )


    AmPmDropdown := SchedulerGui.AddDropDownList(
        "x+10 yp w70",
        ["AM", "PM"]
    )


    ; ========================================================
    ; SAFETY BUFFER
    ; ========================================================

    SchedulerGui.AddText(
        "xm y+20",
        "Safety buffer:"
    )


    BufferDropdown := SchedulerGui.AddDropDownList(
        "x+10 yp-3 w70",
        buffers
    )


    SchedulerGui.AddText(
        "x+7 yp+4",
        "minutes"
    )


    ; ========================================================
    ; SEND OPTION
    ; ========================================================

    SendCheckbox := SchedulerGui.AddCheckbox(
        "xm y+22",
        "Press Enter and actually send the prompt"
    )


    ; ========================================================
    ; NEW SCHEDULE PREVIEW
    ; ========================================================

    PreviewText := SchedulerGui.AddText(
        "xm y+22 w410 h48",
        "New schedule preview:`nCalculating..."
    )


    ; ========================================================
    ; CURRENT STATUS
    ; ========================================================

    StatusText := SchedulerGui.AddText(
        "xm y+8 w410 h38",
        "Status: NOT ARMED"
    )


    ; ========================================================
    ; BUTTONS
    ; ========================================================

    armButton := SchedulerGui.AddButton(
        "xm y+22 w120 h34 Default",
        "Arm Timer"
    )


    cancelButton := SchedulerGui.AddButton(
        "x+10 w100 h34",
        "Cancel"
    )


    closeButton := SchedulerGui.AddButton(
        "x+10 w90 h34",
        "Close"
    )


    armButton.OnEvent(
        "Click",
        ArmTimer
    )


    cancelButton.OnEvent(
        "Click",
        CancelTimer
    )


    closeButton.OnEvent(
        "Click",
        HideScheduler
    )


    SchedulerGui.OnEvent(
        "Close",
        HideScheduler
    )


    ; ========================================================
    ; LIVE PREVIEW EVENTS
    ; ========================================================

    HourDropdown.OnEvent(
        "Change",
        UpdatePreview
    )


    MinuteDropdown.OnEvent(
        "Change",
        UpdatePreview
    )


    AmPmDropdown.OnEvent(
        "Change",
        UpdatePreview
    )


    BufferDropdown.OnEvent(
        "Change",
        UpdatePreview
    )
}


; ============================================================
; DEFAULT RESET TIME = 5 HOURS FROM NOW
; ============================================================

UpdateDefaultTime()
{
    global HourDropdown
    global MinuteDropdown
    global AmPmDropdown
    global BufferDropdown


    defaultTime := DateAdd(
        A_Now,
        5,
        "Hours"
    )


    hour12 := Number(
        FormatTime(
            defaultTime,
            "h"
        )
    )


    minute := Number(
        FormatTime(
            defaultTime,
            "mm"
        )
    )


    ampm := FormatTime(
        defaultTime,
        "tt"
    )


    ; --------------------------------------------------------
    ; HOUR
    ;
    ; Dropdown index:
    ; 1 = 1
    ; 2 = 2
    ; ...
    ; 12 = 12
    ; --------------------------------------------------------

    HourDropdown.Choose(
        hour12
    )


    ; --------------------------------------------------------
    ; MINUTE
    ;
    ; Dropdown index:
    ; 1 = 00
    ; 2 = 01
    ; ...
    ; 60 = 59
    ; --------------------------------------------------------

    MinuteDropdown.Choose(
        minute + 1
    )


    ; --------------------------------------------------------
    ; AM / PM
    ; --------------------------------------------------------

    if ampm = "AM"
    {
        AmPmDropdown.Choose(1)
    }
    else
    {
        AmPmDropdown.Choose(2)
    }


    ; --------------------------------------------------------
    ; DEFAULT BUFFER = 10 MINUTES
    ;
    ; Buffer list:
    ; 0, 5, 10, 15, 20, 30
    ;
    ; Index 3 = 10
    ; --------------------------------------------------------

    BufferDropdown.Choose(3)
}


; ============================================================
; CALCULATE TARGET TIME FROM GUI
; ============================================================

GetTargetTimeFromGui()
{
    global HourDropdown
    global MinuteDropdown
    global AmPmDropdown
    global BufferDropdown


    hour := Number(
        HourDropdown.Text
    )


    minute := Number(
        MinuteDropdown.Text
    )


    ampm := AmPmDropdown.Text


    bufferMinutes := Number(
        BufferDropdown.Text
    )


    ; ========================================================
    ; CONVERT 12-HOUR TIME TO 24-HOUR TIME
    ; ========================================================

    hour24 := hour


    if ampm = "AM"
    {
        if hour = 12
        {
            hour24 := 0
        }
    }
    else
    {
        if hour != 12
        {
            hour24 := hour + 12
        }
    }


    ; ========================================================
    ; BUILD TIMESTAMP FOR TODAY
    ; ========================================================

    today := FormatTime(
        A_Now,
        "yyyyMMdd"
    )


    resetTimestamp :=
        today
        . Format(
            "{:02}",
            hour24
        )
        . Format(
            "{:02}",
            minute
        )
        . "00"


    ; ========================================================
    ; IF THAT RESET CLOCK TIME ALREADY PASSED TODAY,
    ; ASSUME THE USER MEANS TOMORROW
    ; ========================================================

    if DateDiff(
        resetTimestamp,
        A_Now,
        "Seconds"
    ) <= 0
    {
        resetTimestamp := DateAdd(
            resetTimestamp,
            1,
            "Days"
        )
    }


    ; ========================================================
    ; ADD SAFETY BUFFER
    ; ========================================================

    targetTime := DateAdd(
        resetTimestamp,
        bufferMinutes,
        "Minutes"
    )


    return targetTime
}


; ============================================================
; UPDATE NEW-SCHEDULE PREVIEW
; ============================================================

UpdatePreview(*)
{
    global PreviewText


    target := GetTargetTimeFromGui()


    PreviewText.Text :=
        "New schedule preview:`n"
        . FormatTime(
            target,
            "dddd, MMMM d, yyyy"
        )
        . " at "
        . FormatTime(
            target,
            "h:mm tt"
        )
}


; ============================================================
; ARM TIMER
; ============================================================

ArmTimer(*)
{
    global SendCheckbox
    global StatusText
    global SchedulerGui

    global IsArmed
    global ShouldSend

    global TargetTime
    global ScheduledCallback


    ; --------------------------------------------------------
    ; CALCULATE TARGET
    ; --------------------------------------------------------

    TargetTime := GetTargetTimeFromGui()


    secondsUntil := DateDiff(
        TargetTime,
        A_Now,
        "Seconds"
    )


    if secondsUntil <= 0
    {
        MsgBox(
            "The calculated time is not in the future."
        )

        return
    }


    delayMs := secondsUntil * 1000


    ; --------------------------------------------------------
    ; REMEMBER WHETHER ENTER SHOULD BE PRESSED
    ; --------------------------------------------------------

    ShouldSend :=
        SendCheckbox.Value = 1


    IsArmed := true


    ; --------------------------------------------------------
    ; CANCEL ANY EXISTING SCHEDULE FIRST
    ; --------------------------------------------------------

    if ScheduledCallback
    {
        SetTimer(
            ScheduledCallback,
            0
        )
    }


    ScheduledCallback :=
        RunScheduledContinue


    ; --------------------------------------------------------
    ; NEGATIVE INTERVAL = RUN ONCE
    ; --------------------------------------------------------

    SetTimer(
        ScheduledCallback,
        -delayMs
    )


    ; --------------------------------------------------------
    ; DISPLAY ARMED STATUS
    ; --------------------------------------------------------

    displayTime := FormatTime(
        TargetTime,
        "ddd MMM d, yyyy, h:mm:ss tt"
    )


    StatusText.Text :=
        "Status: ARMED for " . displayTime


    ; ========================================================
    ; HIDE GUI AFTER ARMING
    ; ========================================================

    SchedulerGui.Hide()


    ; ========================================================
    ; TRAY ICON HOVER TEXT
    ; ========================================================

    A_IconTip :=
        "Codex continuation ARMED for "
        . FormatTime(
            TargetTime,
            "ddd MMM d, h:mm tt"
        )


    ; ========================================================
    ; WINDOWS NOTIFICATION
    ; ========================================================

    TrayTip(
        "Codex Scheduler",
        "Armed for "
        . FormatTime(
            TargetTime,
            "ddd MMM d, yyyy"
        )
        . " at "
        . FormatTime(
            TargetTime,
            "h:mm tt"
        ),
        1
    )
}


; ============================================================
; SCHEDULE FIRES
; ============================================================

RunScheduledContinue()
{
    global IsArmed
    global ShouldSend

    global StatusText
    global TargetTime


    ; The timer has now fired.
    ;
    ; It is no longer armed regardless of whether the
    ; automation itself succeeds or fails.
    IsArmed := false


    success := ContinueCodex(
        ShouldSend
    )


    ; ========================================================
    ; SUCCESS
    ; ========================================================

    if success
    {
        ; ----------------------------------------------------
        ; PROMPT WAS ACTUALLY SENT
        ; ----------------------------------------------------

        if ShouldSend
        {
            sentTime := FormatTime(
                A_Now,
                "h:mm:ss tt"
            )


            StatusText.Text :=
                "Status: NOT ARMED — last prompt sent at "
                . sentTime


            A_IconTip :=
                "Codex Scheduler — not armed"


            TrayTip(
                "Codex Scheduler",
                "Continue prompt SENT at "
                . sentTime,
                1
            )
        }


        ; ----------------------------------------------------
        ; PROMPT WAS TYPED BUT ENTER WAS NOT PRESSED
        ; ----------------------------------------------------

        else
        {
            typedTime := FormatTime(
                A_Now,
                "h:mm:ss tt"
            )


            StatusText.Text :=
                "Status: NOT ARMED — last prompt typed at "
                . typedTime


            A_IconTip :=
                "Codex Scheduler — not armed"


            TrayTip(
                "Codex Scheduler",
                "Prompt typed but NOT sent at "
                . typedTime,
                1
            )
        }
    }


    ; ========================================================
    ; FAILURE
    ; ========================================================

    else
    {
        failedTime := FormatTime(
            A_Now,
            "h:mm:ss tt"
        )


        StatusText.Text :=
            "Status: NOT ARMED — last attempt failed at "
            . failedTime


        A_IconTip :=
            "Codex Scheduler — not armed"


        TrayTip(
            "Codex Scheduler",
            "Could not control the ChatGPT app.",
            2
        )
    }
}


; ============================================================
; CONTROL CHATGPT / CODEX
; ============================================================

ContinueCodex(sendIt := false)
{
    ; ========================================================
    ; CHATGPT MUST ALREADY BE OPEN
    ; ========================================================

    codex := WinExist(
        "ahk_exe ChatGPT.exe"
    )


    if !codex
    {
        return false
    }


    ; ========================================================
    ; BRING CHATGPT TO THE FRONT
    ; ========================================================

    WinActivate(
        "ahk_id " codex
    )


    if !WinWaitActive(
        "ahk_id " codex,
        ,
        8
    )
    {
        return false
    }


    ; Give Chromium / Codex time to become interactive.
    Sleep 1500


    ; ========================================================
    ; CONFIRM CHATGPT STILL OWNS FOCUS
    ; ========================================================

    if !WinActive(
        "ahk_id " codex
    )
    {
        return false
    }


    ; ========================================================
    ; GET CHATGPT CLIENT AREA
    ; ========================================================

    WinGetClientPos(
        &clientX,
        &clientY,
        &clientW,
        &clientH,
        "ahk_id " codex
    )


    ; ========================================================
    ; CODEX PROMPT POSITION
    ;
    ; This is based on the layout already tested successfully
    ; on this machine.
    ; ========================================================

    clickX := 390
    clickY := clientH - 80


    CoordMode(
        "Mouse",
        "Client"
    )


    Click(
        clickX,
        clickY
    )


    ; Give the prompt box time to receive keyboard focus.
    Sleep 1000


    ; ========================================================
    ; SAFETY CHECK BEFORE TYPING
    ; ========================================================

    if !WinActive(
        "ahk_id " codex
    )
    {
        return false
    }


    ; ========================================================
    ; TYPE CONTINUATION PROMPT
    ; ========================================================

    SendText(
        "Continue where you left off"
    )


    ; ========================================================
    ; OPTIONAL ENTER
    ; ========================================================

    if sendIt
    {
        Sleep 800


        ; ----------------------------------------------------
        ; FINAL SAFETY CHECK BEFORE ENTER
        ; ----------------------------------------------------

        if !WinActive(
            "ahk_id " codex
        )
        {
            return false
        }


        Send "{Enter}"
    }


    return true
}


; ============================================================
; CANCEL SCHEDULE
; ============================================================

CancelTimer(*)
{
    global IsArmed
    global ScheduledCallback
    global StatusText


    ; --------------------------------------------------------
    ; STOP SCHEDULED CALLBACK
    ; --------------------------------------------------------

    if ScheduledCallback
    {
        SetTimer(
            ScheduledCallback,
            0
        )
    }


    IsArmed := false


    ; --------------------------------------------------------
    ; UPDATE GUI STATE
    ; --------------------------------------------------------

    if StatusText
    {
        StatusText.Text :=
            "Status: NOT ARMED — schedule cancelled"
    }


    ; --------------------------------------------------------
    ; RESET TRAY HOVER TEXT
    ; --------------------------------------------------------

    A_IconTip :=
        "Codex Scheduler — not armed"


    ; --------------------------------------------------------
    ; WINDOWS NOTIFICATION
    ; --------------------------------------------------------

    TrayTip(
        "Codex Scheduler",
        "Scheduled continuation cancelled.",
        1
    )
}


; ============================================================
; HIDE GUI
;
; IMPORTANT:
; Closing the GUI does NOT cancel an armed timer.
; Use Cancel or Exit the script to cancel it.
; ============================================================

HideScheduler(*)
{
    global SchedulerGui


    if SchedulerGui
    {
        SchedulerGui.Hide()
    }
}