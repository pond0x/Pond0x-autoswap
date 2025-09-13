#SingleInstance Force
#Requires AutoHotkey v2.0

; ===================== BASE SETTINGS =====================
CoordMode "Mouse", "Screen"
SetTitleMatchMode 2

; --- Timing knobs (dashboard-adjustable) ---
global preConfirmMinMs := 1800     ; (2) Swap → wallet confirm wait (min)
global preConfirmMaxMs := 3000     ;     ... (max)
global postConfirmMinMs := 700     ; settle after confirmation (min)
global postConfirmMaxMs := 1200    ; settle after confirmation (max)
global revDelayMinMs := 500        ; (3) Reverse → next Swap delay (min)
global revDelayMaxMs := 900        ;     ... (max)
global loopCooldownMinMs := 12000  ; (1) Between round-trips (min)
global loopCooldownMaxMs := 22000  ;     ... (max)
global clickJitter := 3

; --- Session pause (“human breaks”) ---
global enableRests := true
global restEveryTrips := 30
global restMinSec := 60
global restMaxSec := 180

; --- Max trips limiter ---
global maxTripsPerRun := 0          ; 0 = unlimited

; --- Wallet detection (titles) ---
global walletWaitMaxMs := 8000
global walletTitleHints := ["Confirm Transaction","Phantom","Backpack","Solflare","OKX","Rabby","Wallet"]

; --- Capture points (screen coords) ---
global amtX := 0, amtY := 0
global swapX := 0, swapY := 0
global revX := 0, revY := 0
global wltX := 0, wltY := 0

; --- Amount typing flags & defaults (USDC↔USDT suggested) ---
global typeLegA := true
global typeLegB := true
global aMin := 0.25, aMax := 0.40
global bMin := 0.25, bMax := 0.40

; --- Logging (CSV) ---
global enableLogging := true
global logDir := A_ScriptDir "\logs"
global logFile := logDir "\pondx_autoswap_log.csv"

; --- Runtime state / HUD ---
global running := false, paused := false
global swapCount := 0
global tripsCount := 0
global lastA := "-", lastB := "-", nextETA := "-", lastDir := "A→B"
global hud := "", hudLbl := ""
global A_ThisFuncLoopID := ""

; ===================== HELPERS =====================
rand(min, max)      => Random(min, max)
randMs(min, max)    => Round(Random(min, max))
fmtAmount(v)        => Format("{:.6f}", v)

flashTip(msg, x, y) {
    ToolTip msg, x+15, y+15, 1
    SetTimer(clearTip1, -900)
}
clearTip1(*) => ToolTip(,,,1)

clickAt(x, y) {
    global clickJitter
    MouseMove x + Random(-clickJitter, clickJitter)
            , y + Random(-clickJitter, clickJitter), 10
    Send "{LButton}"
}

typeAmount(val) {
    global amtX, amtY
    clickAt(amtX, amtY)
    Send "^a"
    SendText val
}

formatCalStatus() {
    global amtX,amtY, swapX,swapY, revX,revY, wltX,wltY
    txt := "Amount: " (amtX ? "✔" : "✖")
    txt .= "   Swap: " (swapX ? "✔" : "✖")
    txt .= "   Reverse: " (revX ? "✔" : "✖")
    txt .= "   Wallet: " (wltX ? "✔" : "✖")
    return txt
}

sleepRand(minMs, maxMs) {
    Sleep randMs(minMs, maxMs)
}

; ----- Safe getters so #Warn doesn’t freak out before GUI exists -----
getVal(ctrl, def) {
    try {
        if (ctrl != "" && ctrl != 0)
            return ctrl.Value
    } catch {
    }
    return def
}
getCheck(ctrl, def) {
    try {
        if (ctrl != "" && ctrl != 0)
            return !!ctrl.Value
    } catch {
    }
    return def
}

; ----- Logging -----
ensureLog() {
    global logDir, logFile
    if !DirExist(logDir)
        DirCreate logDir
    if !FileExist(logFile) {
        header := "ts,loop_uuid,phase,leg,amount,cooldown_ms,wallet_confirmed,swaps_total,trips_total`r`n"
        FileAppend header, logFile, "UTF-8"
    }
}
logEvent(phase, leg := "", amount := "", cooldown := "", walletConfirmed := "") {
    global enableLogging, logFile, swapCount, tripsCount, A_ThisFuncLoopID
    if !enableLogging
        return
    ensureLog()
    ts := A_Now
    line := ts "," A_ThisFuncLoopID "," phase "," leg "," amount "," cooldown "," walletConfirmed "," swapCount "," tripsCount "`r`n"
    FileAppend line, logFile, "UTF-8"
}
newLoopUUID() {
    Return Format("{}-{}", A_TickCount, Random(100000,999999))
}

; ----- Wallet confirm flow -----
confirmWallet() {
    global wltX, wltY, walletWaitMaxMs, walletTitleHints, preConfirmMinMs, preConfirmMaxMs
    sleepRand(preConfirmMinMs, preConfirmMaxMs)

    ; try if wallet popup is already present
    for title in walletTitleHints {
        if WinExist(title) {
            WinRestore(title)
            WinActivate(title)
            Sleep 150
            Send "{Enter}"
            if (wltX && wltY) {
                Sleep 150
                MouseGetPos &cx, &cy
                clickAt(wltX, wltY)
                MouseMove cx, cy, 0
            }
            return true
        }
    }
    ; poll briefly for the popup
    t := A_TickCount
    while (A_TickCount - t) < walletWaitMaxMs {
        for title in walletTitleHints {
            if WinExist(title) {
                WinRestore(title)
                WinActivate(title)
                Sleep 150
                Send "{Enter}"
                if (wltX && wltY) {
                    Sleep 150
                    MouseGetPos &cx, &cy
                    clickAt(wltX, wltY)
                    MouseMove cx, cy, 0
                }
                return true
            }
        }
        Sleep 120
    }
    ; fallback
    Send "{Enter}"
    if (wltX && wltY) {
        Sleep 150
        MouseGetPos &cx, &cy
        clickAt(wltX, wltY)
        MouseMove cx, cy, 0
    }
    return false
}

; ===================== HUD (DRAGGABLE) =====================
initHud() {
    global hud, hudLbl
    if (hud)
        return
    hud := Gui("+AlwaysOnTop +Caption +ToolWindow", "Autoswap HUD")
    hud.SetFont("s9", "Segoe UI")
    hudLbl := hud.AddText("w360"
        , "Swaps: 0 | Trips: 0`nLeg A: -  |  Leg B: -`nDir: A→B`nNext: -")
    hud.Show("x10 y10")
}
updateHud() {
    global hudLbl, swapCount, tripsCount, lastA, lastB, nextETA, lastDir
    if IsSet(hudLbl) {
        hudLbl.Text := "Swaps: " swapCount " | Trips: " tripsCount
            . "`nLeg A: " lastA "  |  Leg B: " lastB
            . "`nDir: " lastDir
            . "`nNext: " nextETA
    }
}
toggleHud() {
    global hud
    if (!hud) {
        initHud()
    } else {
        try hud.Destroy()
        hud := ""
    }
}

; ===================== CONTROL PANEL =====================
global cp := ""
; amount section
global edAMin := "", edAMax := "", edBMin := "", edBMax := "", ckTypeA := "", ckTypeB := ""
; timing section
global edPreMin := "", edPreMax := "", edPostMin := "", edPostMax := ""
global edRevMin := "", edRevMax := "", edCdMin := "", edCdMax := ""
; session/rests & limits
global ckRest := "", edRestTrips := "", edRestMin := "", edRestMax := "", edMaxTrips := ""
; misc
global ckLog := "", lblCal := ""
; buttons
global btnRestNow := ""

initControlPanel() {
    global cp
    global edAMin, edAMax, edBMin, edBMax, ckTypeA, ckTypeB
    global edPreMin, edPreMax, edPostMin, edPostMax, edRevMin, edRevMax, edCdMin, edCdMax
    global ckRest, edRestTrips, edRestMin, edRestMax, edMaxTrips
    global ckLog, lblCal, btnRestNow

    cp := Gui("+AlwaysOnTop", "Pond0x Autoswap — Control Panel")
    cp.SetFont("s10", "Segoe UI")

    cp.AddText(, "Flow: A→B   then   Reverse   then   B→A (round-trip). Keep browser at 100% zoom.")

    ; ----- AMOUNTS -----
    cp.AddText("xm y+10", "Amounts per leg (typed into 'You Pay'):")
    cp.AddGroupBox("w520 h115")
    ckTypeA := cp.AddCheckbox("xp+10 yp+22", "Type before Leg A (first Swap)")
    edAMin  := cp.AddEdit("x+8 w120", aMin)
    cp.AddText("x+6 yp+3", "to")
    edAMax  := cp.AddEdit("x+6 yp-3 w120", aMax)

    ckTypeB := cp.AddCheckbox("xm y+8", "Type before Leg B (after Reverse)")
    edBMin  := cp.AddEdit("x+8 w120", bMin)
    cp.AddText("x+6 yp+3", "to")
    edBMax  := cp.AddEdit("x+6 yp-3 w120", bMax)
    ckTypeA.Value := typeLegA
    ckTypeB.Value := typeLegB

    ; ----- TIMING -----
    cp.AddText("xm y+12", "Timing (milliseconds):")
    cp.AddGroupBox("w520 h150")
    cp.AddText("xp+10 yp+24", "Wallet pop-up wait (Swap → Confirm):")
    edPreMin := cp.AddEdit("x+6 w120", preConfirmMinMs)
    cp.AddText("x+6 yp+3", "to")
    edPreMax := cp.AddEdit("x+6 yp-3 w120", preConfirmMaxMs)

    cp.AddText("xm y+10", "Post-confirm settle:")
    edPostMin := cp.AddEdit("x+6 w120", postConfirmMinMs)
    cp.AddText("x+6 yp+3", "to")
    edPostMax := cp.AddEdit("x+6 yp-3 w120", postConfirmMaxMs)

    cp.AddText("xm y+10", "Reverse → Swap delay:")
    edRevMin := cp.AddEdit("x+6 w120", revDelayMinMs)
    cp.AddText("x+6 yp+3", "to")
    edRevMax := cp.AddEdit("x+6 yp-3 w120", revDelayMaxMs)

    cp.AddText("xm y+12", "Between round-trips (cooldown):")
    cp.AddGroupBox("w520 h58")
    edCdMin := cp.AddEdit("xp+10 yp+22 w160", loopCooldownMinMs)
    cp.AddText("x+8 yp+3", "to")
    edCdMax := cp.AddEdit("x+8 yp-3 w160", loopCooldownMaxMs)

    ; ----- SESSIONS / RESTS -----
    cp.AddText("xm y+12", "Session pause & limits:")
    cp.AddGroupBox("w520 h105")
    ckRest := cp.AddCheckbox("xp+10 yp+20", "Pause after N round-trips (session)")
    ckRest.Value := enableRests
    edRestTrips := cp.AddEdit("x+6 w80", restEveryTrips)
    cp.AddText("x+10 yp+3", "Rest (sec):")
    edRestMin := cp.AddEdit("x+6 w80", restMinSec)
    cp.AddText("x+6 yp+3", "to")
    edRestMax := cp.AddEdit("x+6 yp-3 w80", restMaxSec)
    cp.AddText("xm y+8", "Max trips this run (0 = unlimited):")
    edMaxTrips := cp.AddEdit("x+6 w100", maxTripsPerRun)

    ; ----- EXTRAS -----
    cp.AddText("xm y+12", "Capture points (hover target then click the button):")
    b1 := cp.AddButton("xm y+4 w250", "Capture Amount  (Ctrl+Alt+1)")
    b2 := cp.AddButton("x+10 w250",   "Capture Swap    (Ctrl+Alt+2)")
    b3 := cp.AddButton("xm y+6 w250", "Capture Reverse (Ctrl+Alt+3)")
    b4 := cp.AddButton("x+10 w250",   "Capture Wallet  (Ctrl+Alt+4)")
    b1.OnEvent("Click", cp_capAmt)
    b2.OnEvent("Click", cp_capSwap)
    b3.OnEvent("Click", cp_capRev)
    b4.OnEvent("Click", cp_capWlt)

    cp.AddText("xm y+10", "Options:")
    ckLog := cp.AddCheckbox("x+10 yp", "Enable CSV logging")
    ckLog.Value := enableLogging
    btnRestNow := cp.AddButton("x+20 w140", "Rest now (60s)")
    btnRestNow.OnEvent("Click", cp_restNow)

    ; ----- Controls -----
    btnStart := cp.AddButton("xm y+12 w120", "Start")
    btnPause := cp.AddButton("x+10 w150", "Pause/Resume")
    btnHUD   := cp.AddButton("x+10 w120", "Toggle HUD")
    btnSave  := cp.AddButton("xm y+6 w120", "Save")
    btnClose := cp.AddButton("x+10 w120", "Close")
    btnStart.OnEvent("Click", cp_onStart)
    btnPause.OnEvent("Click", cp_onPause)
    btnHUD.OnEvent("Click", cp_onHUD)
    btnSave.OnEvent("Click", cp_onSave)
    btnClose.OnEvent("Click", cp_onClose)

    cp.AddText("xm y+8", "Calibration:")
    lblCal := cp.AddText("w520", formatCalStatus())
}

showControlPanel() {
    global cp
    if (!cp)
        initControlPanel()
    cp.Show()
}

cp_onStart(*) => startRun()
cp_onPause(*) => pauseRun()
cp_onHUD(*)   => toggleHud()
cp_onSave(*)  => cp_apply()
cp_onClose(*) {
    global cp
    try cp.Hide()
}
cp_restNow(*) {
    ToolTip "Manual rest: 60s", 10, 10, 2
    Sleep 60000
    ToolTip(,,,2)
}

; ----- robust numeric parsing & panel apply -----
parseNum(s, defVal) {
    s := "" s                      ; force to string
    s := Trim(s)
    s := StrReplace(s, " ", "")
    s := StrReplace(s, ",")        ; remove thousands
    if (InStr(s, ",") && !InStr(s, "."))    ; locale "0,25"
        s := StrReplace(s, ",", ".")
    if RegExMatch(s, "^[0-9]*\.?[0-9]+$")
        return Number(s)
    return defVal
}
parseInt(s, defVal) {
    n := Floor(parseNum(s, defVal))
    return n
}

cp_apply() {
    global typeLegA, typeLegB, aMin, aMax, bMin, bMax
    global preConfirmMinMs, preConfirmMaxMs, postConfirmMinMs, postConfirmMaxMs
    global revDelayMinMs, revDelayMaxMs, loopCooldownMinMs, loopCooldownMaxMs
    global enableRests, restEveryTrips, restMinSec, restMaxSec, maxTripsPerRun
    global enableLogging
    global edAMin, edAMax, edBMin, edBMax, ckTypeA, ckTypeB
    global edPreMin, edPreMax, edPostMin, edPostMax, edRevMin, edRevMax, edCdMin, edCdMax
    global ckRest, edRestTrips, edRestMin, edRestMax, edMaxTrips, ckLog, lblCal

    ; checkboxes (safe)
    typeLegA := getCheck(ckTypeA, typeLegA)
    typeLegB := getCheck(ckTypeB, typeLegB)

    ; amounts (safe)
    aMin := parseNum(getVal(edAMin, aMin), aMin)
    aMax := parseNum(getVal(edAMax, aMax), aMax)
    bMin := parseNum(getVal(edBMin, bMin), bMin)
    bMax := parseNum(getVal(edBMax, bMax), bMax)
    if (aMax < aMin) {
        tmp := aMin, aMin := aMax, aMax := tmp
    }
    if (bMax < bMin) {
        tmp := bMin, bMin := bMax, bMax := tmp
    }

    ; timing (safe)
    preConfirmMinMs := parseInt(getVal(edPreMin, preConfirmMinMs), preConfirmMinMs)
    preConfirmMaxMs := parseInt(getVal(edPreMax, preConfirmMaxMs), preConfirmMaxMs)
    if (preConfirmMaxMs < preConfirmMinMs) {
        tmp := preConfirmMinMs, preConfirmMinMs := preConfirmMaxMs, preConfirmMaxMs := tmp
    }

    postConfirmMinMs := parseInt(getVal(edPostMin, postConfirmMinMs), postConfirmMinMs)
    postConfirmMaxMs := parseInt(getVal(edPostMax, postConfirmMaxMs), postConfirmMaxMs)
    if (postConfirmMaxMs < postConfirmMinMs) {
        tmp := postConfirmMinMs, postConfirmMinMs := postConfirmMaxMs, postConfirmMaxMs := tmp
    }

    revDelayMinMs := parseInt(getVal(edRevMin, revDelayMinMs), revDelayMinMs)
    revDelayMaxMs := parseInt(getVal(edRevMax, revDelayMaxMs), revDelayMaxMs)
    if (revDelayMaxMs < revDelayMinMs) {
        tmp := revDelayMinMs, revDelayMinMs := revDelayMaxMs, revDelayMaxMs := tmp
    }

    loopCooldownMinMs := parseInt(getVal(edCdMin, loopCooldownMinMs), loopCooldownMinMs)
    loopCooldownMaxMs := parseInt(getVal(edCdMax, loopCooldownMaxMs), loopCooldownMaxMs)
    if (loopCooldownMaxMs < loopCooldownMinMs) {
        tmp := loopCooldownMinMs, loopCooldownMinMs := loopCooldownMaxMs, loopCooldownMaxMs := tmp
    }

    ; rests & limits (safe)
    enableRests := getCheck(ckRest, enableRests)
    restEveryTrips := parseInt(getVal(edRestTrips, restEveryTrips), restEveryTrips)
    restMinSec := parseInt(getVal(edRestMin, restMinSec), restMinSec)
    restMaxSec := parseInt(getVal(edRestMax, restMaxSec), restMaxSec)
    if (restMaxSec < restMinSec) {
        tmp := restMinSec, restMinSec := restMaxSec, restMaxSec := tmp
    }

    maxTripsPerRun := parseInt(getVal(edMaxTrips, maxTripsPerRun), maxTripsPerRun)
    if (maxTripsPerRun < 0)
        maxTripsPerRun := 0

    ; logging toggle (safe)
    enableLogging := getCheck(ckLog, enableLogging)

    ; refresh calibration label if exists
    try lblCal.Text := formatCalStatus()
}

; ----- capture-by-click buttons -----
cp_captureNextClick(&rx, &ry, label) {
    ToolTip "Hover the " label " and LEFT-CLICK to capture…", 20, 20, 3
    KeyWait "LButton"
    KeyWait "LButton", "D"
    MouseGetPos &rx, &ry
    SetTimer(clearTip3, -800)
}
clearTip3(*) => ToolTip(,,,3)

cp_capAmt(*) {
    global amtX, amtY, lblCal
    cp_captureNextClick(&amtX, &amtY, "Amount box")
    flashTip("Amount set: " amtX "," amtY, amtX, amtY)
    try lblCal.Text := formatCalStatus()
}
cp_capSwap(*) {
    global swapX, swapY, lblCal
    cp_captureNextClick(&swapX, &swapY, "Swap button")
    flashTip("Swap set: " swapX "," swapY, swapX, swapY)
    try lblCal.Text := formatCalStatus()
}
cp_capRev(*) {
    global revX, revY, lblCal
    cp_captureNextClick(&revX, &revY, "Reverse (↕) button")
    flashTip("Reverse set: " revX "," revY, revX, revY)
    try lblCal.Text := formatCalStatus()
}
cp_capWlt(*) {
    global wltX, wltY, lblCal
    cp_captureNextClick(&wltX, &wltY, "Wallet confirm")
    flashTip("Wallet set: " wltX "," wltY, wltX, wltY)
    try lblCal.Text := formatCalStatus()
}

; ===================== TRAY & HOTKEYS =====================
initTray() {
    A_TrayMenu.Delete()
    A_TrayMenu.Add("Open Control Panel (Ctrl+Alt+O)", tray_OpenCP)
    A_TrayMenu.Add("Start (Ctrl+Alt+S)", tray_Start)
    A_TrayMenu.Add("Pause/Resume (Ctrl+Alt+P)", tray_Pause)
    A_TrayMenu.Add("Toggle HUD (Ctrl+Alt+H)", tray_ToggleHUD)
    A_TrayMenu.Add("Quit (Ctrl+Alt+Q)", tray_Quit)
    A_TrayMenu.Default := "Open Control Panel (Ctrl+Alt+O)"
    A_TrayMenu.ClickCount := 2
}
tray_OpenCP(*)   => showControlPanel()
tray_Start(*)    => startRun()
tray_Pause(*)    => pauseRun()
tray_ToggleHUD(*)=> toggleHud()
tray_Quit(*) {
    global running
    running := false
    ToolTip(,,,2)
    ExitApp()
}

; --- Keyboard shortcuts ---
^!1:: {
    global amtX, amtY, lblCal
    MouseGetPos &amtX, &amtY
    flashTip("Amount set: " amtX "," amtY, amtX, amtY)
    try lblCal.Text := formatCalStatus()
}
^!2:: {
    global swapX, swapY, lblCal
    MouseGetPos &swapX, &swapY
    flashTip("Swap set: " swapX "," swapY, swapX, swapY)
    try lblCal.Text := formatCalStatus()
}
^!3:: {
    global revX, revY, lblCal
    MouseGetPos &revX, &revY
    flashTip("Reverse set: " revX "," revY, revX, revY)
    try lblCal.Text := formatCalStatus()
}
^!4:: {
    global wltX, wltY, lblCal
    MouseGetPos &wltX, &wltY
    flashTip("Wallet set: " wltX "," wltY, wltX, wltY)
    try lblCal.Text := formatCalStatus()
}
^!S:: startRun()
^!P:: pauseRun()
^!H:: toggleHud()
^!O:: showControlPanel()
^!Q:: tray_Quit()

; ===================== MAIN LOOP =====================
startRun() {
    global amtX,amtY, swapX,swapY, revX,revY
    global typeLegA, typeLegB, aMin,aMax, bMin,bMax
    global preConfirmMinMs, preConfirmMaxMs, postConfirmMinMs, postConfirmMaxMs
    global revDelayMinMs, revDelayMaxMs, loopCooldownMinMs, loopCooldownMaxMs
    global enableRests, restEveryTrips, restMinSec, restMaxSec, maxTripsPerRun
    global enableLogging
    global running, paused, swapCount, tripsCount, lastA, lastB, nextETA, lastDir, A_ThisFuncLoopID

    ; Make sure panel values are applied (safely)
    cp_apply()

    if (!swapX || !swapY) {
        MsgBox "Please capture the Swap button (Ctrl+Alt+2) first."
        return
    }
    if (!revX || !revY) {
        MsgBox "Please capture the Reverse button (Ctrl+Alt+3)."
        return
    }
    if ((typeLegA || typeLegB) && (!amtX || !amtY)) {
        MsgBox "Amount typing is enabled — capture the Amount box (Ctrl+Alt+1)."
        return
    }

    running := true
    paused := false
    ToolTip "Running…  (Ctrl+Alt+P pause | Ctrl+Alt+Q quit)", 10, 10, 2
    initHud()
    updateHud()

    Loop {
        if !running
            break
        while paused
            Sleep 150

        A_ThisFuncLoopID := newLoopUUID()
        logEvent("LOOP_START")

        ; ------- LEG A (A→B) -------
        lastDir := "A→B"
        if (typeLegA) {
            a := fmtAmount(rand(aMin, aMax))
            typeAmount(a)
            lastA := a
            updateHud()
        } else {
            a := ""
        }
        clickAt(swapX, swapY)
        confirmedA := confirmWallet()
        sleepRand(postConfirmMinMs, postConfirmMaxMs)
        swapCount += 1
        logEvent("SWAP_DONE", "A", a, "", confirmedA)
        updateHud()

        ; ------- Reverse with delay -------
        Sleep randMs(revDelayMinMs, revDelayMaxMs)
        clickAt(revX, revY)
        Sleep randMs(revDelayMinMs, revDelayMaxMs)

        ; ------- LEG B (B→A) -------
        lastDir := "B→A"
        if (typeLegB) {
            b := fmtAmount(rand(bMin, bMax))
            typeAmount(b)
            lastB := b
            updateHud()
        } else {
            b := ""
        }
        clickAt(swapX, swapY)
        confirmedB := confirmWallet()
        sleepRand(postConfirmMinMs, postConfirmMaxMs)
        swapCount += 1
        logEvent("SWAP_DONE", "B", b, "", confirmedB)
        updateHud()

        ; one round-trip finished
        tripsCount += 1
        logEvent("TRIP_DONE")

        ; ------- Cooldown between round-trips -------
        cool := randMs(loopCooldownMinMs, loopCooldownMaxMs)
        nextETA := Round(cool/1000) "s"
        updateHud()
        Sleep cool

        ; ------- Session pause (every N trips) -------
        if (enableRests && restEveryTrips > 0 && Mod(tripsCount, restEveryTrips) = 0) {
            rest := Random(restMinSec, restMaxSec)
            nextETA := "rest " Round(rest) "s"
            updateHud()
            logEvent("REST_START", "", "", Round(rest*1000), "")
            Sleep Round(rest*1000)
            logEvent("REST_END")
        }

        ; ------- Max trips limiter -------
        if (maxTripsPerRun > 0 && tripsCount >= maxTripsPerRun) {
            ToolTip "Reached max trips (" tripsCount "). Stopping.", 10, 10, 2
            Sleep 1200
            ToolTip(,,,2)
            break
        }
    }
    ToolTip(,,,2)
}

pauseRun() {
    global paused
    paused := !paused
    if paused
        ToolTip "Paused  (Ctrl+Alt+P resume | Ctrl+Alt+Q quit)", 10, 10, 2
    else
        ToolTip "Running…  (Ctrl+Alt+P pause | Ctrl+Alt+Q quit)", 10, 10, 2
}

; ===================== AUTO-EXEC =====================
initTray()
showControlPanel()
initHud()
