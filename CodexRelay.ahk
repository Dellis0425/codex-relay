#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; CODEX RELAY
;
; Ctrl + Alt + K = Open scheduler
;
; Codex Relay schedules ONE prompt at a time for the
; ChatGPT desktop application's Codex interface.
;
; Features:
;   - Built-in "Continue where you left off" prompt
;   - Custom prompts
;   - Prompt saved to Markdown before scheduling
;   - Persistent scheduled state
;   - Schedule survives script restart
;   - Supports scheduling several days ahead
;   - Missed schedules NEVER auto-send late
; ============================================================


; ============================================================
; CONSTANTS / STORAGE
; ============================================================

global DEFAULT_PROMPT :=
    "Continue where you left off"

global PROMPT_FOLDER_NAME :=
    "Scheduled Prompts"

global STATE_FILE_NAME :=
    "schedule.ini"

global PromptDir :=
    A_ScriptDir "\" PROMPT_FOLDER_NAME

global StateFile :=
    A_ScriptDir "\" STATE_FILE_NAME


; ============================================================
; GUI GLOBALS
; ============================================================

global SchedulerGui := 0

global PromptTypeDropdown := 0
global PromptEdit := 0

global DaysDropdown := 0
global HourDropdown := 0
global MinuteDropdown := 0
global AmPmDropdown := 0
global BufferDropdown := 0

global SendCheckbox := 0

global PreviewText := 0
global StatusText := 0


; ============================================================
; SCHEDULE GLOBALS
; ============================================================

global IsArmed := false
global ShouldSend := false

global TargetTime := ""
global CurrentPromptFile := ""

global ScheduledCallback := 0

global StatusMessage :=
    "Status: NOT ARMED"


; ============================================================
; STARTUP
; ============================================================

DirCreate(PromptDir)

RestoreSavedSchedule()


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

    global StatusText
    global StatusMessage

    global PreviewText
    global TargetTime


    ; A newly-created GUI has blank dropdowns until we
    ; initialize them at least once.
    if !SchedulerGui
    {
        BuildSchedulerGui()

        ; Always initialize the controls so HourDropdown.Text,
        ; MinuteDropdown.Text, etc. are never empty.
        UpdateDefaultTime()
    }


    ; ========================================================
    ; NO ACTIVE SCHEDULE
    ; ========================================================

    if !IsArmed
    {
        UpdateDefaultTime()
        UpdatePreview()
    }


    ; ========================================================
    ; ACTIVE / RESTORED SCHEDULE
    ;
    ; Do NOT calculate the preview from the fresh dropdowns.
    ; Show the schedule that is actually armed.
    ; ========================================================

    else
    {
        PreviewText.Text :=
            "Currently armed schedule:`n"
            . FormatTime(
                TargetTime,
                "dddd, MMMM d, yyyy"
            )
            . " at "
            . FormatTime(
                TargetTime,
                "h:mm tt"
            )
    }


    StatusText.Text :=
        StatusMessage


    SchedulerGui.Show(
        "AutoSize Center"
    )
}


; ============================================================
; BUILD GUI
; ============================================================

BuildSchedulerGui()
{
    global SchedulerGui

    global PromptTypeDropdown
    global PromptEdit

    global DaysDropdown
    global HourDropdown
    global MinuteDropdown
    global AmPmDropdown
    global BufferDropdown

    global SendCheckbox

    global PreviewText
    global StatusText
    global StatusMessage

    global DEFAULT_PROMPT


    SchedulerGui := Gui(
        "+AlwaysOnTop",
        "Codex Relay"
    )


    SchedulerGui.SetFont(
        "s10"
    )


    SchedulerGui.AddText(
        "w500",
        "Schedule a prompt for your current Codex session."
    )


    ; ========================================================
    ; PROMPT TYPE
    ; ========================================================

    SchedulerGui.AddText(
        "xm y+20",
        "Prompt:"
    )


    PromptTypeDropdown :=
        SchedulerGui.AddDropDownList(
            "xm y+6 w250 Choose1",
            [
                "Continue where you left off",
                "Custom Prompt"
            ]
        )


    ; ========================================================
    ; PROMPT EDITOR
    ; ========================================================

    SchedulerGui.AddText(
        "xm y+15",
        "Prompt text:"
    )


    PromptEdit :=
        SchedulerGui.AddEdit(
            "xm y+6 w500 r7 WantTab",
            DEFAULT_PROMPT
        )


    ; ========================================================
    ; DAYS AHEAD OPTIONS
    ; ========================================================

    days := [
        "Today",
        "Tomorrow",
        "2 days from now",
        "3 days from now",
        "4 days from now",
        "5 days from now",
        "6 days from now",
        "7 days from now"
    ]


    ; ========================================================
    ; HOURS
    ; ========================================================

    hours := []

    Loop 12
    {
        hours.Push(
            String(A_Index)
        )
    }


    ; ========================================================
    ; MINUTES
    ; ========================================================

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


    ; ========================================================
    ; SAFETY BUFFERS
    ; ========================================================

    buffers := [
        "0",
        "5",
        "10",
        "15",
        "20",
        "30"
    ]


    ; ========================================================
    ; DAYS AHEAD
    ; ========================================================

    SchedulerGui.AddText(
        "xm y+20",
        "Day:"
    )


    DaysDropdown :=
        SchedulerGui.AddDropDownList(
            "x+10 yp-3 w155",
            days
        )


    ; ========================================================
    ; RESET TIME
    ; ========================================================

    SchedulerGui.AddText(
        "xm y+18",
        "Reset time:"
    )


    HourDropdown :=
        SchedulerGui.AddDropDownList(
            "x+12 yp-3 w60",
            hours
        )


    SchedulerGui.AddText(
        "x+5 yp+4",
        ":"
    )


    MinuteDropdown :=
        SchedulerGui.AddDropDownList(
            "x+5 yp-4 w65",
            minutes
        )


    AmPmDropdown :=
        SchedulerGui.AddDropDownList(
            "x+10 yp w70",
            [
                "AM",
                "PM"
            ]
        )


    ; ========================================================
    ; SAFETY BUFFER
    ; ========================================================

    SchedulerGui.AddText(
        "xm y+18",
        "Safety buffer:"
    )


    BufferDropdown :=
        SchedulerGui.AddDropDownList(
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

    SendCheckbox :=
        SchedulerGui.AddCheckbox(
            "xm y+20",
            "Press Enter and actually send the prompt"
        )


    ; ========================================================
    ; PREVIEW
    ; ========================================================

    PreviewText :=
        SchedulerGui.AddText(
            "xm y+20 w500 h48",
            "New schedule preview:`nCalculating..."
        )


    ; ========================================================
    ; CURRENT STATUS
    ; ========================================================

    StatusText :=
        SchedulerGui.AddText(
            "xm y+8 w500 h42",
            StatusMessage
        )


    ; ========================================================
    ; BUTTONS
    ; ========================================================

    armButton :=
        SchedulerGui.AddButton(
            "xm y+20 w120 h34 Default",
            "Arm Timer"
        )


    cancelButton :=
        SchedulerGui.AddButton(
            "x+10 w100 h34",
            "Cancel"
        )


    closeButton :=
        SchedulerGui.AddButton(
            "x+10 w90 h34",
            "Close"
        )


    ; ========================================================
    ; EVENTS
    ; ========================================================

    PromptTypeDropdown.OnEvent(
        "Change",
        PromptTypeChanged
    )


    DaysDropdown.OnEvent(
        "Change",
        UpdatePreview
    )


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
}


; ============================================================
; PROMPT TYPE CHANGED
; ============================================================

PromptTypeChanged(*)
{
    global PromptTypeDropdown
    global PromptEdit
    global DEFAULT_PROMPT


    if PromptTypeDropdown.Text =
        "Continue where you left off"
    {
        PromptEdit.Value :=
            DEFAULT_PROMPT
    }
    else
    {
        ; If switching from the built-in prompt to Custom,
        ; clear the built-in text automatically.
        if Trim(PromptEdit.Value) =
            DEFAULT_PROMPT
        {
            PromptEdit.Value := ""
        }


        PromptEdit.Focus()
    }
}


; ============================================================
; DEFAULT SCHEDULE = FIVE HOURS FROM NOW
; ============================================================

UpdateDefaultTime()
{
    global DaysDropdown

    global HourDropdown
    global MinuteDropdown
    global AmPmDropdown
    global BufferDropdown


    defaultTime :=
        DateAdd(
            A_Now,
            5,
            "Hours"
        )


    ; --------------------------------------------------------
    ; FIGURE OUT WHETHER +5 HOURS IS TODAY OR TOMORROW
    ; --------------------------------------------------------

    todayDate :=
        FormatTime(
            A_Now,
            "yyyyMMdd"
        )


    defaultDate :=
        FormatTime(
            defaultTime,
            "yyyyMMdd"
        )


    if defaultDate = todayDate
        DaysDropdown.Choose(1)
    else
        DaysDropdown.Choose(2)


    ; --------------------------------------------------------
    ; HOUR
    ; --------------------------------------------------------

    hour12 :=
        Number(
            FormatTime(
                defaultTime,
                "h"
            )
        )


    HourDropdown.Choose(
        hour12
    )


    ; --------------------------------------------------------
    ; MINUTE
    ; --------------------------------------------------------

    minute :=
        Number(
            FormatTime(
                defaultTime,
                "mm"
            )
        )


    MinuteDropdown.Choose(
        minute + 1
    )


    ; --------------------------------------------------------
    ; AM / PM
    ; --------------------------------------------------------

    ampm :=
        FormatTime(
            defaultTime,
            "tt"
        )


    if ampm = "AM"
        AmPmDropdown.Choose(1)
    else
        AmPmDropdown.Choose(2)


    ; --------------------------------------------------------
    ; DEFAULT SAFETY BUFFER = 10 MINUTES
    ; --------------------------------------------------------

    BufferDropdown.Choose(3)
}


; ============================================================
; GET DAYS AHEAD
; ============================================================

GetDaysAhead()
{
    global DaysDropdown

    ; Dropdown index 1 = today = 0 days.
    ; Dropdown index 2 = tomorrow = 1 day.
    ; etc.

    return DaysDropdown.Value - 1
}


; ============================================================
; CALCULATE TARGET TIME
; ============================================================

GetTargetTimeFromGui()
{
    global HourDropdown
    global MinuteDropdown
    global AmPmDropdown
    global BufferDropdown


    daysAhead :=
        GetDaysAhead()


    hour :=
        Number(
            HourDropdown.Text
        )


    minute :=
        Number(
            MinuteDropdown.Text
        )


    ampm :=
        AmPmDropdown.Text


    bufferMinutes :=
        Number(
            BufferDropdown.Text
        )


    ; ========================================================
    ; CONVERT 12-HOUR CLOCK TO 24-HOUR
    ; ========================================================

    hour24 := hour


    if ampm = "AM"
    {
        if hour = 12
            hour24 := 0
    }
    else
    {
        if hour != 12
            hour24 := hour + 12
    }


    ; ========================================================
    ; BUILD SELECTED DATE
    ; ========================================================

    todayMidnight :=
        FormatTime(
            A_Now,
            "yyyyMMdd"
        )
        . "000000"


    selectedDay :=
        DateAdd(
            todayMidnight,
            daysAhead,
            "Days"
        )


    selectedDate :=
        FormatTime(
            selectedDay,
            "yyyyMMdd"
        )


    resetTimestamp :=
        selectedDate
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
    ; ADD SAFETY BUFFER
    ; ========================================================

    targetTime :=
        DateAdd(
            resetTimestamp,
            bufferMinutes,
            "Minutes"
        )


    return targetTime
}


; ============================================================
; UPDATE SCHEDULE PREVIEW
; ============================================================

UpdatePreview(*)
{
    global PreviewText


    target :=
        GetTargetTimeFromGui()


    secondsUntil :=
        DateDiff(
            target,
            A_Now,
            "Seconds"
        )


    if secondsUntil <= 0
    {
        PreviewText.Text :=
            "New schedule preview:`n"
            . "Selected time is not in the future."

        return
    }


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
    global PromptEdit
    global SendCheckbox

    global SchedulerGui
    global StatusText
    global StatusMessage

    global IsArmed
    global ShouldSend

    global TargetTime
    global CurrentPromptFile
    global ScheduledCallback


    ; ========================================================
    ; VALIDATE PROMPT
    ; ========================================================

    promptText :=
        Trim(
            PromptEdit.Value
        )


    if promptText = ""
    {
        MsgBox(
            "The prompt cannot be empty."
        )

        return
    }


    ; ========================================================
    ; CALCULATE TARGET TIME
    ; ========================================================

    TargetTime :=
        GetTargetTimeFromGui()


    secondsUntil :=
        DateDiff(
            TargetTime,
            A_Now,
            "Seconds"
        )


    if secondsUntil <= 0
    {
        MsgBox(
            "The scheduled time must be in the future."
        )

        return
    }


    ShouldSend :=
        SendCheckbox.Value = 1


    createdTime :=
        A_Now


    ; ========================================================
    ; SAVE PROMPT TO MARKDOWN
    ; ========================================================

    CurrentPromptFile :=
        SavePromptToMarkdown(
            promptText,
            createdTime,
            TargetTime
        )


    if CurrentPromptFile = ""
    {
        MsgBox(
            "Codex Relay could not save the prompt file."
        )

        return
    }


    ; ========================================================
    ; STOP ANY OLD TIMER
    ; ========================================================

    if ScheduledCallback
    {
        SetTimer(
            ScheduledCallback,
            0
        )
    }


    ; ========================================================
    ; CREATE NEW TIMER
    ; ========================================================

    ScheduledCallback :=
        RunScheduledPrompt


    SetTimer(
        ScheduledCallback,
        -(secondsUntil * 1000)
    )


    IsArmed := true


    ; ========================================================
    ; SAVE PERSISTENT STATE
    ; ========================================================

    SaveScheduleState(
        createdTime
    )


    ; ========================================================
    ; DISPLAY STATUS
    ; ========================================================

    StatusMessage :=
        "Status: ARMED for "
        . FormatTime(
            TargetTime,
            "ddd MMM d, yyyy, h:mm:ss tt"
        )


    StatusText.Text :=
        StatusMessage


    A_IconTip :=
        "Codex Relay ARMED for "
        . FormatTime(
            TargetTime,
            "ddd MMM d, h:mm tt"
        )


    SchedulerGui.Hide()


    TrayTip(
        "Codex Relay",
        "Prompt saved and armed for "
        . FormatTime(
            TargetTime,
            "ddd MMM d"
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
; SAVE PROMPT TO MARKDOWN
; ============================================================

SavePromptToMarkdown(
    promptText,
    createdTime,
    scheduledTime
)
{
    global PromptDir


    ; Create Scheduled Prompts only when actually needed.
    DirCreate(
        PromptDir
    )


    filename :=
        "created_"
        . FormatTime(
            createdTime,
            "yyyy-MM-dd_HH-mm-ss"
        )
        . "__scheduled_"
        . FormatTime(
            scheduledTime,
            "yyyy-MM-dd_HH-mm-ss"
        )
        . ".md"


    filePath :=
        PromptDir
        . "\"
        . filename


    ; Extremely unlikely, but protect against overwrite if
    ; two prompts happen to be created during the same second.
    counter := 2


    while FileExist(
        filePath
    )
    {
        filename :=
            "created_"
            . FormatTime(
                createdTime,
                "yyyy-MM-dd_HH-mm-ss"
            )
            . "__scheduled_"
            . FormatTime(
                scheduledTime,
                "yyyy-MM-dd_HH-mm-ss"
            )
            . "_"
            . counter
            . ".md"


        filePath :=
            PromptDir
            . "\"
            . filename


        counter += 1
    }


    try
    {
        FileAppend(
            promptText,
            filePath,
            "UTF-8"
        )
    }
    catch
    {
        return ""
    }


    return filePath
}


; ============================================================
; SAVE PERSISTENT SCHEDULE
; ============================================================

SaveScheduleState(createdTime)
{
    global StateFile

    global TargetTime
    global CurrentPromptFile
    global ShouldSend


    ; Store only the prompt filename instead of its entire
    ; absolute path. This makes the project portable if the
    ; codex-relay folder is moved later.

    SplitPath(
        CurrentPromptFile,
        &promptFilename
    )


    IniWrite(
        "1",
        StateFile,
        "Schedule",
        "Armed"
    )


    IniWrite(
        TargetTime,
        StateFile,
        "Schedule",
        "TargetTime"
    )


    IniWrite(
        promptFilename,
        StateFile,
        "Schedule",
        "PromptFile"
    )


    IniWrite(
        ShouldSend ? "1" : "0",
        StateFile,
        "Schedule",
        "PressEnter"
    )


    IniWrite(
        createdTime,
        StateFile,
        "Schedule",
        "CreatedAt"
    )
}


; ============================================================
; RESTORE PERSISTED SCHEDULE ON SCRIPT START
; ============================================================

RestoreSavedSchedule()
{
    global StateFile
    global PromptDir

    global IsArmed
    global ShouldSend

    global TargetTime
    global CurrentPromptFile

    global ScheduledCallback
    global StatusMessage


    A_IconTip :=
        "Codex Relay — not armed"


    if !FileExist(
        StateFile
    )
    {
        return
    }


    armed :=
        IniRead(
            StateFile,
            "Schedule",
            "Armed",
            "0"
        )


    if armed != "1"
    {
        return
    }


    savedTarget :=
        IniRead(
            StateFile,
            "Schedule",
            "TargetTime",
            ""
        )


    savedPromptFilename :=
        IniRead(
            StateFile,
            "Schedule",
            "PromptFile",
            ""
        )


    savedPressEnter :=
        IniRead(
            StateFile,
            "Schedule",
            "PressEnter",
            "0"
        )


    ; --------------------------------------------------------
    ; VALIDATE SAVED STATE
    ; --------------------------------------------------------

    if savedTarget = "" ||
        savedPromptFilename = ""
    {
        MarkScheduleInactive()


        StatusMessage :=
            "Status: NOT ARMED — saved schedule was invalid"


        return
    }


    CurrentPromptFile :=
        PromptDir
        . "\"
        . savedPromptFilename


    TargetTime :=
        savedTarget


    ShouldSend :=
        savedPressEnter = "1"


    secondsUntil :=
        DateDiff(
            TargetTime,
            A_Now,
            "Seconds"
        )


    ; ========================================================
    ; MISSED SCHEDULE
    ;
    ; SAFETY RULE:
    ; NEVER automatically send a prompt late after reboot.
    ; ========================================================

    if secondsUntil <= 0
    {
        MarkScheduleInactive()


        IsArmed := false


        StatusMessage :=
            "Status: NOT ARMED — missed schedule for "
            . FormatTime(
                TargetTime,
                "ddd MMM d, h:mm tt"
            )


        A_IconTip :=
            "Codex Relay — scheduled prompt was missed"


        TrayTip(
            "Codex Relay",
            "A scheduled prompt was missed while Codex Relay was not running.",
            2
        )


        return
    }


    ; ========================================================
    ; PROMPT FILE MUST STILL EXIST
    ; ========================================================

    if !FileExist(
        CurrentPromptFile
    )
    {
        MarkScheduleInactive()


        IsArmed := false


        StatusMessage :=
            "Status: NOT ARMED — saved prompt file is missing"


        A_IconTip :=
            "Codex Relay — prompt file missing"


        return
    }


    ; ========================================================
    ; RESTORE TIMER
    ; ========================================================

    ScheduledCallback :=
        RunScheduledPrompt


    SetTimer(
        ScheduledCallback,
        -(secondsUntil * 1000)
    )


    IsArmed := true


    StatusMessage :=
        "Status: ARMED for "
        . FormatTime(
            TargetTime,
            "ddd MMM d, yyyy, h:mm:ss tt"
        )


    A_IconTip :=
        "Codex Relay ARMED for "
        . FormatTime(
            TargetTime,
            "ddd MMM d, h:mm tt"
        )


    TrayTip(
        "Codex Relay",
        "Saved schedule restored for "
        . FormatTime(
            TargetTime,
            "ddd MMM d, h:mm tt"
        ),
        1
    )
}


; ============================================================
; MARK SAVED SCHEDULE INACTIVE
; ============================================================

MarkScheduleInactive()
{
    global StateFile


    if FileExist(
        StateFile
    )
    {
        IniWrite(
            "0",
            StateFile,
            "Schedule",
            "Armed"
        )
    }
}


; ============================================================
; SCHEDULE FIRES
; ============================================================

RunScheduledPrompt()
{
    global IsArmed
    global ShouldSend

    global CurrentPromptFile

    global StatusMessage
    global StatusText


    ; The timer is no longer armed once execution begins.
    IsArmed := false


    ; Mark inactive BEFORE interacting with Codex so a crash
    ; cannot accidentally resend the same prompt on restart.
    MarkScheduleInactive()


    ; ========================================================
    ; READ PROMPT FROM MARKDOWN
    ; ========================================================

    if !FileExist(
        CurrentPromptFile
    )
    {
        HandleScheduledFailure(
            "The scheduled prompt file could not be found."
        )

        return
    }


    try
    {
        promptText :=
            FileRead(
                CurrentPromptFile,
                "UTF-8"
            )
    }
    catch
    {
        HandleScheduledFailure(
            "The scheduled prompt file could not be read."
        )

        return
    }


    if Trim(promptText) = ""
    {
        HandleScheduledFailure(
            "The scheduled prompt file was empty."
        )

        return
    }


    ; ========================================================
    ; SEND TO CODEX
    ; ========================================================

    success :=
        ContinueCodex(
            promptText,
            ShouldSend
        )


    ; ========================================================
    ; SUCCESS
    ; ========================================================

    if success
    {
        completedTime :=
            FormatTime(
                A_Now,
                "h:mm:ss tt"
            )


        if ShouldSend
        {
            StatusMessage :=
                "Status: NOT ARMED — last prompt sent at "
                . completedTime


            TrayTip(
                "Codex Relay",
                "Scheduled prompt SENT at "
                . completedTime,
                1
            )
        }
        else
        {
            StatusMessage :=
                "Status: NOT ARMED — last prompt typed at "
                . completedTime


            TrayTip(
                "Codex Relay",
                "Prompt typed but NOT sent at "
                . completedTime,
                1
            )
        }


        A_IconTip :=
            "Codex Relay — not armed"


        if StatusText
            StatusText.Text := StatusMessage
    }


    ; ========================================================
    ; FAILURE
    ; ========================================================

    else
    {
        HandleScheduledFailure(
            "Could not control the ChatGPT desktop app."
        )
    }
}


; ============================================================
; FAILURE HANDLER
; ============================================================

HandleScheduledFailure(message)
{
    global StatusMessage
    global StatusText


    failedTime :=
        FormatTime(
            A_Now,
            "h:mm:ss tt"
        )


    StatusMessage :=
        "Status: NOT ARMED — last attempt failed at "
        . failedTime


    if StatusText
        StatusText.Text :=
            StatusMessage


    A_IconTip :=
        "Codex Relay — not armed"


    TrayTip(
        "Codex Relay",
        message,
        2
    )
}


; ============================================================
; CONTROL CHATGPT / CODEX
; ============================================================

ContinueCodex(
    promptText,
    sendIt := false
)
{
    ; ========================================================
    ; CHATGPT MUST ALREADY BE OPEN
    ; ========================================================

    codex :=
        WinExist(
            "ahk_exe ChatGPT.exe"
        )


    if !codex
        return false


    ; ========================================================
    ; BRING CHATGPT TO FRONT
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


    Sleep 1500


    ; ========================================================
    ; VERIFY FOCUS
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
    ; Based on the layout already tested successfully.
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


    Sleep 1000


    ; ========================================================
    ; VERIFY FOCUS AGAIN
    ; ========================================================

    if !WinActive(
        "ahk_id " codex
    )
    {
        return false
    }


    ; ========================================================
    ; PASTE PROMPT
    ;
    ; Clipboard paste is much safer for large multiline
    ; prompts than simulating thousands of keystrokes.
    ; ========================================================

    if !PastePromptText(
        promptText
    )
    {
        return false
    }


    ; ========================================================
    ; OPTIONAL ENTER
    ; ========================================================

    if sendIt
    {
        Sleep 800


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
; SAFE CLIPBOARD PASTE
; ============================================================

PastePromptText(text)
{
    savedClipboard :=
        ClipboardAll()


    A_Clipboard := ""


    A_Clipboard :=
        text


    if !ClipWait(2)
    {
        A_Clipboard :=
            savedClipboard


        return false
    }


    Send "^v"


    Sleep 400


    ; Restore whatever the user previously had copied.
    A_Clipboard :=
        savedClipboard


    return true
}


; ============================================================
; CANCEL ACTIVE SCHEDULE
; ============================================================

CancelTimer(*)
{
    global IsArmed
    global ScheduledCallback

    global StatusMessage
    global StatusText


    if ScheduledCallback
    {
        SetTimer(
            ScheduledCallback,
            0
        )
    }


    IsArmed := false


    MarkScheduleInactive()


    StatusMessage :=
        "Status: NOT ARMED — schedule cancelled"


    if StatusText
    {
        StatusText.Text :=
            StatusMessage
    }


    A_IconTip :=
        "Codex Relay — not armed"


    TrayTip(
        "Codex Relay",
        "Scheduled prompt cancelled.",
        1
    )
}


; ============================================================
; HIDE GUI
;
; IMPORTANT:
; Closing the GUI does NOT cancel an armed timer.
; Use Cancel or exit Codex Relay to stop an in-memory timer.
;
; The persistent schedule remains saved until Cancel or until
; the scheduled attempt begins.
; ============================================================

HideScheduler(*)
{
    global SchedulerGui


    if SchedulerGui
    {
        SchedulerGui.Hide()
    }
}