#Requires AutoHotkey v2.0
#SingleInstance Force

; ============================================================
; OSK Maker - design your own on-screen keyboard, then export it
; as a standalone .ahk script or a compiled .exe.
;
;   Key types:
;     Text = types the action text exactly as written (symbols, words)
;     Send = AutoHotkey Send syntax: z   ^c   {BackSpace}   {Esc}
;            (the Ctrl / Shift / Alt sticky buttons apply to Send keys)
;     Hold = press-and-hold toggle, e.g. Space or Ctrl+Space.
;            Press once to hold, press again to release. Held keys are
;            always released when the keyboard closes.
;
;   Command line (optional):
;     OSK_Maker.ahk /build layout.osk out.ahk
;     OSK_Maker.ahk /preset math|krita out.ahk
; ============================================================

DllCall("SetProcessDpiAwarenessContext", "ptr", -4)

global Keys := []
global Settings := Map()

global G := "", LV := "", presetDD := ""
global edRow := "", edLabel := "", ddType := "", edAction := ""
global edTitle := "", edBg := "", edFont := "", edTrans := ""
global edWidth := "", edHeight := "", edHoverMs := ""
global chkSticky := "", chkHoverBtn := "", statusTxt := ""

SetDefaults()

if (A_Args.Length >= 1 && StrLower(A_Args[1]) = "/build" && A_Args.Length >= 3) {
    RunCliBuild(A_Args[2], A_Args[3])
    ExitApp()
}
if (A_Args.Length >= 1 && StrLower(A_Args[1]) = "/preset" && A_Args.Length >= 3) {
    if (StrLower(A_Args[2]) = "math")
        PresetMath()
    else
        PresetKrita()
    text := BuildScriptText(true)
    if (text != "")
        WriteTextFile(A_Args[3], text)
    ExitApp()
}

BuildEditor()

; ============================================================
; Editor window
; ============================================================
BuildEditor() {
    global G, LV, presetDD, edRow, edLabel, ddType, edAction
    global edTitle, edBg, edFont, edTrans, edWidth, edHeight, edHoverMs
    global chkSticky, chkHoverBtn, statusTxt

    G := Gui("+Resize", "OSK Maker - On-Screen Keyboard Builder")
    G.SetFont("s10", "Segoe UI")
    G.OnEvent("Close", (*) => ExitApp())

    G.Add("Text", "x10 y14 w50", "Preset:")
    presetDD := G.Add("DropDownList", "x62 y10 w170 Choose1", ["Blank", "Math keyboard", "Krita / drawing"])
    btnPreset := G.Add("Button", "x240 y9 w110 h26", "Load Preset")
    btnOpen := G.Add("Button", "x360 y9 w130 h26", "Open Layout...")
    btnSave := G.Add("Button", "x498 y9 w130 h26", "Save Layout...")
    btnPreset.OnEvent("Click", LoadPreset)
    btnOpen.OnEvent("Click", OpenLayout)
    btnSave.OnEvent("Click", SaveLayout)

    LV := G.Add("ListView", "x10 y46 w720 r11 -Multi Grid", ["#", "Row", "Label", "Type", "Action"])
    LV.ModifyCol(1, 40)
    LV.ModifyCol(2, 50)
    LV.ModifyCol(3, 200)
    LV.ModifyCol(4, 70)
    LV.ModifyCol(5, 330)
    LV.OnEvent("ItemSelect", OnLVSelect)

    G.Add("Text", "xm y+12 w40", "Row:")
    edRow := G.Add("Edit", "x+2 yp-3 w50 Number", "1")
    G.Add("UpDown", "Range1-30", 1)
    G.Add("Text", "x+14 yp+3 w50", "Label:")
    edLabel := G.Add("Edit", "x+2 yp-3 w130")
    G.Add("Text", "x+14 yp+3 w42", "Type:")
    ddType := G.Add("DropDownList", "x+2 yp-3 w75 Choose1", ["Text", "Send", "Hold"])
    G.Add("Text", "x+14 yp+3 w52", "Action:")
    edAction := G.Add("Edit", "x+2 yp-3 w200")

    btnAdd := G.Add("Button", "xm y+10 w110 h28", "Add Key")
    btnUpd := G.Add("Button", "x+6 yp w140 h28", "Update Selected")
    btnDel := G.Add("Button", "x+6 yp w100 h28", "Delete")
    btnUp := G.Add("Button", "x+6 yp w70 h28", "Up")
    btnDn := G.Add("Button", "x+6 yp w70 h28", "Down")
    btnAdd.OnEvent("Click", AddKey)
    btnUpd.OnEvent("Click", UpdateKey)
    btnDel.OnEvent("Click", DeleteKey)
    btnUp.OnEvent("Click", MoveKey.Bind(-1))
    btnDn.OnEvent("Click", MoveKey.Bind(1))

    G.Add("Text", "xm y+8 w720 h54", "Text = types the action text as written.   Send = AutoHotkey Send syntax (z, ^c, {BackSpace}); the sticky Ctrl/Shift/Alt buttons apply to Send keys.   Hold = press-and-hold toggle such as Space or Ctrl+Space (released when pressed again, or when the keyboard closes).   Keys with the same Row number share a row.")

    G.Add("GroupBox", "xm y+6 w720 h112", "Keyboard settings")
    G.Add("Text", "xp+12 yp+26 w45", "Title:")
    edTitle := G.Add("Edit", "x+2 yp-3 w220")
    G.Add("Text", "x+14 yp+3 w95", "Background:")
    edBg := G.Add("Edit", "x+2 yp-3 w70")
    G.Add("Text", "x+14 yp+3 w70", "Font size:")
    edFont := G.Add("Edit", "x+2 yp-3 w45 Number")
    G.Add("Text", "x+14 yp+3 w90", "Opacity (30-255):")
    edTrans := G.Add("Edit", "x+2 yp-3 w50 Number")

    G.Add("Text", "xm+12 y+16 w70", "Width %:")
    edWidth := G.Add("Edit", "x+2 yp-3 w50 Number")
    G.Add("Text", "x+14 yp+3 w90", "Height (px):")
    edHeight := G.Add("Edit", "x+2 yp-3 w60 Number")
    G.Add("Text", "x+14 yp+3 w110", "Hover delay (ms):")
    edHoverMs := G.Add("Edit", "x+2 yp-3 w60 Number")
    chkSticky := G.Add("Checkbox", "x+16 yp+3 w150", "Sticky Ctrl/Shift/Alt")
    chkHoverBtn := G.Add("Checkbox", "x+6 yp w110", "Hover button")

    btnPrev := G.Add("Button", "xm y+22 w120 h32", "Preview")
    btnAhk := G.Add("Button", "x+8 yp w160 h32", "Generate .ahk...")
    btnExe := G.Add("Button", "x+8 yp w160 h32", "Generate .exe...")
    btnPrev.OnEvent("Click", PreviewKeyboard)
    btnAhk.OnEvent("Click", GenerateAhk)
    btnExe.OnEvent("Click", GenerateExe)

    statusTxt := G.Add("Text", "xm y+10 w720", "Load a preset or add your first key.")

    WriteSettingsToControls()
    RefreshLV()
    G.Show()
}

SetStatus(msg) {
    global statusTxt
    if (statusTxt != "")
        statusTxt.Text := msg
}

; ============================================================
; Settings
; ============================================================
SetDefaults() {
    global Settings
    Settings := Map("title", "My On-Screen Keyboard", "bg", "1E1E1E", "fontSize", 14, "trans", 235, "widthPct", 60, "height", 200, "hoverDelay", 700, "sticky", 0, "hoverBtn", 1)
}

ClampInt(text, lo, hi, def) {
    t := Trim(text)
    if !IsInteger(t)
        return def
    v := Integer(t)
    return Max(lo, Min(hi, v))
}

ReadSettings() {
    global Settings, edTitle, edBg, edFont, edTrans, edWidth, edHeight, edHoverMs, chkSticky, chkHoverBtn
    title := Trim(edTitle.Text)
    if (title = "")
        title := "On-Screen Keyboard"
    bg := Trim(edBg.Text)
    if !RegExMatch(bg, "^[0-9A-Fa-f]{6}$") {
        MsgBox("Background must be a 6-digit hex color, for example 1E1E1E.", "OSK Maker", "Icon!")
        return false
    }
    Settings["title"] := title
    Settings["bg"] := bg
    Settings["fontSize"] := ClampInt(edFont.Text, 6, 48, 14)
    Settings["trans"] := ClampInt(edTrans.Text, 30, 255, 235)
    Settings["widthPct"] := ClampInt(edWidth.Text, 10, 100, 60)
    Settings["height"] := ClampInt(edHeight.Text, 80, 1200, 200)
    Settings["hoverDelay"] := ClampInt(edHoverMs.Text, 100, 5000, 700)
    Settings["sticky"] := chkSticky.Value ? 1 : 0
    Settings["hoverBtn"] := chkHoverBtn.Value ? 1 : 0
    WriteSettingsToControls()
    return true
}

WriteSettingsToControls() {
    global Settings, edTitle, edBg, edFont, edTrans, edWidth, edHeight, edHoverMs, chkSticky, chkHoverBtn
    if (edTitle = "")
        return
    edTitle.Text := Settings["title"]
    edBg.Text := Settings["bg"]
    edFont.Text := Settings["fontSize"]
    edTrans.Text := Settings["trans"]
    edWidth.Text := Settings["widthPct"]
    edHeight.Text := Settings["height"]
    edHoverMs.Text := Settings["hoverDelay"]
    chkSticky.Value := Settings["sticky"] ? 1 : 0
    chkHoverBtn.Value := Settings["hoverBtn"] ? 1 : 0
}

; ============================================================
; Key list editing
; ============================================================
RefreshLV(selIdx := 0) {
    global Keys, LV
    LV.Delete()
    for i, k in Keys
        LV.Add("", i, k["row"], k["label"], k["type"], k["action"])
    if (selIdx >= 1 && selIdx <= Keys.Length)
        LV.Modify(selIdx, "Select Focus Vis")
}

GetSelectedIdx() {
    global LV
    return LV.GetNext(0)
}

OnLVSelect(ctrl, item, selected) {
    global Keys, edRow, edLabel, ddType, edAction
    if (!selected || item < 1 || item > Keys.Length)
        return
    k := Keys[item]
    edRow.Text := k["row"]
    edLabel.Text := k["label"]
    ddType.Choose(k["type"])
    edAction.Text := k["action"]
}

ReadKeyFields() {
    global edRow, edLabel, ddType, edAction
    label := StrReplace(edLabel.Text, "`t", " ")
    action := StrReplace(edAction.Text, "`t", " ")
    type := ddType.Text
    rowNum := IsInteger(edRow.Text) ? Integer(edRow.Text) : 1
    if (rowNum < 1)
        rowNum := 1
    if (label = "") {
        MsgBox("Give the key a label first.", "OSK Maker", "Icon!")
        return 0
    }
    if (action = "") {
        if (type = "Text") {
            action := label
        } else {
            MsgBox("Send and Hold keys need an Action.", "OSK Maker", "Icon!")
            return 0
        }
    }
    return Map("row", rowNum, "label", label, "type", type, "action", action)
}

AddKey(*) {
    global Keys
    k := ReadKeyFields()
    if (!IsObject(k))
        return
    Keys.Push(k)
    RefreshLV(Keys.Length)
    SetStatus("Added key '" . k["label"] . "'.")
}

UpdateKey(*) {
    global Keys
    idx := GetSelectedIdx()
    if (!idx) {
        SetStatus("Select a key in the list first.")
        return
    }
    k := ReadKeyFields()
    if (!IsObject(k))
        return
    Keys[idx] := k
    RefreshLV(idx)
    SetStatus("Updated key '" . k["label"] . "'.")
}

DeleteKey(*) {
    global Keys
    idx := GetSelectedIdx()
    if (!idx) {
        SetStatus("Select a key in the list first.")
        return
    }
    Keys.RemoveAt(idx)
    RefreshLV(Min(idx, Keys.Length))
    SetStatus("Key deleted.")
}

MoveKey(dir, *) {
    global Keys
    idx := GetSelectedIdx()
    if (!idx)
        return
    j := idx + dir
    if (j < 1 || j > Keys.Length)
        return
    tmp := Keys[idx]
    Keys[idx] := Keys[j]
    Keys[j] := tmp
    RefreshLV(j)
}

; ============================================================
; Presets (based on the Math and Krita keyboards)
; ============================================================
LoadPreset(*) {
    global presetDD, Keys
    if (Keys.Length > 0) {
        if (MsgBox("Replace the current layout with the preset?", "OSK Maker", "YesNo Icon?") != "Yes")
            return
    }
    choice := presetDD.Value
    if (choice = 2) {
        PresetMath()
    } else if (choice = 3) {
        PresetKrita()
    } else {
        Keys := []
        SetDefaults()
    }
    WriteSettingsToControls()
    RefreshLV()
    SetStatus("Preset loaded.")
}

PresetMath() {
    global Keys, Settings
    SetDefaults()
    Settings["title"] := "Math On-Screen Keyboard"
    Settings["bg"] := "1E1E1E"
    Settings["fontSize"] := 14
    Settings["trans"] := 235
    Settings["widthPct"] := 60
    Settings["height"] := 200
    Settings["sticky"] := 0
    rows := [
        ["7", "8", "9", "/", "(", ")", "√", "⌫"],
        ["4", "5", "6", "*", "^", "x²", "x³", "π"],
        ["1", "2", "3", "-", "=", "≠", "≈", "∞"],
        ["0", ".", ",", "+", "±", "<", ">", "≤", "≥"],
        ["%", "!", "°", "∑", "∫", "θ", "α", "␣"]
    ]
    Keys := []
    for r, items in rows {
        for lbl in items {
            if (lbl = "⌫")
                Keys.Push(Map("row", r, "label", lbl, "type", "Send", "action", "{BackSpace}"))
            else if (lbl = "␣")
                Keys.Push(Map("row", r, "label", lbl, "type", "Send", "action", "{Space}"))
            else
                Keys.Push(Map("row", r, "label", lbl, "type", "Text", "action", lbl))
        }
    }
}

PresetKrita() {
    global Keys, Settings
    SetDefaults()
    Settings["title"] := "Krita Accessible Assistant"
    Settings["bg"] := "2B2B2B"
    Settings["fontSize"] := 11
    Settings["trans"] := 245
    Settings["widthPct"] := 55
    Settings["height"] := 215
    Settings["sticky"] := 1
    rows := [
        [["Undo (Z)", "Send", "z"], ["Redo (Y)", "Send", "y"], ["Copy (C)", "Send", "c"], ["Paste (V)", "Send", "v"], ["Backspace", "Send", "{BackSpace}"]],
        [["Brush (B)", "Send", "b"], ["Eraser (E)", "Send", "e"], ["Picker (I)", "Send", "i"], ["Fill (G)", "Send", "g"], ["Select All (A)", "Send", "a"]],
        [["Size - ([)", "Send", "["], ["Size + (])", "Send", "]"], ["Zoom In (+)", "Send", "^{NumpadAdd}"], ["Zoom Out (-)", "Send", "^{NumpadSub}"], ["Reset Zoom (0)", "Send", "^0"]],
        [["Mirror (M)", "Send", "m"], ["Rotate Reset (R)", "Send", "r"], ["Pan Canvas", "Hold", "Space"], ["Zoom Drag", "Hold", "Ctrl+Space"], ["Rotate Drag", "Hold", "Shift+Space"], ["Esc", "Send", "{Esc}"]]
    ]
    Keys := []
    for r, items in rows {
        for spec in items
            Keys.Push(Map("row", r, "label", spec[1], "type", spec[2], "action", spec[3]))
    }
}

; ============================================================
; Layout files (.osk) - simple tab-separated text
; ============================================================
SaveLayout(*) {
    global Keys, Settings
    if (!ReadSettings())
        return
    path := FileSelect("S16", A_ScriptDir . "\layout.osk", "Save layout", "OSK layout (*.osk)")
    if (path = "")
        return
    if !RegExMatch(path, "i)\.osk$")
        path .= ".osk"
    text := "OSKLAYOUT`t1`n"
    for name, val in Settings
        text .= "SET`t" . name . "`t" . val . "`n"
    for k in Keys
        text .= "KEY`t" . k["row"] . "`t" . k["type"] . "`t" . k["label"] . "`t" . k["action"] . "`n"
    if WriteTextFile(path, text)
        SetStatus("Layout saved: " . path)
}

OpenLayout(*) {
    path := FileSelect(3, A_ScriptDir, "Open layout", "OSK layout (*.osk)")
    if (path = "")
        return
    if LoadLayoutFile(path) {
        WriteSettingsToControls()
        RefreshLV()
        SetStatus("Layout loaded: " . path)
    }
}

LoadLayoutFile(path) {
    global Keys, Settings
    try {
        text := FileRead(path, "UTF-8")
    } catch {
        MsgBox("Could not read " . path, "OSK Maker", "Icon!")
        return false
    }
    lines := StrSplit(text, "`n", "`r")
    if (lines.Length = 0 || SubStr(lines[1], 1, 10) != "OSKLAYOUT") {
        MsgBox("This is not an OSK layout file.", "OSK Maker", "Icon!")
        return false
    }
    newKeys := []
    newSet := Map()
    for line in lines {
        if (line = "")
            continue
        p := StrSplit(line, "`t")
        if (p[1] = "SET" && p.Length >= 3) {
            newSet[p[2]] := p[3]
        } else if (p[1] = "KEY" && p.Length >= 5) {
            rowNum := IsInteger(p[2]) ? Integer(p[2]) : 1
            newKeys.Push(Map("row", rowNum, "type", p[3], "label", p[4], "action", p[5]))
        }
    }
    SetDefaults()
    for name, val in newSet
        Settings[name] := val
    Keys := newKeys
    return true
}

WriteTextFile(path, text) {
    try FileDelete(path)
    try {
        FileAppend(text, path, "UTF-8-RAW")
        return true
    } catch {
        MsgBox("Could not write " . path, "OSK Maker", "Icon!")
        return false
    }
}

RunCliBuild(layoutPath, outPath) {
    global Keys
    if !LoadLayoutFile(layoutPath)
        return
    text := BuildScriptText(true)
    if (text != "")
        WriteTextFile(outPath, text)
}

; ============================================================
; Script generation
; ============================================================
EscAhk(s) {
    s := StrReplace(s, "``", "````")
    s := StrReplace(s, '"', '``"')
    return s
}

Q(s) {
    return '"' . EscAhk(s) . '"'
}

BuildScriptText(skipControls := false) {
    global Keys, Settings
    if (Keys.Length = 0) {
        MsgBox("Add at least one key first.", "OSK Maker", "Icon!")
        return ""
    }
    if (!skipControls && !ReadSettings())
        return ""

    ; Collect distinct row numbers, sorted ascending
    rowNums := []
    for k in Keys {
        found := false
        for n in rowNums {
            if (n = k["row"])
                found := true
        }
        if (!found)
            rowNums.Push(k["row"])
    }
    total := rowNums.Length
    pass := 1
    while (pass < total) {
        j := 1
        while (j <= total - pass) {
            if (rowNums[j] > rowNums[j + 1]) {
                tmp := rowNums[j]
                rowNums[j] := rowNums[j + 1]
                rowNums[j + 1] := tmp
            }
            j += 1
        }
        pass += 1
    }

    out := "#Requires AutoHotkey v2.0`n#SingleInstance Force`n`n"
    out .= "; Generated by OSK Maker. Edit the values and KeyRows below if you like.`n"
    out .= "global OSK_Title := " . Q(Settings["title"]) . "`n"
    out .= "global OSK_BgColor := " . Q(Settings["bg"]) . "`n"
    out .= "global OSK_FontSize := " . Integer(Settings["fontSize"]) . "`n"
    out .= "global OSK_Trans := " . Integer(Settings["trans"]) . "`n"
    out .= "global OSK_WidthPct := " . Integer(Settings["widthPct"]) . "`n"
    out .= "global OSK_Height := " . Integer(Settings["height"]) . "`n"
    out .= "global OSK_HoverDelay := " . Integer(Settings["hoverDelay"]) . "`n"
    out .= "global OSK_Sticky := " . (Integer(Settings["sticky"]) ? "true" : "false") . "`n"
    out .= "global OSK_HoverBtn := " . (Integer(Settings["hoverBtn"]) ? "true" : "false") . "`n`n"

    out .= "global KeyRows := [`n"
    rowTexts := []
    for rn in rowNums {
        pieces := []
        for k in Keys {
            if (k["row"] != rn)
                continue
            pieces.Push("        Map(" . Q("label") . ", " . Q(k["label"]) . ", " . Q("type") . ", " . Q(k["type"]) . ", " . Q("action") . ", " . Q(k["action"]) . ")")
        }
        rowTexts.Push("    [`n" . JoinList(pieces, ",`n") . "`n    ]")
    }
    out .= JoinList(rowTexts, ",`n") . "`n]`n`n"

    for line in GetTemplateLines()
        out .= line . "`n"
    return out
}

JoinList(arr, sep) {
    result := ""
    for i, v in arr
        result .= (i = 1 ? "" : sep) . v
    return result
}

; ============================================================
; Preview / export
; ============================================================
FindAhkExe() {
    candidates := [A_AhkPath, A_ProgramFiles . "\AutoHotkey\v2\AutoHotkey64.exe", A_ProgramFiles . "\AutoHotkey\v2\AutoHotkey32.exe", EnvGet("LOCALAPPDATA") . "\Programs\AutoHotkey\v2\AutoHotkey64.exe"]
    for c in candidates {
        if (c != "" && FileExist(c))
            return c
    }
    return ""
}

FindCompiler() {
    ahkDir := ""
    if (A_AhkPath != "")
        SplitPath(A_AhkPath, , &ahkDir)
    candidates := [A_ProgramFiles . "\AutoHotkey\Compiler\Ahk2Exe.exe", EnvGet("LOCALAPPDATA") . "\Programs\AutoHotkey\Compiler\Ahk2Exe.exe"]
    if (ahkDir != "")
        candidates.Push(ahkDir . "\..\Compiler\Ahk2Exe.exe")
    for c in candidates {
        if FileExist(c)
            return c
    }
    return ""
}

PreviewKeyboard(*) {
    text := BuildScriptText()
    if (text = "")
        return
    ahk := FindAhkExe()
    if (ahk = "") {
        MsgBox("AutoHotkey v2 was not found, so the preview cannot start.", "OSK Maker", "Icon!")
        return
    }
    path := A_Temp . "\osk_maker_preview.ahk"
    if !WriteTextFile(path, text)
        return
    Run('"' . ahk . '" "' . path . '"')
    SetStatus("Preview started. Close the keyboard window to stop it.")
}

GenerateAhk(*) {
    text := BuildScriptText()
    if (text = "")
        return
    path := FileSelect("S16", A_ScriptDir . "\my_keyboard.ahk", "Save keyboard script", "AutoHotkey script (*.ahk)")
    if (path = "")
        return
    if !RegExMatch(path, "i)\.ahk$")
        path .= ".ahk"
    if WriteTextFile(path, text)
        SetStatus("Saved: " . path)
}

GenerateExe(*) {
    text := BuildScriptText()
    if (text = "")
        return
    compiler := FindCompiler()
    base := FindAhkExe()
    if (compiler = "" || base = "") {
        MsgBox("Ahk2Exe (the AutoHotkey compiler) was not found.`n`nInstall AutoHotkey v2 with the compiler option, or use 'Generate .ahk' and compile that file yourself.", "OSK Maker", "Icon!")
        return
    }
    exePath := FileSelect("S16", A_ScriptDir . "\my_keyboard.exe", "Save keyboard program", "Program (*.exe)")
    if (exePath = "")
        return
    if !RegExMatch(exePath, "i)\.exe$")
        exePath .= ".exe"
    srcPath := A_Temp . "\osk_maker_build.ahk"
    if !WriteTextFile(srcPath, text)
        return
    SetStatus("Compiling...")
    try FileDelete(exePath)
    try {
        RunWait('"' . compiler . '" /in "' . srcPath . '" /out "' . exePath . '" /base "' . base . '"', , "Hide")
    } catch as err {
        MsgBox("The compiler could not be started: " . err.Message, "OSK Maker", "Icon!")
        return
    }
    if FileExist(exePath)
        SetStatus("Compiled: " . exePath)
    else
        MsgBox("Compiling did not produce an .exe. Try 'Generate .ahk' and compile it with Ahk2Exe manually.", "OSK Maker", "Icon!")
}

; ============================================================
; Keyboard engine template (written into every generated script)
; ============================================================
GetTemplateLines() {
    return [
        '; ============================================================',
        '; On-screen keyboard engine (generated by OSK Maker)',
        '; The window never takes focus (WS_EX_NOACTIVATE), so the app you',
        '; are typing into keeps focus and receives the keys directly.',
        '; ============================================================',
        'DllCall("SetProcessDpiAwarenessContext", "ptr", -4)',
        '',
        'global KeyControls := []',
        'global KeyMap := Map()',
        'global ModMap := Map()',
        'global ModButtons := Map()',
        'global StickyOn := Map("Ctrl", false, "Shift", false, "Alt", false)',
        'global HeldKeys := Map()',
        'global TopBarH := 40',
        'global TopX := 10',
        'global HoverModeOn := false',
        'global HoverCandidateHwnd := 0',
        'global HoverStartTick := 0',
        'global HoverFired := false',
        'global HoverEntry := 0',
        '',
        'OnExit(OnScriptExit)',
        '',
        'OSK := Gui("+AlwaysOnTop +Resize -MaximizeBox +E0x08000000", OSK_Title)',
        'OSK.BackColor := OSK_BgColor',
        'OSK.OnEvent("Size", OnResize)',
        'OSK.OnEvent("Close", (*) => ExitApp())',
        '',
        '; ---- Top bar ----',
        'OSK.SetFont("s10 Bold cWhite", "Segoe UI")',
        'AddTopButton("Snap Bottom", 105, SnapToBottom)',
        'AddTopButton("Snap Top", 85, SnapToTop)',
        'if (OSK_HoverBtn)',
        '    AddTopButton("Hover: Off", 100, ToggleHoverMode)',
        'if (OSK_Sticky) {',
        '    for modName in ["Ctrl", "Shift", "Alt"] {',
        '        modBtn := AddTopButton(modName . ": OFF", 85, ToggleSticky.Bind(modName))',
        '        ModButtons[modName] := modBtn',
        '        ModMap[modBtn.Hwnd] := Map("name", modName, "btn", modBtn)',
        '    }',
        '}',
        'if (HasHoldKeys())',
        '    AddTopButton("Release Held", 115, OnReleaseClick)',
        '',
        '; ---- Initial size and position ----',
        'MonitorGetWorkArea(, &waLeft, &waTop, &waRight, &waBottom)',
        'screenW := waRight - waLeft',
        'initW := Round(screenW * OSK_WidthPct / 100)',
        'initH := OSK_Height',
        'initX := waLeft + Round((screenW - initW) / 2)',
        'initY := waBottom - initH - 10',
        'OSK.Show(Format("x{} y{} w{} h{}", initX, initY, initW, initH))',
        'WinSetTransparent(OSK_Trans, OSK)',
        '',
        'CreateKeys()',
        'LayoutKeys()',
        '',
        '; ---------------- Helpers ----------------',
        '',
        'AddTopButton(text, w, handler) {',
        '    global OSK, TopX',
        '    btn := OSK.Add("Button", Format("x{} y6 w{} h28", TopX, w), text)',
        '    btn.OnEvent("Click", handler)',
        '    TopX += w + 6',
        '    return btn',
        '}',
        '',
        'HasHoldKeys() {',
        '    global KeyRows',
        '    for rowItems in KeyRows {',
        '        for spec in rowItems {',
        '            if (spec["type"] = "Hold")',
        '                return true',
        '        }',
        '    }',
        '    return false',
        '}',
        '',
        'LabelFor(spec) {',
        '    global HeldKeys',
        '    if (spec["type"] = "Hold" && HeldKeys.Has(spec["action"]))',
        '        return spec["label"] . " [HELD]"',
        '    return spec["label"]',
        '}',
        '',
        '; ---------------- Keys: create once, move on resize ----------------',
        '',
        'CreateKeys() {',
        '    global KeyControls, KeyMap, KeyRows, OSK, OSK_FontSize',
        '    OSK.SetFont("s" . OSK_FontSize . " Bold cWhite", "Segoe UI")',
        '    KeyControls := []',
        '    KeyMap := Map()',
        '    for rowIndex, rowItems in KeyRows {',
        '        for colIndex, spec in rowItems {',
        '            btn := OSK.Add("Button", "x0 y0 w40 h30", LabelFor(spec))',
        '            btn.OnEvent("Click", PressKey.Bind(spec, btn))',
        '            KeyControls.Push(Map("btn", btn, "row", rowIndex, "col", colIndex, "cols", rowItems.Length))',
        '            KeyMap[btn.Hwnd] := Map("spec", spec, "btn", btn)',
        '        }',
        '    }',
        '}',
        '',
        'LayoutKeys() {',
        '    global KeyControls, KeyRows, OSK, TopBarH',
        '    OSK.GetClientPos(, , &clientW, &clientH)',
        '    if (clientW < 100 || clientH < 60)',
        '        return',
        '    numRows := KeyRows.Length',
        '    if (numRows = 0)',
        '        return',
        '    marginX := 10',
        '    marginY := 10',
        '    gap := 6',
        '    topOffset := TopBarH + marginY',
        '    availH := clientH - topOffset - marginY',
        '    rowH := (availH - gap * (numRows - 1)) / numRows',
        '    if (rowH < 12)',
        '        rowH := 12',
        '    rowW := clientW - marginX * 2',
        '    for item in KeyControls {',
        '        keyW := (rowW - gap * (item["cols"] - 1)) / item["cols"]',
        '        xPos := marginX + (item["col"] - 1) * (keyW + gap)',
        '        yPos := topOffset + (item["row"] - 1) * (rowH + gap)',
        '        item["btn"].Move(Round(xPos), Round(yPos), Round(keyW), Round(rowH))',
        '    }',
        '}',
        '',
        'OnResize(GuiObj, MinMax, Width, Height) {',
        '    global OSK_WidthPct, OSK_Height',
        '    if (MinMax = -1)',
        '        return',
        '    if (MinMax = 1) {',
        '        WinRestore(GuiObj.Hwnd)',
        '        MonitorGetWorkArea(, &wl, &wt, &wr, &wb)',
        '        rw := Round((wr - wl) * OSK_WidthPct / 100)',
        '        WinMove(wl + Round(((wr - wl) - rw) / 2), wb - OSK_Height - 10, rw, OSK_Height, GuiObj.Hwnd)',
        '        return',
        '    }',
        '    LayoutKeys()',
        '}',
        '',
        'SnapToBottom(*) {',
        '    global OSK',
        '    OSK.GetPos(&curX, &curY, &curW, &curH)',
        '    MonitorGetWorkArea(, &wl, &wt, &wr, &wb)',
        '    OSK.Move(, wb - curH)',
        '}',
        '',
        'SnapToTop(*) {',
        '    global OSK',
        '    MonitorGetWorkArea(, &wl, &wt, &wr, &wb)',
        '    OSK.Move(, wt)',
        '}',
        '',
        '; ---------------- Key actions ----------------',
        '',
        'GetStickyPrefix() {',
        '    global StickyOn',
        '    prefix := ""',
        '    if (StickyOn["Ctrl"])',
        '        prefix .= "^"',
        '    if (StickyOn["Shift"])',
        '        prefix .= "+"',
        '    if (StickyOn["Alt"])',
        '        prefix .= "!"',
        '    return prefix',
        '}',
        '',
        'ResetSticky() {',
        '    global StickyOn, ModButtons',
        '    for name, btn in ModButtons {',
        '        if (StickyOn[name]) {',
        '            StickyOn[name] := false',
        '            btn.Text := name . ": OFF"',
        '        }',
        '    }',
        '}',
        '',
        'ToggleSticky(name, btn, *) {',
        '    global StickyOn',
        '    StickyOn[name] := !StickyOn[name]',
        '    btn.Text := name . (StickyOn[name] ? ": ON" : ": OFF")',
        '}',
        '',
        'PressKey(spec, btn, *) {',
        '    type := spec["type"]',
        '    if (type = "Text") {',
        '        SendText(spec["action"])',
        '    } else if (type = "Send") {',
        '        Send(GetStickyPrefix() . spec["action"])',
        '    } else if (type = "Hold") {',
        '        ToggleHold(spec, btn)',
        '    }',
        '    ResetSticky()',
        '}',
        '',
        'ToggleHold(spec, btn) {',
        '    global HeldKeys',
        '    id := spec["action"]',
        '    parts := StrSplit(id, "+")',
        '    if (HeldKeys.Has(id)) {',
        '        idx := parts.Length',
        '        while (idx >= 1) {',
        '            keyName := Trim(parts[idx])',
        '            if (keyName != "")',
        '                Send("{" . keyName . " up}")',
        '            idx -= 1',
        '        }',
        '        HeldKeys.Delete(id)',
        '    } else {',
        '        for part in parts {',
        '            keyName := Trim(part)',
        '            if (keyName != "")',
        '                Send("{" . keyName . " down}")',
        '        }',
        '        HeldKeys[id] := true',
        '    }',
        '    btn.Text := LabelFor(spec)',
        '}',
        '',
        'ReleaseHeldKeys() {',
        '    global HeldKeys',
        '    for id, state in HeldKeys.Clone() {',
        '        parts := StrSplit(id, "+")',
        '        idx := parts.Length',
        '        while (idx >= 1) {',
        '            keyName := Trim(parts[idx])',
        '            if (keyName != "")',
        '                try Send("{" . keyName . " up}")',
        '            idx -= 1',
        '        }',
        '    }',
        '    HeldKeys := Map()',
        '}',
        '',
        'OnReleaseClick(*) {',
        '    global KeyMap',
        '    ReleaseHeldKeys()',
        '    for hwnd, entry in KeyMap {',
        '        entry["btn"].Text := LabelFor(entry["spec"])',
        '    }',
        '}',
        '',
        'OnScriptExit(*) {',
        '    ReleaseHeldKeys()',
        '}',
        '',
        '; ---------------- Hover mode (dwell to click) ----------------',
        '',
        'ToggleHoverMode(ctrlObj, *) {',
        '    global HoverModeOn, HoverCandidateHwnd, HoverFired',
        '    HoverModeOn := !HoverModeOn',
        '    ctrlObj.Text := HoverModeOn ? "Hover: On" : "Hover: Off"',
        '    HoverCandidateHwnd := 0',
        '    HoverFired := false',
        '    SetTimer(HoverCheck, HoverModeOn ? 60 : 0)',
        '}',
        '',
        'HoverCheck() {',
        '    global HoverModeOn, KeyMap, ModMap, OSK, OSK_HoverDelay',
        '    global HoverCandidateHwnd, HoverStartTick, HoverFired, HoverEntry',
        '',
        '    if (!HoverModeOn)',
        '        return',
        '',
        '    MouseGetPos(, , &winUnderMouse, &ctrlHwnd, 2)',
        '',
        '    if (winUnderMouse != OSK.Hwnd) {',
        '        HoverCandidateHwnd := 0',
        '        HoverFired := false',
        '        return',
        '    }',
        '',
        '    entry := 0',
        '    if KeyMap.Has(ctrlHwnd)',
        '        entry := KeyMap[ctrlHwnd]',
        '    else if ModMap.Has(ctrlHwnd)',
        '        entry := ModMap[ctrlHwnd]',
        '',
        '    if (!IsObject(entry)) {',
        '        HoverCandidateHwnd := 0',
        '        HoverFired := false',
        '        return',
        '    }',
        '',
        '    if (ctrlHwnd != HoverCandidateHwnd) {',
        '        HoverCandidateHwnd := ctrlHwnd',
        '        HoverEntry := entry',
        '        HoverStartTick := A_TickCount',
        '        HoverFired := false',
        '        return',
        '    }',
        '',
        '    if (!HoverFired && (A_TickCount - HoverStartTick >= OSK_HoverDelay)) {',
        '        HoverFired := true',
        '        if HoverEntry.Has("spec")',
        '            PressKey(HoverEntry["spec"], HoverEntry["btn"])',
        '        else',
        '            ToggleSticky(HoverEntry["name"], HoverEntry["btn"])',
        '    }',
        '}'
    ]
}
