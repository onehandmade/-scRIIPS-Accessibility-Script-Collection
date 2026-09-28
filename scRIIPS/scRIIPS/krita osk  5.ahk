#Requires AutoHotkey v2.0
#SingleInstance Force

DllCall("SetProcessDpiAwarenessContext", "ptr", -4)

; ============================================================
; Krita Art Assistant (Accessibility Edition)
; Features "Sticky Modifiers" so you don't need to press multiple 
; buttons or keys at the same time.
; ============================================================

global KeyControls := []
global RebuildPending := false
global TopBarH := 40

global HoverModeOn := false
global HoverCandidateHwnd := 0
global HoverCandidateLabel := ""
global HoverStartTick := 0
global HoverFired := false
global HoverDelayMs := 700

; Sticky modifier states
global StickyCtrl := false
global StickyShift := false
global StickyAlt := false

; ---------------- Button Layout ----------------
; Note: Simple actions instead of combos, since modifiers can be toggled first!
KeyRows := [
    ["Undo (Z)", "Redo (Y)", "Copy (C)", "Paste (V)", "Backspace"],
    ["Brush (B)", "Eraser (E)", "Picker (I)", "Fill (G)", "Select All (A)"],
    ["Size - ([)", "Size + (])", "Zoom In (+)", "Zoom Out (-)", "Reset Zoom (0)"],
    ["Mirror (M)", "Rotate Reset (R)", "Pan Canvas", "Zoom/Rotate", "Esc"]
]

; ---------------- Build GUI ----------------
KritaBar := Gui("+AlwaysOnTop +Resize -MaximizeBox +E0x08000000", "Krita Accessible Assistant")
KritaBar.BackColor := "2B2B2B"
KritaBar.SetFont("s11 Bold cWhite", "Segoe UI")
KritaBar.OnEvent("Size", OnResize)
KritaBar.OnEvent("Close", (*) => ExitApp())

; Top Control Bar & Sticky Modifiers
ctrlBtn := KritaBar.Add("Button", "x10 y6 w65 h28", "Ctrl: OFF")
ctrlBtn.OnEvent("Click", ToggleStickyCtrl)

shiftBtn := KritaBar.Add("Button", "x80 y6 w75 h28", "Shift: OFF")
shiftBtn.OnEvent("Click", ToggleStickyShift)

altBtn := KritaBar.Add("Button", "x160 y6 w65 h28", "Alt: OFF")
altBtn.OnEvent("Click", ToggleStickyAlt)

hoverBtn := KritaBar.Add("Button", "x235 y6 w130 h28", "Hover: Off")
hoverBtn.OnEvent("Click", ToggleHoverMode)

snapBtn := KritaBar.Add("Button", "x375 y6 w120 h28", "Snap Bottom")
snapBtn.OnEvent("Click", SnapToBottom)

; Initial Placement Near Bottom of Screen
MonitorGetWorkArea(, &waLeft, &waTop, &waRight, &waBottom)
screenW := waRight - waLeft
initW := Round(screenW * 0.55)
initH := 215
initX := waLeft + Round((screenW - initW) / 2)
initY := waBottom - initH - 15

KritaBar.Show(Format("x{} y{} w{} h{}", initX, initY, initW, initH))
WinSetTransparent(245, KritaBar)

BuildKeys()

; ---------------- Layout & Resize Logic ----------------

OnResize(GuiObj, MinMax, Width, Height) {
    global RebuildPending
    if (MinMax = -1)
        return
    if (MinMax = 1) {
        WinRestore(GuiObj.Hwnd)
        return
    }
    if (RebuildPending)
        return
    RebuildPending := true
    SetTimer(DoRebuild, -120)
}

SnapToBottom(*) {
    global KritaBar
    MonitorGetWorkArea(, &waLeft, &waTop, &waRight, &waBottom)
    KritaBar.GetPos(, , , &curH)
    KritaBar.Move(, waBottom - curH)
}

DoRebuild() {
    global RebuildPending
    RebuildPending := false
    BuildKeys()
}

BuildKeys() {
    global KeyControls, KeyRows, KritaBar, TopBarH

    for ctrl in KeyControls {
        try ctrl.Destroy()
    }
    KeyControls := []

    KritaBar.GetClientPos(, , &clientW, &clientH)
    if (clientW < 100 || clientH < 100)
        return

    marginX := 10
    marginY := 10
    gap := 6
    topOffset := TopBarH + marginY

    numRows := KeyRows.Length
    availH := clientH - topOffset - marginY
    rowH := (availH - gap * (numRows - 1)) / numRows

    for rowIndex, rowItems in KeyRows {
        numCols := rowItems.Length
        rowW := clientW - marginX * 2
        keyW := (rowW - gap * (numCols - 1)) / numCols
        yPos := topOffset + (rowIndex - 1) * (rowH + gap)

        for colIndex, label in rowItems {
            xPos := marginX + (colIndex - 1) * (keyW + gap)
            btn := KritaBar.Add("Button", Format("x{} y{} w{} h{}", Round(xPos), Round(yPos), Round(keyW), Round(rowH)), label)
            btn.OnEvent("Click", MakeClickHandler(label))
            KeyControls.Push(btn)
        }
    }
}

; ---------------- Sticky Modifiers Logic ----------------

ToggleStickyCtrl(btn, *) {
    global StickyCtrl
    StickyCtrl := !StickyCtrl
    btn.Text := StickyCtrl ? "Ctrl: ON" : "Ctrl: OFF"
    if (StickyCtrl)
        btn.Opt("cLime")
    else
        btn.Opt("cWhite")
}

ToggleStickyShift(btn, *) {
    global StickyShift
    StickyShift := !StickyShift
    btn.Text := StickyShift ? "Shift: ON" : "Shift: OFF"
    if (StickyShift)
        btn.Opt("cLime")
    else
        btn.Opt("cWhite")
}

ToggleStickyAlt(btn, *) {
    global StickyAlt
    StickyAlt := !StickyAlt
    btn.Text := StickyAlt ? "Alt: ON" : "Alt: OFF"
    if (StickyAlt)
        btn.Opt("cLime")
    else
        btn.Opt("cWhite")
}

ResetStickyModifiers() {
    global StickyCtrl, StickyShift, StickyAlt, ctrlBtn, shiftBtn, altBtn
    if (StickyCtrl) {
        StickyCtrl := false
        ctrlBtn.Text := "Ctrl: OFF"
        ctrlBtn.Opt("cWhite")
    }
    if (StickyShift) {
        StickyShift := false
        shiftBtn.Text := "Shift: OFF"
        shiftBtn.Opt("cWhite")
    }
    if (StickyAlt) {
        StickyAlt := false
        altBtn.Text := "Alt: OFF"
        altBtn.Opt("cWhite")
    }
}

; ---------------- Command Dispatcher ----------------

MakeClickHandler(label) {
    return SendKritaCommand.Bind(label)
}

SendKritaCommand(label, *) {
    global StickyCtrl, StickyShift, StickyAlt

    ; Build modifier prefix string for SendInput
    prefix := ""
    if (StickyCtrl)
        prefix .= "^"
    if (StickyShift)
        prefix .= "+"
    if (StickyAlt)
        prefix .= "!"

    switch label {
        case "Undo (Z)":
            Send(prefix . "z")
        case "Redo (Y)":
            Send(prefix . "y")
        case "Copy (C)":
            Send(prefix . "c")
        case "Paste (V)":
            Send(prefix . "v")
        case "Select All (A)":
            Send(prefix . "a")
        case "Backspace":
            Send(prefix . "{BackSpace}")
        case "Brush (B)":
            Send(prefix . "b")
        case "Eraser (E)":
            Send(prefix . "e")
        case "Picker (I)":
            Send(prefix . "i")
        case "Fill (G)":
            Send(prefix . "g")
        case "Size - ([)":
            Send(prefix . "[")
        case "Size + (])":
            Send(prefix . "]")
        case "Zoom In (+)":
            Send(prefix . "^{NumpadAdd}")
        case "Zoom Out (-)":
            Send(prefix . "^{NumpadSub}")
        case "Reset Zoom (0)":
            Send(prefix . "^0")
        case "Mirror (M)":
            Send(prefix . "m")
        case "Rotate Reset (R)":
            Send(prefix . "r")
        case "Esc":
            Send("{Esc}")
        case "Pan Canvas":
            ToolTip("Space locked/simulated: Drag mouse to pan canvas!")
            Send("{Space down}")
            Sleep(50)
            Send("{Space up}")
            SetTimer(() => ToolTip(), -2000)
        case "Zoom/Rotate":
            ToolTip("Shift locked/simulated: Drag mouse to zoom/rotate!")
            Send("+{LButton down}")
            Sleep(50)
            Send("+{LButton up}")
            SetTimer(() => ToolTip(), -2000)
        default:
            SendText(label)
    }

    ; Automatically reset sticky modifiers after one command is sent
    ResetStickyModifiers()
}

; ---------------- Hover Mode Support ----------------

ToggleHoverMode(ctrlObj, *) {
    global HoverModeOn, HoverCandidateHwnd, HoverFired
    HoverModeOn := !HoverModeOn
    ctrlObj.Text := HoverModeOn ? "Hover: On" : "Hover: Off"
    HoverCandidateHwnd := 0
    HoverFired := false
    if (HoverModeOn) {
        SetTimer(HoverCheck, 60)
    } else {
        SetTimer(HoverCheck, 0)
    }
}

HoverCheck() {
    global HoverModeOn, KeyControls, KritaBar
    global HoverCandidateHwnd, HoverCandidateLabel, HoverStartTick, HoverFired, HoverDelayMs

    if (!HoverModeOn)
        return

    MouseGetPos(, , &winUnderMouse, &ctrlHwndUnderMouse, 2)

    if (winUnderMouse != KritaBar.Hwnd) {
        HoverCandidateHwnd := 0
        HoverFired := false
        return
    }

    matchedLabel := ""
    for btn in KeyControls {
        if (btn.Hwnd = ctrlHwndUnderMouse) {
            matchedLabel := btn.Text
            break
        }
    }

    if (matchedLabel = "") {
        HoverCandidateHwnd := 0
        HoverFired := false
        return
    }

    if (ctrlHwndUnderMouse != HoverCandidateHwnd) {
        HoverCandidateHwnd := ctrlHwndUnderMouse
        HoverCandidateLabel := matchedLabel
        HoverStartTick := A_TickCount
        HoverFired := false
        return
    }

    if (!HoverFired && (A_TickCount - HoverStartTick >= HoverDelayMs)) {
        HoverFired := true
        SendKritaCommand(HoverCandidateLabel)
    }
}