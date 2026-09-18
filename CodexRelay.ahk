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
; This version is a stable visual polish pass (V25):
;   - Dark / futuristic GUI
;   - Custom dark selectors (no bright white dropdown fields)
;   - Clearer section hierarchy
;   - Improved labels and status presentation
;   - Same scheduling and delivery behavior
; ============================================================


; ============================================================
; CONSTANTS / STORAGE
; ============================================================

global DEFAULT_PROMPT := "Continue where you left off"
global PROMPT_FOLDER_NAME := "Scheduled Prompts"
global STATE_FILE_NAME := "schedule.ini"

global PromptDir := A_ScriptDir "\" PROMPT_FOLDER_NAME
global StateFile := A_ScriptDir "\" STATE_FILE_NAME
global BackgroundDir := A_ScriptDir "\images"

global SelectedBackgroundName := "None"


; ============================================================
; GUI GLOBALS
; ============================================================

global SchedulerGui := 0

global BackgroundPic := 0
global BackgroundDropdown := 0

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
global StatusDot := 0
global FooterText := 0
global FocusSink := 0

global ArmButton := 0
global CancelButton := 0

; Prevents programmatic prompt resets from being mistaken for
; user edits by PromptTextChanged().
global SuppressPromptModeSync := false

; Tracks custom selector controls so only one popup can be open
; at a time, and so popups can be closed if the main window moves.
global DarkSelectorInstances := []


; ============================================================
; SCHEDULE GLOBALS
; ============================================================

global IsArmed := false
global ShouldSend := false

global TargetTime := ""
global CurrentPromptFile := ""

global ScheduledCallback := 0

global StatusMessage := "Status: NOT ARMED"


; ============================================================
; STARTUP
; ============================================================

DirCreate(PromptDir)
DirCreate(BackgroundDir)

; Backgrounds are optional eye candy.
; Always start in the clean default state instead of restoring a
; previous image. This avoids a partially-painted image state at
; launch and guarantees the app opens with the most readable UI.
SelectedBackgroundName := "None"

RestoreSavedSchedule()


; ============================================================
; HOTKEY
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
    global BackgroundPic

    global StatusText
    global StatusMessage

    global PreviewText
    global TargetTime
    global FocusSink

    if !SchedulerGui
    {
        BuildSchedulerGui()

        ; A newly-created GUI has blank dropdowns until
        ; initialized at least once.
        UpdateDefaultTime()
    }

    if !IsArmed
    {
        UpdateDefaultTime()
        UpdatePreview()
    }
    else
    {
        PreviewText.Text :=
            "CURRENTLY ARMED`n"
            . FormatTime(TargetTime, "dddd, MMMM d, yyyy")
            . "  •  "
            . FormatTime(TargetTime, "h:mm tt")
    }

    StatusText.Text := StatusMessage
    RefreshStatusStyle()
    RefreshActionButtons()

    SchedulerGui.Show("AutoSize Center")

    ; The GUI is fixed-size in normal use, but it is built with
    ; AutoSize. Resize the background after AutoSize has resolved
    ; the final client dimensions.
    UpdateBackgroundSize()

    ; Transparent static labels over a Picture control can need a
    ; full child repaint on Windows. Force one immediately after
    ; the final layout is known so labels don't appear only after
    ; mouse-hover repaint events.
    ForceSchedulerRedraw()

    ; Keep focus on a harmless invisible control so the default
    ; prompt does not open highlighted/selected.
    try FocusSink.Focus()
}


; ============================================================
; BUILD GUI
; ============================================================

BuildSchedulerGui()
{
    global SchedulerGui

    global BackgroundPic
    global BackgroundDropdown
    global SelectedBackgroundName

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
    global StatusDot
    global StatusMessage
    global FooterText
    global FocusSink
    global ArmButton
    global CancelButton

    global DEFAULT_PROMPT

    ; --------------------------------------------------------
    ; WINDOW
    ; --------------------------------------------------------

    SchedulerGui := Gui("+AlwaysOnTop", "Codex Relay")
    SchedulerGui.BackColor := "12161C"
    SchedulerGui.MarginX := 24
    SchedulerGui.MarginY := 22

    ; Default font for the window.
    SchedulerGui.SetFont("s10 cD7DEE7", "Segoe UI")

    EnableModernWindowStyle(SchedulerGui.Hwnd)

    ; --------------------------------------------------------
    ; BACKGROUND IMAGE LAYER
    ;
    ; Added before every visible control so later controls are
    ; naturally drawn above it. It starts at 1x1 so it does not
    ; influence AutoSize. ShowScheduler() expands it to the
    ; final client size after the window is laid out.
    ; --------------------------------------------------------

    BackgroundPic := SchedulerGui.AddPicture(
        "x0 y0 w1 h1 Hidden Disabled",
        ""
    )

    ; Off-screen focus target. A tiny Button can receive keyboard
    ; focus without showing a text caret. It is placed outside the
    ; visible client area, so clicking empty space does not leave a
    ; blinking cursor anywhere in the GUI.
    FocusSink := SchedulerGui.AddButton(
        "x-100 y-100 w1 h1 -TabStop",
        ""
    )

    ; --------------------------------------------------------
    ; HEADER
    ; --------------------------------------------------------

    title := SchedulerGui.AddText("x0 ym w608 h36 Center BackgroundTrans", "CODEX RELAY")
    title.SetFont("s19 Bold c62B7FF", "Segoe UI")

    subtitle := SchedulerGui.AddText(
        "x0 y+3 w608 Center BackgroundTrans",
        "Scheduled prompt delivery for your current Codex session"
    )
    subtitle.SetFont("s10 cA9B4C3", "Segoe UI")

    meta := SchedulerGui.AddText(
        "x0 y+5 w608 Center BackgroundTrans",
        "CTRL + ALT + K   •   ONE ACTIVE SCHEDULE AT A TIME"
    )
    meta.SetFont("s8 Bold c687386", "Segoe UI")

    ; --------------------------------------------------------
    ; BACKGROUND SELECTOR
    ; --------------------------------------------------------

    backgroundItems :=
        GetBackgroundChoices()

    backgroundChoiceIndex :=
        GetBackgroundChoiceIndex(
            backgroundItems,
            SelectedBackgroundName
        )

    ; Center the Background label + selector as one visual group.
    ; The selector grows for longer image filenames (up to a
    ; reasonable maximum) and the whole group is re-centered.
    backgroundEditWidth :=
        GetBackgroundSelectorWidth(
            backgroundItems
        )

    backgroundLabelWidth := 82
    backgroundGap := 8
    backgroundArrowWidth := 24

    backgroundGroupWidth :=
        backgroundLabelWidth
        + backgroundGap
        + backgroundEditWidth
        + backgroundArrowWidth

    backgroundGroupX :=
        Round(
            (608 - backgroundGroupWidth) / 2
        )

    backgroundLabel := SchedulerGui.AddText(
        "x" backgroundGroupX
        . " y+9 w" backgroundLabelWidth
        . " Right BackgroundTrans",
        "Background"
    )
    backgroundLabel.SetFont(
        "s8 c687386",
        "Segoe UI"
    )

    BackgroundDropdown := DarkSelector(
        SchedulerGui,
        "x+" backgroundGap
        . " yp-4 w" backgroundEditWidth
        . " h24",
        "x+0 yp w" backgroundArrowWidth
        . " h24",
        backgroundItems,
        backgroundChoiceIndex
    )

    SchedulerGui.AddProgress(
        "x0 y+14 w608 h2 c3A8DFF Background25303B",
        100
    )

    ; --------------------------------------------------------
    ; SECTION 01 — PROMPT
    ; --------------------------------------------------------

    section1 := SchedulerGui.AddText("xm y+18 w560 BackgroundTrans", "1)  Prompt")
    section1.SetFont("s9 Bold c62B7FF", "Segoe UI")

    promptLabel := SchedulerGui.AddText("xm y+10 w120 BackgroundTrans", "Prompt mode")
    promptLabel.SetFont("s9 c98A5B5", "Segoe UI")

    PromptTypeDropdown := DarkSelector(
        SchedulerGui,
        "xm y+5 w250 h27",
        "x+0 yp w30 h27",
        [
            "Continue where you left off",
            "Custom Prompt"
        ],
        1
    )

    promptTextLabel := SchedulerGui.AddText("xm y+14 w120 BackgroundTrans", "Prompt text")
    promptTextLabel.SetFont("s9 c98A5B5", "Segoe UI")

    PromptEdit := SchedulerGui.AddEdit(
        "xm y+5 w560 r7 WantTab -Theme -Border -E0x200 Background20252B cF1F4F8",
        DEFAULT_PROMPT
    )
    PromptEdit.SetFont("s10", "Segoe UI")

    ; --------------------------------------------------------
    ; OPTIONS DATA
    ; --------------------------------------------------------

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

    hours := []
    Loop 12
        hours.Push(String(A_Index))

    minutes := []
    Loop 60
        minutes.Push(Format("{:02}", A_Index - 1))

    buffers := [
        "0",
        "5",
        "10",
        "15",
        "20",
        "30"
    ]

    ; --------------------------------------------------------
    ; SECTION 02 — SCHEDULE
    ; --------------------------------------------------------

    section2 := SchedulerGui.AddText("xm y+20 w560 BackgroundTrans", "2)  Schedule")
    section2.SetFont("s9 Bold c62B7FF", "Segoe UI")

    dayLabel := SchedulerGui.AddText("xm y+10 w175 BackgroundTrans", "DAY")
    dayLabel.SetFont("s8 Bold c687386", "Segoe UI")

    resetLabel := SchedulerGui.AddText("x+14 yp w235 BackgroundTrans", "RESET TIME")
    resetLabel.SetFont("s8 Bold c687386", "Segoe UI")

    bufferLabel := SchedulerGui.AddText("x+14 yp w115 BackgroundTrans", "BUFFER")
    bufferLabel.SetFont("s8 Bold c687386", "Segoe UI")

    DaysDropdown := DarkSelector(
        SchedulerGui,
        "xm y+5 w147 h27",
        "x+0 yp w28 h27",
        days
    )

    HourDropdown := DarkSelector(
        SchedulerGui,
        "x+14 yp w32 h27",
        "x+0 yp w24 h27",
        hours
    )

    colon := SchedulerGui.AddText("x+5 yp+4 BackgroundTrans", ":")
    colon.SetFont("s10 Bold cA9B4C3", "Segoe UI")

    MinuteDropdown := DarkSelector(
        SchedulerGui,
        "x+5 yp-4 w36 h27",
        "x+0 yp w26 h27",
        minutes
    )

    AmPmDropdown := DarkSelector(
        SchedulerGui,
        "x+7 yp w44 h27",
        "x+0 yp w26 h27",
        [
            "AM",
            "PM"
        ]
    )

    BufferDropdown := DarkSelector(
        SchedulerGui,
        "x+14 yp w40 h27",
        "x+0 yp w26 h27",
        buffers
    )

    bufferUnit := SchedulerGui.AddText("x+5 yp+4 BackgroundTrans", "min")
    bufferUnit.SetFont("s9 c98A5B5", "Segoe UI")

    bufferHelp := SchedulerGui.AddText(
        "xm y+9 w560 BackgroundTrans",
        "Safety buffer = extra wait time after the reset time before delivery."
    )
    bufferHelp.SetFont("s8 c687386", "Segoe UI")

    ; --------------------------------------------------------
    ; SECTION 03 — DELIVERY
    ; --------------------------------------------------------

    section3 := SchedulerGui.AddText("xm y+18 w560 BackgroundTrans", "3)  Delivery")
    section3.SetFont("s9 Bold c62B7FF", "Segoe UI")

    ; Custom transparent checkbox row.
    ; Native Windows checkbox controls paint their own rectangular
    ; background, which looks out of place over optional images.
    ; This custom control preserves the same .Value behavior used
    ; by the scheduling code while rendering as transparent text.
    SendCheckbox := TransparentCheckbox(
        SchedulerGui,
        "xm y+10",
        "Send automatically — press Enter after the prompt is pasted"
    )

    safetyNote := SchedulerGui.AddText(
        "xm y+7 w560 BackgroundTrans",
        "Tip: leave this unchecked for your first positioning test."
    )
    safetyNote.SetFont("s8 c687386", "Segoe UI")

    ; Divider between delivery controls and the preview/status area.
    SchedulerGui.AddProgress(
        "x0 y+16 w608 h1 c25303B Background25303B",
        100
    )

    ; --------------------------------------------------------
    ; PREVIEW
    ; --------------------------------------------------------

    previewLabel := SchedulerGui.AddText(
        "x0 y+14 w608 Center BackgroundTrans",
        "DELIVERY PREVIEW"
    )
    previewLabel.SetFont("s8 Bold c687386", "Segoe UI")

    PreviewText := SchedulerGui.AddText(
        "x0 y+5 w608 h44 Center BackgroundTrans",
        "NEW SCHEDULE`nCalculating..."
    )
    PreviewText.SetFont("s10 Bold cFFD166", "Segoe UI")

    ; --------------------------------------------------------
    ; STATUS
    ; --------------------------------------------------------

    SchedulerGui.AddProgress(
        "x0 y+9 w608 h1 c25303B Background25303B",
        100
    )

    statusLabel := SchedulerGui.AddText(
        "x0 y+14 w608 Center BackgroundTrans",
        "RELAY STATUS"
    )
    statusLabel.SetFont("s8 Bold c687386", "Segoe UI")

    ; Center the status text across the full content area.
    StatusText := SchedulerGui.AddText(
        "x0 y+10 w608 h36 Center BackgroundTrans",
        StatusMessage
    )
    StatusText.SetFont("s10 Bold cA9B4C3", "Segoe UI")

    ; Draw the blue state dot afterward so it remains visible.
    StatusDot := SchedulerGui.AddText(
        "x220 yp-2 w16 Center BackgroundTrans",
        "●"
    )
    StatusDot.SetFont("s13 c778394", "Segoe UI")

    ; --------------------------------------------------------
    ; ACTIONS
    ; --------------------------------------------------------

    ; One centered action at a time:
    ;   NOT ARMED -> ARM RELAY (green text)
    ;   ARMED     -> CANCEL    (red text)
    ArmButton := FlatTextButton(
        SchedulerGui,
        "x214 y+18 w180 h38",
        "ARM RELAY",
        "2C3137",
        "5DE08B"
    )

    CancelButton := FlatTextButton(
        SchedulerGui,
        "x214 yp w180 h38 Hidden",
        "CANCEL",
        "2C3137",
        "FF6B6B"
    )

    FooterText := SchedulerGui.AddText(
        "x0 y+14 w608 Center BackgroundTrans",
        "Close this window with X. Closing it does not cancel an armed schedule."
    )
    FooterText.SetFont("s8 c5F6978", "Segoe UI")

    ; Keep the original keyboard behavior: pressing Enter while
    ; the scheduler is active still arms the relay.
    defaultArmButton := SchedulerGui.AddButton(
        "x0 y0 w1 h1 Hidden Default",
        ""
    )
    defaultArmButton.OnEvent("Click", ArmTimer)

    ; --------------------------------------------------------
    ; TRY TO USE WINDOWS' DARK CONTROL THEME
    ;
    ; These calls are cosmetic only. If Windows ignores them,
    ; Codex Relay still works normally.
    ; --------------------------------------------------------

    for ctrl in [
        PromptEdit
    ]
    {
        ApplyDarkControlTheme(ctrl)
    }

    ; --------------------------------------------------------
    ; EVENTS
    ; --------------------------------------------------------

    PromptTypeDropdown.OnEvent("Change", PromptTypeChanged)
    PromptEdit.OnEvent("Change", PromptTextChanged)
    BackgroundDropdown.OnEvent("Change", BackgroundChanged)

    ; Clicking into normal controls should dismiss any open
    ; selector popup so the UI behaves like a conventional app.
    PromptEdit.OnEvent("Focus", CloseSelectorPopupsOnInteraction)
    SendCheckbox.OnEvent("Click", CloseSelectorPopupsOnInteraction)

    DaysDropdown.OnEvent("Change", UpdatePreview)
    HourDropdown.OnEvent("Change", UpdatePreview)
    MinuteDropdown.OnEvent("Change", UpdatePreview)
    AmPmDropdown.OnEvent("Change", UpdatePreview)
    BufferDropdown.OnEvent("Change", UpdatePreview)

    ArmButton.OnEvent("Click", ArmTimer)
    CancelButton.OnEvent("Click", CancelTimer)

    SchedulerGui.OnEvent("Close", HideScheduler)

    ; Close any open selector popup if the main Codex Relay
    ; window is moved. This prevents detached/floating dropdowns
    ; from being left behind on another monitor.
    OnMessage(0x0003, SchedulerWindowMoved)

    ; Empty-background clicks dismiss selector popups and move
    ; focus to the harmless focus sink.
    OnMessage(0x0201, SchedulerLeftClick)

    ApplySelectedBackground(false)
    RefreshStatusStyle()
    RefreshActionButtons()
}


; ============================================================
; CUSTOM DARK SELECTOR
;
; Native Windows dropdown fields stay bright on some systems.
; This wrapper uses a dark read-only Edit + small arrow button
; and opens a normal popup menu for selection.
;
; It intentionally mimics the small part of the DropDownList
; API used elsewhere in Codex Relay:
;   .Text
;   .Value
;   .Choose(index)
;   .OnEvent("Change", callback)
; ============================================================

class FlatTextButton
{
    __New(
        gui,
        options,
        caption,
        fillColor := "2C3137",
        textColor := "F1F4F8"
    )
    {
        this.ClickCallback := 0

        this.Control := gui.AddText(
            options
            . " Center +0x200 +0x100"
            . " Background" fillColor
            . " c" textColor,
            caption
        )

        this.Control.SetFont(
            "s10 Bold c" textColor,
            "Segoe UI"
        )

        this.Control.OnEvent(
            "Click",
            ObjBindMethod(this, "Clicked")
        )
    }


    OnEvent(eventName, callback)
    {
        if eventName = "Click"
            this.ClickCallback := callback
    }


    Clicked(*)
    {
        if this.ClickCallback
            this.ClickCallback.Call(this)
    }
}


class TransparentCheckbox
{
    __New(
        gui,
        positionOptions,
        caption,
        initialValue := 0
    )
    {
        this.Checked := initialValue ? 1 : 0
        this.ClickCallback := 0

        ; Small checkbox glyph. BackgroundTrans lets the selected
        ; app background (or normal GUI BackColor when None is
        ; selected) show through cleanly.
        this.Box := gui.AddText(
            positionOptions
            . " w22 h24 Center +0x200 BackgroundTrans cD7DEE7",
            ""
        )

        this.Box.SetFont(
            "s12 cD7DEE7",
            "Segoe UI Symbol"
        )

        ; Caption is a separate transparent Text control so there
        ; is no long native checkbox background rectangle.
        this.Label := gui.AddText(
            "x+2 yp w530 h24 +0x200 BackgroundTrans cF1F4F8",
            caption
        )

        this.Label.SetFont(
            "s10 cF1F4F8",
            "Segoe UI"
        )

        this.Box.OnEvent(
            "Click",
            ObjBindMethod(this, "Clicked")
        )

        this.Label.OnEvent(
            "Click",
            ObjBindMethod(this, "Clicked")
        )

        this.RefreshVisual()
    }


    Value
    {
        get => this.Checked
        set
        {
            this.Checked := value ? 1 : 0
            this.RefreshVisual()
        }
    }


    OnEvent(
        eventName,
        callback
    )
    {
        if eventName = "Click"
            this.ClickCallback := callback
    }


    Clicked(*)
    {
        this.Checked := !this.Checked

        this.RefreshVisual()

        if this.ClickCallback
            this.ClickCallback.Call(this)
    }


    RefreshVisual()
    {
        if this.Checked
        {
            this.Box.Text := "☑"
            this.Box.SetFont(
                "s12 c62B7FF",
                "Segoe UI Symbol"
            )
        }
        else
        {
            this.Box.Text := "☐"
            this.Box.SetFont(
                "s12 cD7DEE7",
                "Segoe UI Symbol"
            )
        }
    }
}


class DarkSelector
{
    __New(gui, editOptions, buttonOptions, items, chooseIndex := 0)
    {
        global DarkSelectorInstances

        this.ParentGui := gui
        this.Items := items
        this.Index := 0
        this.ChangeCallback := 0
        this.PopupGui := 0
        this.PopupList := 0

        DarkSelectorInstances.Push(this)

        ; Borderless dark read-only field.
        this.Edit := gui.AddEdit(
            editOptions
            . " ReadOnly -TabStop -Border -E0x200"
            . " Background20252B cF1F4F8",
            ""
        )
        this.Edit.SetFont(
            "s10 cF1F4F8",
            "Segoe UI"
        )

        ; Flat arrow button with softer gray arrow color so it
        ; visually matches the prompt editor's dark scrollbar.
        this.Button := FlatTextButton(
            gui,
            buttonOptions,
            "▼",
            "242A30",
            "AEB6BF"
        )

        this.Button.OnEvent(
            "Click",
            ObjBindMethod(this, "ShowPopup")
        )

        if chooseIndex > 0
            this.Choose(chooseIndex)
    }


    Text
    {
        get => this.Edit.Value
    }


    Value
    {
        get => this.Index
    }


    Choose(index)
    {
        if index < 1 || index > this.Items.Length
            return

        this.Index := index
        this.Edit.Value := this.Items[index]
    }


    OnEvent(eventName, callback)
    {
        if eventName = "Change"
            this.ChangeCallback := callback
    }


    ShowPopup(*)
    {
        ; Clicking the same selector again toggles its popup closed.
        if this.PopupGui
        {
            this.ClosePopup()
            return
        }

        ; Only one selector popup may be open at a time.
        ; Opening a different selector closes any existing popup.
        CloseAllSelectorPopups(this)

        ; ----------------------------------------------------
        ; SIZE / POSITION
        ; ----------------------------------------------------

        this.Edit.GetPos(&editX, &editY, &editW, &editH)
        this.Button.Control.GetPos(&btnX, &btnY, &btnW, &btnH)

        popupW := editW + btnW

        ; For long lists (minutes), show a compact scrolling
        ; list rather than a full-screen menu.
        visibleRows := Min(this.Items.Length, 15)

        ; Get screen position from the selector's arrow button.
        rect := Buffer(16, 0)

        DllCall(
            "GetWindowRect",
            "Ptr", this.Button.Control.Hwnd,
            "Ptr", rect.Ptr
        )

        left := NumGet(rect, 0, "Int")
        bottom := NumGet(rect, 12, "Int")

        popupX := left - editW
        popupY := bottom + 2

        ; ----------------------------------------------------
        ; DARK POPUP
        ; ----------------------------------------------------

        this.PopupGui := Gui(
            "-Caption +ToolWindow -Border +Owner" this.ParentGui.Hwnd,
            ""
        )

        this.PopupGui.BackColor := "171B20"
        this.PopupGui.MarginX := 0
        this.PopupGui.MarginY := 0
        this.PopupGui.SetFont(
            "s10 cF1F4F8",
            "Segoe UI"
        )

        this.PopupList := this.PopupGui.AddListBox(
            "xm ym w" popupW
            . " r" visibleRows
            . " -Border -E0x200"
            . " Background20252B cF1F4F8",
            this.Items
        )

        this.PopupList.SetFont(
            "s10 cF1F4F8",
            "Segoe UI"
        )

        ApplyDarkControlTheme(this.PopupList)

        if this.Index > 0
            this.PopupList.Choose(this.Index)

        this.PopupList.OnEvent(
            "Change",
            ObjBindMethod(this, "PopupSelectionChanged")
        )

        this.PopupList.OnEvent(
            "DoubleClick",
            ObjBindMethod(this, "PopupSelectionChanged")
        )

        this.PopupGui.OnEvent(
            "Escape",
            ObjBindMethod(this, "ClosePopup")
        )

        this.PopupGui.OnEvent(
            "Close",
            ObjBindMethod(this, "ClosePopup")
        )

        this.PopupGui.Show(
            "x" popupX
            . " y" popupY
            . " AutoSize"
        )

        this.PopupList.Focus()
    }


    PopupSelectionChanged(*)
    {
        if !this.PopupList
            return

        selected := this.PopupList.Value

        if selected < 1
            return

        this.Choose(selected)

        if this.ChangeCallback
            this.ChangeCallback.Call(this)

        this.ClosePopup()
    }


    ClosePopup(*)
    {
        if this.PopupGui
        {
            try this.PopupGui.Destroy()
        }

        this.PopupGui := 0
        this.PopupList := 0
    }
}


; ============================================================
; SELECTOR POPUP MANAGER
; ============================================================

CloseSelectorPopupsOnInteraction(*)
{
    CloseAllSelectorPopups()
}


CloseAllSelectorPopups(exceptSelector := 0)
{
    global DarkSelectorInstances

    for selector in DarkSelectorInstances
    {
        if exceptSelector && selector = exceptSelector
            continue

        try selector.ClosePopup()
    }
}


SchedulerWindowMoved(wParam, lParam, msg, hwnd)
{
    global SchedulerGui

    if SchedulerGui && hwnd = SchedulerGui.Hwnd
        CloseAllSelectorPopups()
}


SchedulerLeftClick(wParam, lParam, msg, hwnd)
{
    global SchedulerGui
    global FocusSink

    ; A WM_LBUTTONDOWN delivered directly to the GUI window
    ; means the user clicked empty background rather than a
    ; child control.
    if SchedulerGui && hwnd = SchedulerGui.Hwnd
    {
        CloseAllSelectorPopups()
        try FocusSink.Focus()
    }
}


; ============================================================
; COSMETIC HELPERS
; ============================================================

EnableModernWindowStyle(hwnd)
{
    ; Dark title bar on supported Windows versions.
    try
    {
        darkValue := Buffer(4, 0)
        NumPut("Int", 1, darkValue, 0)

        DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "Ptr", hwnd,
            "Int", 20,
            "Ptr", darkValue.Ptr,
            "Int", 4
        )
    }

    ; Rounded Windows 11 corners where supported.
    try
    {
        cornerValue := Buffer(4, 0)
        NumPut("Int", 2, cornerValue, 0)

        DllCall(
            "dwmapi\DwmSetWindowAttribute",
            "Ptr", hwnd,
            "Int", 33,
            "Ptr", cornerValue.Ptr,
            "Int", 4
        )
    }
}


ApplyDarkControlTheme(ctrl)
{
    try
    {
        DllCall(
            "uxtheme\SetWindowTheme",
            "Ptr", ctrl.Hwnd,
            "Str", "DarkMode_Explorer",
            "Ptr", 0
        )
    }
}


GetBackgroundChoices()
{
    global BackgroundDir

    items := ["None"]

    patterns := [
        "*.png",
        "*.jpg",
        "*.jpeg",
        "*.bmp",
        "*.gif"
    ]

    for _, pattern in patterns
    {
        Loop Files, BackgroundDir "\" pattern, "F"
        {
            items.Push(
                A_LoopFileName
            )
        }
    }

    return items
}


GetBackgroundSelectorWidth(items)
{
    ; Approximate text width well enough for Segoe UI 10 and
    ; keep the selector from becoming absurdly wide.
    width := 130

    for _, itemName in items
    {
        candidate :=
            (StrLen(itemName) * 7)
            + 18

        if candidate > width
            width := candidate
    }

    if width > 240
        width := 240

    return width
}


GetBackgroundChoiceIndex(
    items,
    wantedName
)
{
    for index, itemName in items
    {
        if itemName = wantedName
            return index
    }

    return 1
}


BackgroundChanged(*)
{
    ApplySelectedBackground()
}


ApplySelectedBackground(
    saveChoice := true
)
{
    global BackgroundDropdown
    global BackgroundPic
    global BackgroundDir
    global SelectedBackgroundName
    global StateFile

    if !BackgroundDropdown || !BackgroundPic
        return

    chosen :=
        BackgroundDropdown.Text

    if chosen = "" || chosen = "None"
    {
        SelectedBackgroundName := "None"

        BackgroundPic.Value := ""
        BackgroundPic.Visible := false
    }
    else
    {
        imagePath :=
            BackgroundDir
            . "\"
            . chosen

        if FileExist(
            imagePath
        )
        {
            SelectedBackgroundName := chosen

            ; The Picture control keeps the same GUI position and
            ; size; changing Value swaps only the image.
            BackgroundPic.Value := imagePath
            BackgroundPic.Visible := true

            UpdateBackgroundSize()
        }
        else
        {
            SelectedBackgroundName := "None"

            BackgroundPic.Value := ""
            BackgroundPic.Visible := false

            BackgroundDropdown.Choose(1)
        }
    }

    if saveChoice
    {
        ; Keep recording the user's latest selection in the INI
        ; for future use / diagnostics, but V21 intentionally does
        ; not restore it automatically on startup. Every launch
        ; begins with Background = None.
        IniWrite(
            SelectedBackgroundName,
            StateFile,
            "Appearance",
            "BackgroundImage"
        )
    }

    ; Repaint the entire GUI whenever the background changes so
    ; BackgroundTrans labels redraw against the newly selected
    ; image (or the normal GUI background when "None" is chosen).
    ForceSchedulerRedraw()
}


UpdateBackgroundSize()
{
    global SchedulerGui
    global BackgroundPic

    if !SchedulerGui || !BackgroundPic
        return

    try
    {
        WinGetClientPos(
            &clientX,
            &clientY,
            &clientW,
            &clientH,
            "ahk_id " SchedulerGui.Hwnd
        )

        if clientW > 0 && clientH > 0
        {
            BackgroundPic.Move(
                0,
                0,
                clientW,
                clientH
            )
        }
    }
}


ForceSchedulerRedraw()
{
    global SchedulerGui

    if !SchedulerGui
        return

    try
    {
        ; RDW_INVALIDATE | RDW_ERASE | RDW_ALLCHILDREN |
        ; RDW_UPDATENOW
        flags := 0x0001 | 0x0004 | 0x0080 | 0x0100

        DllCall(
            "RedrawWindow",
            "Ptr", SchedulerGui.Hwnd,
            "Ptr", 0,
            "Ptr", 0,
            "UInt", flags
        )
    }
}


UpdateStatusLayout()
{
    global StatusMessage
    global StatusDot

    if !StatusDot
        return

    ; The status text itself remains centered. The dot is placed
    ; separately to the left of the estimated text start.
    ;
    ; Use a deliberately conservative width estimate and extra
    ; breathing room. This prevents the dot from covering the
    ; beginning of longer messages such as:
    ; "Status: ARMED for Wednesday ..."
    ;
    ; If the message becomes exceptionally long, clamp the dot
    ; near the left edge rather than ever allowing an overlap.
    estimatedTextWidth := StrLen(StatusMessage) * 8.6

    contentLeft := 0
    contentWidth := 608
    gap := 26

    textLeft :=
        contentLeft
        + ((contentWidth - estimatedTextWidth) / 2)

    dotX := Round(textLeft - gap)

    if dotX < contentLeft
        dotX := contentLeft

    ; For short messages, keep the dot reasonably close rather
    ; than letting it drift too far toward the center.
    if dotX > 218
        dotX := 218

    try StatusDot.Move(dotX)
}


RefreshStatusStyle()
{
    global StatusMessage
    global StatusDot
    global StatusText

    if !StatusDot || !StatusText
        return

    ; Keep the colored dot immediately to the left of the
    ; centered status message, even when the message gets much
    ; longer after a schedule is armed.
    UpdateStatusLayout()

    if InStr(StatusMessage, "ARMED for")
    {
        StatusDot.SetFont("s13 c5DE08B", "Segoe UI")
        StatusText.SetFont("s10 Bold cB8F3CB", "Segoe UI")
    }
    else if InStr(StatusMessage, "failed")
        || InStr(StatusMessage, "missed")
        || InStr(StatusMessage, "missing")
        || InStr(StatusMessage, "invalid")
    {
        StatusDot.SetFont("s13 cFFB454", "Segoe UI")
        StatusText.SetFont("s10 Bold cFFD19A", "Segoe UI")
    }
    else
    {
        ; NOT ARMED is intentionally red so the state is visually
        ; distinct from the green ARMED state.
        StatusDot.SetFont("s13 cFF6B6B", "Segoe UI")
        StatusText.SetFont("s10 Bold cA9B4C3", "Segoe UI")
    }
}


RefreshActionButtons()
{
    global IsArmed
    global ArmButton
    global CancelButton
    global FooterText

    if !ArmButton || !CancelButton
        return

    if IsArmed
    {
        ArmButton.Control.Visible := false
        CancelButton.Control.Visible := true

        if FooterText
        {
            FooterText.Text :=
                "Relay armed. You may now close this window with X."
        }
    }
    else
    {
        CancelButton.Control.Visible := false
        ArmButton.Control.Visible := true

        if FooterText
        {
            FooterText.Text :=
                "Close this window with X. Closing it does not cancel an armed schedule."
        }
    }
}


; ============================================================
; PROMPT TYPE CHANGED
; ============================================================

PromptTypeChanged(*)
{
    global PromptTypeDropdown
    global PromptEdit
    global DEFAULT_PROMPT
    global SuppressPromptModeSync

    SuppressPromptModeSync := true

    if PromptTypeDropdown.Text = "Continue where you left off"
    {
        PromptEdit.Value := DEFAULT_PROMPT
    }
    else
    {
        if Trim(PromptEdit.Value) = DEFAULT_PROMPT
            PromptEdit.Value := ""

        PromptEdit.Focus()
    }

    SuppressPromptModeSync := false
}


PromptTextChanged(*)
{
    global PromptTypeDropdown
    global PromptEdit
    global DEFAULT_PROMPT
    global SuppressPromptModeSync

    if SuppressPromptModeSync
        return

    ; Natural behavior: if the user edits the built-in prompt at
    ; all, the mode immediately becomes Custom Prompt. The text
    ; they typed is preserved exactly as-is.
    if PromptTypeDropdown.Value = 1
        && PromptEdit.Value != DEFAULT_PROMPT
    {
        PromptTypeDropdown.Choose(2)
    }
}


ResetPromptComposerAfterDelivery()
{
    global PromptTypeDropdown
    global PromptEdit
    global SendCheckbox
    global DEFAULT_PROMPT
    global SuppressPromptModeSync
    global ShouldSend

    SuppressPromptModeSync := true

    PromptTypeDropdown.Choose(1)
    PromptEdit.Value := DEFAULT_PROMPT
    SendCheckbox.Value := 0
    ShouldSend := false

    SuppressPromptModeSync := false
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

    defaultTime := DateAdd(A_Now, 5, "Hours")

    todayDate := FormatTime(A_Now, "yyyyMMdd")
    defaultDate := FormatTime(defaultTime, "yyyyMMdd")

    if defaultDate = todayDate
        DaysDropdown.Choose(1)
    else
        DaysDropdown.Choose(2)

    hour12 := Number(FormatTime(defaultTime, "h"))
    HourDropdown.Choose(hour12)

    minute := Number(FormatTime(defaultTime, "mm"))
    MinuteDropdown.Choose(minute + 1)

    ampm := FormatTime(defaultTime, "tt")

    if ampm = "AM"
        AmPmDropdown.Choose(1)
    else
        AmPmDropdown.Choose(2)

    ; Default safety buffer = 10 minutes.
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

    daysAhead := GetDaysAhead()

    hour := Number(HourDropdown.Text)
    minute := Number(MinuteDropdown.Text)
    ampm := AmPmDropdown.Text
    bufferMinutes := Number(BufferDropdown.Text)

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

    todayMidnight :=
        FormatTime(A_Now, "yyyyMMdd")
        . "000000"

    selectedDay := DateAdd(
        todayMidnight,
        daysAhead,
        "Days"
    )

    selectedDate := FormatTime(
        selectedDay,
        "yyyyMMdd"
    )

    resetTimestamp :=
        selectedDate
        . Format("{:02}", hour24)
        . Format("{:02}", minute)
        . "00"

    targetTime := DateAdd(
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

    target := GetTargetTimeFromGui()

    secondsUntil := DateDiff(
        target,
        A_Now,
        "Seconds"
    )

    if secondsUntil <= 0
    {
        PreviewText.Text :=
            "NEW SCHEDULE`n"
            . "Selected time is not in the future."

        return
    }

    PreviewText.Text :=
        "NEW SCHEDULE`n"
        . FormatTime(target, "dddd, MMMM d, yyyy")
        . "  •  "
        . FormatTime(target, "h:mm tt")
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
    global PreviewText
    global FooterText

    global IsArmed
    global ShouldSend

    global TargetTime
    global CurrentPromptFile
    global ScheduledCallback

    ; While armed, the visible action is Cancel. Prevent the
    ; hidden default Enter button from silently replacing the
    ; existing schedule.
    if IsArmed
        return

    promptText := Trim(PromptEdit.Value)

    if promptText = ""
    {
        MsgBox("The prompt cannot be empty.")
        return
    }

    TargetTime := GetTargetTimeFromGui()

    secondsUntil := DateDiff(
        TargetTime,
        A_Now,
        "Seconds"
    )

    if secondsUntil <= 0
    {
        MsgBox("The scheduled time must be in the future.")
        return
    }

    ShouldSend := SendCheckbox.Value = 1
    createdTime := A_Now

    CurrentPromptFile := SavePromptToMarkdown(
        promptText,
        createdTime,
        TargetTime
    )

    if CurrentPromptFile = ""
    {
        MsgBox("Codex Relay could not save the prompt file.")
        return
    }

    if ScheduledCallback
        SetTimer(ScheduledCallback, 0)

    ScheduledCallback := RunScheduledPrompt

    SetTimer(
        ScheduledCallback,
        -(secondsUntil * 1000)
    )

    IsArmed := true

    SaveScheduleState(createdTime)

    StatusMessage :=
        "Status: ARMED for "
        . FormatTime(
            TargetTime,
            "ddd MMM d, yyyy, h:mm:ss tt"
        )

    StatusText.Text := StatusMessage
    RefreshStatusStyle()

    A_IconTip :=
        "Codex Relay ARMED for "
        . FormatTime(
            TargetTime,
            "ddd MMM d, h:mm tt"
        )

    ; Keep the scheduler visible after arming so the user gets
    ; immediate visual confirmation before choosing to close it.
    CloseAllSelectorPopups()

    PreviewText.Text :=
        "CURRENTLY ARMED`n"
        . FormatTime(
            TargetTime,
            "dddd, MMMM d, yyyy"
        )
        . "  •  "
        . FormatTime(
            TargetTime,
            "h:mm tt"
        )

    RefreshActionButtons()

    try FocusSink.Focus()

    TrayTip(
        "Codex Relay",
        "Prompt saved and armed for "
        . FormatTime(TargetTime, "ddd MMM d")
        . " at "
        . FormatTime(TargetTime, "h:mm tt"),
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

    DirCreate(PromptDir)

    filename :=
        "created_"
        . FormatTime(createdTime, "yyyy-MM-dd_HH-mm-ss")
        . "__scheduled_"
        . FormatTime(scheduledTime, "yyyy-MM-dd_HH-mm-ss")
        . ".md"

    filePath :=
        PromptDir
        . "\"
        . filename

    counter := 2

    while FileExist(filePath)
    {
        filename :=
            "created_"
            . FormatTime(createdTime, "yyyy-MM-dd_HH-mm-ss")
            . "__scheduled_"
            . FormatTime(scheduledTime, "yyyy-MM-dd_HH-mm-ss")
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

    A_IconTip := "Codex Relay — not armed"

    if !FileExist(StateFile)
        return

    armed := IniRead(
        StateFile,
        "Schedule",
        "Armed",
        "0"
    )

    if armed != "1"
        return

    savedTarget := IniRead(
        StateFile,
        "Schedule",
        "TargetTime",
        ""
    )

    savedPromptFilename := IniRead(
        StateFile,
        "Schedule",
        "PromptFile",
        ""
    )

    savedPressEnter := IniRead(
        StateFile,
        "Schedule",
        "PressEnter",
        "0"
    )

    if savedTarget = "" || savedPromptFilename = ""
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

    TargetTime := savedTarget
    ShouldSend := savedPressEnter = "1"

    secondsUntil := DateDiff(
        TargetTime,
        A_Now,
        "Seconds"
    )

    ; Safety rule:
    ; NEVER automatically send a prompt late after restart.
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

    if !FileExist(CurrentPromptFile)
    {
        MarkScheduleInactive()

        IsArmed := false

        StatusMessage :=
            "Status: NOT ARMED — saved prompt file is missing"

        A_IconTip :=
            "Codex Relay — prompt file missing"

        return
    }

    ScheduledCallback := RunScheduledPrompt

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

    if FileExist(StateFile)
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
    global FooterText

    IsArmed := false

    ; Mark inactive BEFORE interacting with Codex so a crash
    ; cannot accidentally resend the same prompt on restart.
    MarkScheduleInactive()

    if !FileExist(CurrentPromptFile)
    {
        HandleScheduledFailure(
            "The scheduled prompt file could not be found."
        )

        return
    }

    try
    {
        promptText := FileRead(
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

    success := ContinueCodex(
        promptText,
        ShouldSend
    )

    if success
    {
        completedTime := FormatTime(
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

        A_IconTip := "Codex Relay — not armed"

        if StatusText
        {
            StatusText.Text := StatusMessage
            RefreshStatusStyle()
        }

        ; The prompt has left Codex Relay successfully. Reset the
        ; composer to a clean ready state so the previous custom
        ; prompt / auto-send choice cannot be mistaken for a new job.
        ResetPromptComposerAfterDelivery()
        RefreshActionButtons()

        ; The relay has finished and is no longer armed.
        ; If the scheduler window is still open, immediately return
        ; it to the same fresh state the user would see after closing
        ; and reopening it: default time + NEW SCHEDULE preview.
        UpdateDefaultTime()
        UpdatePreview()
    }
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
    global FooterText

    failedTime := FormatTime(
        A_Now,
        "h:mm:ss tt"
    )

    StatusMessage :=
        "Status: NOT ARMED — last attempt failed at "
        . failedTime

    if StatusText
    {
        StatusText.Text := StatusMessage
        RefreshStatusStyle()
    }

    A_IconTip := "Codex Relay — not armed"

    RefreshActionButtons()

    ; A failed scheduled attempt is also no longer armed, so put
    ; the open scheduler back into a fresh NEW SCHEDULE state.
    UpdateDefaultTime()
    UpdatePreview()

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
    codex := WinExist(
        "ahk_exe ChatGPT.exe"
    )

    if !codex
        return false

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

    if !WinActive(
        "ahk_id " codex
    )
    {
        return false
    }

    WinGetClientPos(
        &clientX,
        &clientY,
        &clientW,
        &clientH,
        "ahk_id " codex
    )

    ; Tested Codex prompt position.
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

    if !WinActive(
        "ahk_id " codex
    )
    {
        return false
    }

    if !PastePromptText(promptText)
        return false

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
    savedClipboard := ClipboardAll()

    A_Clipboard := ""
    A_Clipboard := text

    if !ClipWait(2)
    {
        A_Clipboard := savedClipboard
        return false
    }

    Send "^v"

    Sleep 400

    A_Clipboard := savedClipboard

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
    global FooterText

    if !IsArmed
        return

    if ScheduledCallback
        SetTimer(ScheduledCallback, 0)

    IsArmed := false

    MarkScheduleInactive()

    StatusMessage :=
        "Status: NOT ARMED — schedule cancelled"

    if StatusText
    {
        StatusText.Text := StatusMessage
        RefreshStatusStyle()
    }

    RefreshActionButtons()

    ; The schedule is no longer armed, so switch the yellow
    ; preview back from "CURRENTLY ARMED" to "NEW SCHEDULE"
    ; using the existing controls. This does not change the
    ; selected day/time/buffer values.
    UpdatePreview()

    A_IconTip := "Codex Relay — not armed"

    TrayTip(
        "Codex Relay",
        "Scheduled prompt cancelled.",
        1
    )
}


; ============================================================
; HIDE GUI
;
; Closing the GUI does NOT cancel an armed timer.
; Use Cancel to disarm it.
; ============================================================

HideScheduler(*)
{
    global SchedulerGui

    CloseAllSelectorPopups()

    if SchedulerGui
        SchedulerGui.Hide()
}
