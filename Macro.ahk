#NoEnv  ; Recommended for performance and compatibility with future AutoHotkey releases.
; #Warn  ; Enable warnings to assist with detecting common errors.
SendMode Input  ; Recommended for new scripts due to its superior speed and reliability.
SetWorkingDir %A_ScriptDir%  ; Ensures a consistent starting directory.

; GLOBAL VARIABLES

global TASKS := []

global ERRORS := 0
lastErrors := 0

global NeedsAlignment := true
global WaitingForTasks := false
global CameraChanged := false

global SelectedPlot := 0

global RobloxWindow
global iniFile := A_ScriptDir "\config.ini"

global AutoAlignCamera
global CurrentShop := ""
global MapSide := ""

global AutoHarvest
global HarvestNow := false

global WaitForRestocks

global shopKeys := Object()
shopKeys["Seeds"] := "Seed"
shopKeys["Gears"] := "Gear"
shopKeys["Props"] := "Prop"

; === Read from INI ===
iniFile := "config.ini"

IniRead, StartHotkey, %iniFile%, Settings, StartHotkey, F1
IniRead, PauseHotkey, %iniFile%, Settings, PauseHotkey, F2
IniRead, StopHotkey, %iniFile%, Settings, StopHotkey, F3

IniRead, AutoHarvest, %iniFile%, Settings, AutoHarvest, 0
IniRead, HarvestTime, %iniFile%, Settings, HarvestTime, 30
IniRead, AutoPlant, %iniFile%, Settings, AutoPlant, 0
IniRead, AutoSellPlants, %iniFile%, Settings, AutoSellPlants, 0

IniRead, WaitForRestocks, %iniFile%, Settings, WaitForRestocks, 1

IniRead, CameraModePos, %iniFile%, Settings, CameraModePos, 2

IniRead, MoveSpeed, %iniFile%, Settings, MoveSpeed, 16
IniRead, GardenSize, %iniFile%, Settings, GardenSize, 1

; === Bind Hotkeys Dynamically ===
Hotkey, %StartHotkey%, StartHotkeyLabel
Hotkey, %PauseHotkey%, PauseHotkeyLabel
Hotkey, %StopHotkey%, StopHotkeyLabel

; === Reconnect ===
global VIP_SERVER_LINK
global AutoReconnect
global JoinPublicServer
IniRead, VIP_SERVER_LINK, %iniFile%, Settings, VipServerLink, Enter a private server link here
INiRead, AutoReconnect, %iniFile%, Settings, AutoReconnect, 0
IniRead, JoinPublicServer, %iniFile%, Settings, JoinPublicServer, 0

; === Positiniong ===
global backpackBtnX
global backpackBtnY

IniRead, backpackBtnX, %iniFile%, Settings, backpackBtnX, 296
IniRead, backpackBtnY, %iniFile%, Settings, backpackBtnY, 53

; ITEMS
global seeds := ["Carrot", "Strawberry", "Blueberry", "Tulip", "Tomato", "Apple", "Bamboo", "Corn", "Cactus", "Pineapple", "Mushroom", "Green Bean", "Banana", "Grape", "Coconut", "Mango", "Dragon Fruit"
                , "Acorn", "Cherry", "Sunflower", "Venus Fly Trap", "Pomegranate", "Posion Apple", "Moon Bloom", "Dragon's Breath"]

global gears := ["Common Watering Can", "Common Sprinkler", "Sign", "Uncommon Sprinkler", "Trowel", "Rare Sprinkler", "Jump Mushroom", "Speed Mushroom", "Lantern", "Shrink Mushroom", "Supersize Mushroom"
                , "Gnome", "Flashbang", "Basic Pot", "Legendary Sprinkler", "Invisibility Mushroom", "Teleporter", "Wheelbarrow", "Super Watering Can", "Super Sprinkler"]

global props := ["Ladder Crate", "Bench Crate", "Light Crate", "Sign Crate", "Arch Crate", "Roleplay Crate", "Bridge Crate", "Spring Crate", "Seesaw Crate", "Conveyor Crate", "Owner Door Crate"
                , "Bear Trap Crate", "Fence Crate", "Teleporter Pad Crate"]


; SHOPS
; Create global shop objects
global shops := Object()
shops["Seeds"] := seeds
shops["Gears"] := gears
shops["Props"] := props

global shopPrefixes := Object()
shopPrefixes["Seeds"] := "Seed"
shopPrefixes["Gears"] := "Gear"
shopPrefixes["Props"]  := "Prop"

; FUNCTIONS
; --- Purchase reporting ---
global BoughtList := {}
global lastReportHour := ""

ClickRelative(relX, relY, coord := 0, noDelay := 0) {
    global RobloxWindow
    CoordMode, Window

    ; Ensure RobloxWindow is valid
    if !RobloxWindow || !WinExist("ahk_id " . RobloxWindow) {
        WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
        if !RobloxWindow {
            SetStatus("Roblox window not found!")
            CheckRobloxStatusFunc()
            return
        }
    }

    ; Activate & restore window
    WinActivate, ahk_id %RobloxWindow%
    WinWaitActive, ahk_id %RobloxWindow%, , 2
    WinGet, winState, MinMax, ahk_id %RobloxWindow%
    if (winState = -1) {
        ; Window is minimized, restore it
        WinRestore, ahk_id %RobloxWindow%
    }

    WinActivate, ahk_id %RobloxWindow%
    WinWaitActive, ahk_id %RobloxWindow%, , 2


    ; Get window position
    WinGetPos, X, Y, W, H, ahk_id %RobloxWindow%
    if (ErrorLevel || W = 0 || H = 0) {
        return
    }

    ; Calculate click coordinates
    if (coord = 1) {
        clickX := Round(X + (relX / 1936) * W)
        clickY := Round(Y + (relY / 1056) * H)
    } else if (coord = 2) {
        clickX := relX
        clickY := relY
    } else {
        clickX := Round(X + (W * relX))
        clickY := Round(Y + (H * relY))
        clickY += 3
    }

    oldMode := A_SendMode
    

    if (noDelay = 0) {
        SendMode Event
        MouseMove, %clickX%, %clickY%, 3
    }
    Sleep, 10
    Click, %clickX%, %clickY%

    SendMode %oldMode%
}

MouseMoveRelative(relX, relY, coord := 0, noDelay := 0, activate := 1) {
    global RobloxWindow

    ; Ensure RobloxWindow is valid
    if !RobloxWindow || !WinExist("ahk_id " . RobloxWindow) {
        WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
        if !RobloxWindow {
            SetStatus("Roblox window not found!")
            CheckRobloxStatusFunc()
            return
        }
    }

    ; Activate & restore window
    if (activate) {
        WinActivate, ahk_id %RobloxWindow%
        WinWaitActive, ahk_id %RobloxWindow%, , 2
        WinGet, winState, MinMax, ahk_id %RobloxWindow%
        if (winState = -1) {
            ; Window is minimized, restore it
            WinRestore, ahk_id %RobloxWindow%
        }

        WinActivate, ahk_id %RobloxWindow%
        WinWaitActive, ahk_id %RobloxWindow%, , 2
    }


    ; Get window position
    WinGetPos, X, Y, W, H, ahk_id %RobloxWindow%
    if (ErrorLevel || W = 0 || H = 0) {
        SetStatus("wingetpos failed")
        return
    }

    ; Calculate click coordinates
    if (coord = 1) {
        clickX := Round(X + (relX / 1936) * W)
        clickY := Round(Y + (relY / 1056) * H)
    } else if (coord = 2) {
        clickX := relX
        clickY := relY
    } else {
        clickX := Round(X + (W * relX))
        clickY := Round(Y + (H * relY))
        clickY += 3
    }

    oldMode := A_SendMode
    

    if (noDelay = 0) {
        SendMode Event
        MouseMove, %clickX%, %clickY%, 3
    }
    Sleep, 10

    SendMode %oldMode%
}

RotateCamera(degrees)
{
    global RobloxWindow

    if !RobloxWindow || !WinExist("ahk_id " . RobloxWindow)
    {
        WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
        if !RobloxWindow
            return
    }

    ClickRelative(0.5, 0.5)
    WinGetPos, X, Y, W, H, ahk_id %RobloxWindow%

    ; Scale from the 1936px reference width
    dx := Round(degrees * (6.0 / 1936.0) * W)

    Loop, 25 {
        Send, {WheelUp}
        Sleep, 25
    }

    DllCall("mouse_event"
        , "UInt", 0x0001
        , "Int", dx
        , "Int", 0
        , "UInt", 0
        , "UPtr", 0)

    Sleep, 500

    Loop, 6 {
        Send, {WheelDown}
        Sleep, 25
    }

    global CameraChanged := true
}

CheckCameraMode() {
    global RobloxWindow, CameraModePos
    WinGetPos, X, Y, W, H, ahk_id %RobloxWindow%

    Send, {Esc}
    Sleep, 1000
    Send, {Tab}
    Sleep, 500
    if ImageDetect("Video.png", 550, 240, 755, 336, 80) {
        ClickRelative(817, 205, 1)
        Sleep, 250
    }
    UINavigation("UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU", 1, 0)
    Sleep, 500
    if (CameraModePos = -1) {
        SetStatus("Detecting Camera Mode Position")
        i := -1
        Loop, 40 {
            i += 1
            if ImageDetect("CameraMode.png", 540, 210, 1400, 910, 120) {
                SetStatus("Camera Mode Detected at Setting #" . (%i% + 1))
                CameraModePos := i
                break
            }
            Send, {Down}
            Sleep, 30
        }
    }
    UINavigation("UUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUU", 1, 0)
    downTimes := (CameraModePos - 1)
    Loop, %downTimes% {
        Send, {Down}
        Sleep, 30
    }
    Loop, 4 {
        imagePath := A_ScriptDir . "\Images\Camera" . A_Index . ".png"
        ImageSearch, FoundX, FoundY, (((X+557)/1936)*W), (((Y+218)/1056)*H), (((X+1376)/1936)*W), (((Y+910)/1056)*H), *80 %imagePath%
        if (ErrorLevel = 0) {
            return A_Index
        }
    }

    Loop, 4 {
        Send, {Right}
        Sleep, 30
    }

    Loop, 4 {
        imagePath := A_ScriptDir . "\Images\Camera" . A_Index . ".png"
        ImageSearch, FoundX, FoundY, (((X+557)/1936)*W), (((Y+218)/1056)*H), (((X+1376)/1936)*W), (((Y+910)/1056)*H), *80 %imagePath%
        if (ErrorLevel = 0) {
            return A_Index
        }
    }
    
    SetStatus("ERROR: Unable to detect camera mode")
    return 0  ; No match found
}

SetCameraMode(number) {
    if (number > 4)
        number := 4

    mode := CheckCameraMode()
    if (mode) {
        distance := mode - number
        if (distance > 0) {
            Loop, %distance% {
                Send, {Left}
                Sleep, 100
            }
        } else if (distance < 0) {
            Loop, % Abs(distance) {
                Send, {Right}
                Sleep, 100
            }
        }
        Sleep, 1000
    }
    Send, {Esc}
    Sleep, 1000
    MouseMoveRelative(0.5, 0.5)
    Return
}

CheckRobloxStatusFunc() {

    ; Check if Roblox is not open
    WinGetPos, X, Y, W, H, ahk_exe RobloxPlayerBeta.exe
    if !(WinExist("Roblox")) {
        ReconnectToGame()
        return
    }
    
    ; Check if the disconnected text exists
    global RobloxWindow
    WinGetPos, X, Y, W, H, ahk_id %RobloxWindow%

    imagePath := A_ScriptDir . "\Images\Disconnected.png"
    ImageSearch, FoundX, FoundY, (((X+702)/1936)*W), (((Y+361)/1056)*H), (((X+1224)/1936)*W), (((Y+718)/1056)*H), *80 %imagePath%
    if (ErrorLevel = 0) {
        ReconnectToGame()
        return
    }
    
    ; Check for error windows
    try {
        if (WinExist("ahk_class #32770 ahk_exe RobloxPlayerBeta.exe")) {
            errorText := WinGetText, ahk_class #32770 ahk_exe RobloxPlayerBeta.exe
            if (InStr(errorText, "disconnected") || InStr(errorText, "lost connection") || InStr(errorText, "error") || InStr(errorText, "Disconnected")) {
                SetStatus("Connection error detected. Reconnecting...")
                WinClose, ahk_class #32770 ahk_exe RobloxPlayerBeta.exe
                Sleep, 1000
                ReconnectToGame()
                return
            }
        }
        
        ; Check Roblox window titles
        robloxWindows := WinGetList, ahk_exe RobloxPlayerBeta.exe
        for hwnd in robloxWindows {
            try {
                windowTitle := WinGetTitle, "ahk_id " . hwnd
                if (InStr(windowTitle, "Disconnected") || InStr(windowTitle, "Lost connection") || InStr(windowTitle, "Error")) {
                    SetStatus("Game disconnection detected. Reconnecting...")
                    ReconnectToGame()
                    return
                }
            }
        }
    }
}

ReconnectToGame() {
    global VIP_SERVER_LINK, RECONNECT_DELAY
    if (VIP_SERVER_LINK = "") || (VIP_SERVER_LINK = "Enter a private server link here.") {
        SetStatus("Cannot reconnect: No VIP Server link")
        return
    }
    
    SetStatus("Starting reconnection process...")
    
    ; Close all Roblox processes
    try {
        WinClose, ahk_exe RobloxPlayerBeta.exe
        Sleep, 1000
        WinClose, ahk_exe RobloxPlayerBeta.exe
        SetStatus("Roblox closed. Waiting...")
        Sleep, 2000
        
        ; Wait before reopening
        Sleep, %RECONNECT_DELAY%
        
        ; Open VIP Server link
        SetStatus("Opening Roblox...")
        if JoinPublicServer {
            joinLink := "roblox://placeID=97598239454123"
        } else {
            ; --- Extract the link-code part from the URL ---
            if (RegExMatch(VIP_SERVER_LINK, "i)(?<=privateServerLinkCode=)[A-Za-z0-9]+", linkCode))
            {
                ; Build the Roblox deeplink URI
                joinLink := "roblox://placeID=97598239454123&linkCode=" linkCode
            }
        }
        ; Launch via Windows Shell (same behavior as Win+R)
        try
        {
            ComObjCreate("Shell.Application").ShellExecute(joinLink)
        }
        catch e
        {
            MsgBox, 16, Error, % "Failed to launch Roblox:`n" e.Message
        }
        
        ; Wait for Roblox to open
        Loop 30 {
            global RobloxWindow
            if (WinExist("Roblox")) {
                WinMaximize, ahk_exe RobloxPlayerBeta.exe
                SetStatus("Roblox opened successfully. Loading game...")
                WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
                Sleep, 30000  ; Wait for game to load
                ; Check for connection failed
                imagePath := A_ScriptDir . "\Images\ConnectionFailed.png"
                ImageSearch, FoundX, FoundY, (((X+702)/1936)*W), (((Y+361)/1056)*H), (((X+1224)/1936)*W), (((Y+718)/1056)*H), *80 %imagePath%
                if (ErrorLevel = 0) {
                    SetStatus("Connection Failed. Retrying...")
                    Sleep, 2500
                    ReconnectToGame()
                }
                ; Connection didn't fail. Return to previous function
                SetStatus("Successfully joined game!")
                ClickRelative(0.5, 0.5)
                Sleep, 5000
                Click, {Down}
                Sleep, 5000
                Click, {Up}
                global NeedsAlignment := true
                global CameraChanged := false
                break
            }
            Sleep, 1000
        }
    }
}


UINavigation(command, uialreadyopen := 0, closeUi := 1, delay := 100) {
    ; If UI is not already open, press backslash to open it
    if (!uialreadyopen) {
        Send, {sc02B}  ; sc02B is the scancode for the backslash key ("\")
        Sleep, %delay%
    }

    ; Navigate to hotbar if settings start
    if (SettingsStart) {
        UINavigation("DDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDDD", 1, 0)
    }

    ; Loop through each character in the command string
    Loop, Parse, command
    {
        char := A_LoopField
        if (char = "U") {
            Send, {Up}
            Sleep, %delay% 
        } else if (char = "R") {
            Send, {Right}
            Sleep, %delay%
        } else if (char = "D") {
            Send, {Down}
            Sleep, %delay%
        } else if (char = "L") {
            Send, {Left}    
            Sleep, %delay%
        } else if (char = "E") {
            Send, {Enter}
            Sleep, %delay%
        } else if (char = "|") {
            Sleep, %delay%
        }
        
    }

    ; If closeUi flag is set, press backslash again to close
    if (closeUi) {
        Sleep, %delay%
        Send, {sc02B}
    }
}

AddTask(task, position := 0) {
    ; prevent duplicate tasks
    for i, v in TASKS {
        if (v == task) {
            return
        }
    }
    if (position) == 0 {
        TASKS.Push(task)
    } else {
        TASKS.InsertAt(position, task)
    }
}

GoToGarden(click := false) {
    if (click) {
        ClickRelative(970, 120, 1)
    } else {
        UINavigation("UUUUUUUUUUUULLLLLLLLLLLLURRRRRE", 0, 1)
    }
}

Harvest() {
    Walk("e", 5000, 1000, 0)
    CloseRobuxPrompt()
    Sleep, 500
}

searchItem(search := "nil") {
    global backpackBtnX
    global backpackBtnY

    if (search = "nil") {
        return
    }

    ClickRelative(%backpackBtnX%, %backpackBtnY%, 2)
    Sleep, 1000
    ClickRelative(1180, 676, 1)
    Sleep, 1000
    ; Delete any existing text
    Send, {Ctrl down}
    Send, {Right}
    Send, {Backspace}
    Send, {Ctrl up}
    Sleep, 1000
    Send, %search%

}
PixelColorFound(color, x1, y1, x2, y2, variation := 0, scale := 1) {
    ; Reference resolution
    refW := 1936
    refH := 1056

    ; Get Roblox window position & size
    if !RobloxWindow || !WinExist("ahk_id " . RobloxWindow) {
        WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
        if !RobloxWindow {
            SetStatus("Roblox window not found!")
            CheckRobloxStatusFunc()
            return
        }
    }

    ; Activate & restore window
    WinActivate, ahk_id %RobloxWindow%
    WinWaitActive, ahk_id %RobloxWindow%, , 2
    WinGet, winState, MinMax, ahk_id %RobloxWindow%
    if (winState = -1) {
        ; Window is minimized, restore it
        WinRestore, ahk_id %RobloxWindow%
    }

    WinActivate, ahk_id %RobloxWindow%
    WinWaitActive, ahk_id %RobloxWindow%, , 2

    ; Scale coordinates to current window size
    ; Get actual window geometry (was missing causing wrong coords)
    WinGetPos, winX, winY, winW, winH, ahk_id %RobloxWindow%
    if (ErrorLevel || winW = 0 || winH = 0) {
        SetStatus("WinGetPos failed")
        return
    }

    ; Use screen coordinates since we compute absolute positions
    CoordMode, Pixel, Screen
    CoordMode, Mouse, Screen

    scaleX := winW / refW
    scaleY := winH / refH

    if (scale) {
        sx1 := winX + (x1 * scaleX)
        sx2 := winX + (x2 * scaleX)
        sy1 := winY + (y1 * scaleY)
        sy2 := winY + (y2 * scaleY)
    } else {
        sx1 := x1
        sx2 := x2
        sy1 := y1
        sy2 := y2
    }

    ; Ensure integer coordinates
    sx1 := Floor(sx1)
    sy1 := Floor(sy1)
    sx2 := Floor(sx2)
    sy2 := Floor(sy2)

    ; Search for the pixel in the selected area
    PixelSearch, foundX, foundY, %sx1%, %sy1%, %sx2%, %sy2%, %color%, %variation%, Fast RGB
    if (ErrorLevel = 0)
        return 1
    else
        return 0
}

ImageDetect(imageName, x1, y1, x2, y2, variation = 0) {
    ; === Setup ===
    baseDir := A_ScriptDir . "\Images\"
    imagePath := baseDir . imageName

    ; Reference resolution (your base)
    refW := 1936
    refH := 1056

    ; Get Roblox window position & size
    if !RobloxWindow || !WinExist("ahk_id " . RobloxWindow) {
        WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
        if !RobloxWindow {
            SetStatus("Roblox window not found!")
            CheckRobloxStatusFunc()
            return
        }
    }

    ; Activate & restore window
    WinActivate, ahk_id %RobloxWindow%
    WinWaitActive, ahk_id %RobloxWindow%, , 2
    WinGet, winState, MinMax, ahk_id %RobloxWindow%
    if (winState = -1) {
        ; Window is minimized, restore it
        WinRestore, ahk_id %RobloxWindow%
    }

    WinActivate, ahk_id %RobloxWindow%
    WinWaitActive, ahk_id %RobloxWindow%, , 2

    CoordMode, Pixel, Window
    CoordMode, Mouse, Window

    ; === Try up to 4 times ===
    Loop, 4 {

        ; Scale coordinates relative to Roblox window
        x1s := X + ((x1 / refW) * W)
        y1s := Y + ((y1 / refH) * H)
        x2s := X + ((x2 / refW) * W)
        y2s := Y + ((y2 / refH) * H)

        ; Search within Roblox window
        ImageSearch, FoundX, FoundY, %x1s%, %y1s%, %x2s%, %y2s%, *%variation% %imagePath%, 

        if (ErrorLevel = 0) {
            Sleep, 500
            Tooltip
            return 1
        }
        Sleep, 1000
    }

    Sleep, 1000
    Tooltip
    return 0
}

ImageDetectTransparent(imageName, x1, y1, x2, y2, variation = 0, absolute = 0) {
    ; === Setup ===
    baseDir := A_ScriptDir . "\Images\"
    imagePath := baseDir . imageName

    ; Reference resolution (your base)
    refW := 1936
    refH := 1056

    ; Get Roblox window position & size
    if !RobloxWindow || !WinExist("ahk_id " . RobloxWindow) {
        WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
        if !RobloxWindow {
            SetStatus("Roblox window not found!")
            CheckRobloxStatusFunc()
            return
        }
    }

    ; Activate & restore window
    WinActivate, ahk_id %RobloxWindow%
    WinWaitActive, ahk_id %RobloxWindow%, , 2
    WinGet, winState, MinMax, ahk_id %RobloxWindow%
    if (winState = -1) {
        ; Window is minimized, restore it
        WinRestore, ahk_id %RobloxWindow%
    }

    WinActivate, ahk_id %RobloxWindow%
    WinWaitActive, ahk_id %RobloxWindow%, , 2

    CoordMode, Pixel, Window
    CoordMode, Mouse, Window

    ; === Try up to 4 times ===
    Loop, 4 {

        ; Scale coordinates relative to Roblox window
        if (absolute) {
            x1s := X + ((x1 / refW) * W)
            y1s := Y + ((y1 / refH) * H)
            x2s := X + ((x2 / refW) * W)
            y2s := Y + ((y2 / refH) * H)
        } else {
            x1s := x1
            y1s := y1
            x2s := x2
            y2s := y2
        }

        ; Search within Roblox window
        ImageSearch, FoundX, FoundY, %x1s%, %y1s%, %x2s%, %y2s%, *%variation% *Trans0x000000 %imagePath%, 

        if (ErrorLevel = 0) {
            Sleep, 500
            Tooltip
            return 1
        }
        Sleep, 1000
    }

    Sleep, 1000
    Tooltip
    return 0
}

capitalizeFirst(text) {
    firstChar := SubStr(text, 1, 1)
    StringUpper, firstChar, firstChar, T
    return firstChar . SubStr(text, 2)
}

AddBoughtItem(item, qty) {
    global BoughtList
    if (qty <= 0)
        return
    if !IsObject(BoughtList)
        BoughtList := {}

    if (BoughtList.HasKey(item)) {
        BoughtList[item] += qty
    } else {
        BoughtList[item] := qty
    }

    ; Also append to a running purchases log immediately for reliability
    reportDir := A_ScriptDir "\Reports"
    FileCreateDir, %reportDir%
    timestamp := A_Now
    FormatTime, humanTime, %timestamp%, yyyy-MM-dd HH:mm:ss
    logLine := humanTime " - " item " x" qty "`r`n"
    FileAppend, %logLine%, %reportDir% "\purchases_current.txt"
}

HourlyReport() {
    global BoughtList
    ; Determine previous hour label (report covers the last hour)
    prev := A_Now
    EnvAdd, prev, -1, hours
    FormatTime, label, %prev%, yyyy-MM-dd_HH

    reportDir := A_ScriptDir "\Reports"
    FileCreateDir, %reportDir%
    file := reportDir "\hourly_report_" label ".txt"

    header := "Hourly report for " label "`r`n`r`n"
    FileAppend, %header%, %file%

    wrote := 0
    if IsObject(BoughtList) {
        for item, qty in BoughtList {
            line := item " x" qty "`r`n"
            FileAppend, %line%, %file%
            wrote := 1
        }
    }

    if (wrote = 0) {
        FileAppend, % "No purchases recorded.`r`n", %file%
    }

    ; Clear the list after reporting
    BoughtList := {}
}


AnyItemsSelected(shopName) {
    global shops
    anyItemsSelected := false
    capitalized := capitalizeFirst(shopName)

    shop := shops[capitalized]

    ; Determine the INI key prefix from the dictionary
    keyPrefix := shopKeys[capitalized]
    if (keyPrefix = "")
    {
        MsgBox, 48, Error, No key mapping found for shop "%capitalized%"
        return false
    }
    anyItemsSelected := false

    ; Loop through the items in the given shop array (e.g., Seeds, Tools, etc.)
    for i, item in shop
    {
        IniRead, checked, %iniFile%, %capitalized%, %keyPrefix%%i%, 0
        if (checked = "1" || checked = 1)
        {
            anyItemsSelected := true
            break
        }
    }

    return anyItemsSelected
}

BuyFromShop(shopName) {
    global doubleScrolls, itemPositions, seeds, gears, iniFile, ahopa
    global RobloxWindow

    WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
    if !RobloxWindow {
        SetStatus("Roblox window not found!")
        CheckRobloxStatusFunc()
        return
    }

    ; Navigate to the first item in the shop
    UINavigation("DDUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUDD")
    Sleep, 100
    ClickRelative(970, 620, 1)
    Sleep, 1000
    UINavigation("DDUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUUDDE||E", 0, 0)
    Sleep, 1000

    ; Get shop items and prefix
    if shops.hasKey(shopName) {
        shopItems := shops[shopName]
        section := shopName
        prefix := shopPrefixes[shopName]
    } else {
        MsgBox, Shop name not found: %shopName%
        return
    }

    ; Read selected items from INI
    selectedItems := []
    for i, item in shopItems {
        IniRead, checked, %iniFile%, %section%, %prefix%%i%, 0
        if (checked = "1" || checked = 1) {
            selectedItems.Push(item)
        }
    }

    ; Build name-based lookup map
    selectedNameMap := {}
    for _, item in selectedItems {
        selectedNameMap[item] := true
    }

    ; Loop through shop items
    for index, item in shopItems {
        idx := index + 0

        ; Scroll down if not the first item
        if (idx != 1) {
            Send, {Down}
            Sleep, 500
        }

        ; Only buy if item is selected
        if selectedNameMap.HasKey(item) {
            Tooltip, Buying %item%
            UINavigation("E|||||D", 1, 0)
            bought := 0

            Sleep, 100
            if PixelColorFound(0x308C00, 515, 300, 1415, 920, 0) {
                Loop, 50 {
                    if !(PixelColorFound(0x308C00, 515, 300, 1415, 920, 0)) {
                        break
                    }
                    UINavigation("E|", 1, 0, 65)
                    bought += 1
                    Tooltip, Bought %item% %bought%x
                }
                ; If purchases occurred, record them to the BoughtList
                if (bought >= 0) {
                    qty := bought + 1
                    AddBoughtItem(item, qty)
                }
            }
        }

        Sleep, 150
    }

    ; Exit shop
    UINavigation("", 1, 1)
    Sleep, 1000 
    ClickRelative(1370, 240, 1)
    Sleep, 1000
    GoToGarden()

    ; Confirm Roblox window still exists
    WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
    if !RobloxWindow {
        SetStatus("Roblox window not found!")
        CheckRobloxStatusFunc()
        return
    }

    Sleep, 1000
    ClickRelative(0.5, 0.5)
    Sleep, 1000
    Return
}

Walk(direction, length, delay := 500, studs := 1) {
    global MoveSpeed
    if (studs) {
        holdDuration := (length/MoveSpeed)*1000
        ;Send, {%direction%}
        Send, {%direction% down}
        Sleep, %holdDuration%
        Send, {%direction% up}
        Sleep, %delay%
    } else {
        Send, {%direction%}
        Send, {%direction% down}
        Sleep, %length%
        Send, {%direction% up}
        Sleep, %delay%
    }
}

CloseRobuxPrompt() {
    Send, {Esc}
    Sleep, 100
    Send, {Esc}
    Sleep, 1000
}

SetStatus(status) {
    Tooltip, %status%
    SetTimer, ClearTooltip, -1500
}

CheckForUpdate() {
    currentVersion := "Release1.02"
    latestURL := "https://api.github.com/repos/DeweyPointJr/Scripter-Grow-A-Garden-2-Macro/releases/latest"

    whr := ComObjCreate("WinHttp.WinHttpRequest.5.1")
    whr.Open("GET", latestURL, false)
    whr.Send()
    whr.WaitForResponse()
    status := whr.Status + 0

    if (status != 200) {
        MsgBox, Failed to fetch release info. Status: %status%
        return
    }

    json := whr.ResponseText
    RegExMatch(json, """tag_name"":\s*""([^""]+)""", m)
    latestVersion := m1

    if (latestVersion = "") {
        MsgBox, Could not find latest version in response.
        return
    }

    if (latestVersion != currentVersion) {
        MsgBox, 4, Update Available, New version %latestVersion% found! Download and install?
        IfMsgBox, Yes
        {
            RegExMatch(json, """zipball_url"":\s*""([^""]+)""", d)
            downloadURL := d1
            if (downloadURL = "") {
                MsgBox, Could not find zipball_url in release JSON.
                return
            }

            whr2 := ComObjCreate("WinHttp.WinHttpRequest.5.1")
            whr2.Open("GET", downloadURL, false)
            whr2.Send()
            whr2.WaitForResponse()
            status2 := whr2.Status + 0

            if (status2 != 200) {
                MsgBox, Failed to download update file. Status: %status2%
                return
            }

            stream := ComObjCreate("ADODB.Stream")
            stream.Type := 1 ; binary
            stream.Open()
            stream.Write(whr2.ResponseBody)
            stream.SaveToFile(A_ScriptDir "\update.zip", 2)
            stream.Close()

            ; Extract the update
            RunWait, %ComSpec% /c powershell -Command "Expand-Archive -Force '%A_ScriptDir%\update.zip' '%A_ScriptDir%'",, Hide

            ; Run updater (it will handle the log and file moves)
            Run, %A_ScriptDir%\Submacros\update.ahk
            ExitApp
        }
    } else {
        ; On startup, check if update.ahk has a pending replacement
        CheckForUpdatedUpdater()
    }
}

; --- Helper function to replace update.ahk safely ---
CheckForUpdatedUpdater() {
    updateCandidate := A_ScriptDir "\update_files\update.ahk"
    if FileExist(updateCandidate) {
        FileMove, %updateCandidate%, %A_ScriptDir%\Submacros\update.ahk, 1
        FileRemoveDir, %A_ScriptDir%\update_files, 1
    }
}


CheckForUpdate()

; Show Gui
Gosub, MainGui
return

; MAIN LOOP

MainLoop:
    Gui, Destroy

    global NeedsAlignment, WaitingForTasks, ERRORS, WaitForRestocks

    CheckRobloxStatusFunc()

    WinGet, RobloxWindow, ID, ahk_exe RobloxPlayerBeta.exe
    if (RobloxWindow) {
        WinActivate, ahk_id %RobloxWindow%

        ; Roblox is active. Start main macro actions.

        ; Check for reconnect
        global AutoReconnect
        if (AutoReconnect) {
            CheckRobloxStatusFunc()
        }

        ; Make sure camera is aligned correctly
        if (lastErrors != ERRORS) {
            lastErrors := ERRORS
            Gosub, AutoAlignCameraLabel
            NeedsAlignment := false
        }
        if (ERRORS > 3) && (AutoReconnect) {
            ReconnectToGame()
            ERRORS := 0
        }

        if NeedsAlignment {
            NeedsAlignment := false
            Gosub, AutoAlignCameraLabel
        }

        if (AutoHarvest && HarvestNow) {
            Gosub, AutoHarvestLabel
            HarvestNow := false
        }

        if (TASKS.Length()) {
            WaitingForTasks := false
            NextTask := TASKS.RemoveAt(1)
            Gosub, % NextTask
        } else {
            if WaitForRestocks {
                if !WaitingForTasks {
                    Gosub, AutoAlignCameraLabel
                    Sleep, 500
                    ClickRelative(963, 143, 1)
                    Sleep, 1000
                    Tooltip, Waiting For Restocks...
                }
                WaitingForTasks := true
            } else {
                NeedsAlignment := True
                Gosub, AddOneMinuteTasks
                Gosub, AddFiveMinuteTasks
                Gosub, AddFifteenMinuteTasks
                Gosub, AddThirtyMinuteTasks
            }
        }
        
    } else {
        if (AutoReconnect) {
            CheckRobloxStatusFunc()
        } else {
            MsgBox, Roblox window not found! Please open Roblox.
        }
        
    }

    SetTimer, MainLoop, -1000
Return

; GUI Code

MainGui:
    Gui, Destroy
    Gui, New, +Resize, Scripter Macro

    ; Title label at the top
    Gui, Add, Text, w180 h30 Center vTitleText, Scripter Grow A Garden 2 Macro [RELEASE]

    ; Buttons stacked vertically
    Gui, Add, Button, w180 h40 gShopsGui, Shops
    Gui, Add, Button, w180 h40 gSettingsGui, Settings
    Gui, Add, Button, w180 h40 gStartHotkeyLabel, Start (%StartHotkey%)

    ; Show GUI
    Gui, Show, w200 h200, Scripter Macro
return

ShopsGui:
    Gui, Destroy
    Gui, New, +Resize, Scripter Macro

    ; Buttons stacked vertically
    Gui, Add, Button, w180 h40 gSeedsGui, Seeds
    Gui, Add, Button, w180 h40 gGearsGui, Gears
    Gui, Add, Button, w180 h40 gPropsGui, Props
    Gui, Add, Button, w180 h40 gMainGui, Back

    ; Show GUI
    Gui, Show, w200 h200, Scripter Macro
return

SeedsGui:
    CurrentShop := "Seeds"
    Gosub, ShowShopGui
return

GearsGui:
    CurrentShop := "Gears"
    Gosub, ShowShopGui
return

PropsGui:
    CurrentShop := "Props"
    Gosub, ShowShopGui
Return

SettingsGui:

    Gui, Destroy
    Gui, New, +Resize, Settings

    ; Create tab control
    Gui, Add, Tab2, x10 y10 w280 h200, General|Roblox|Hotkeys|Positioning|Reconnect

    ; === General Tab ===
    Gui, Add, Text, x20 y50, Auto Align Camera:
    IniRead, AutoAlignCamera, config.ini, Settings, AutoAlignCamera, 1
    Gui, Add, Checkbox, vAutoAlignCamera x120 y50
    GuiControl,, AutoAlignCamera, %AutoAlignCamera%

    Gui, Add, Text, x20 y75, Auto Harvest
    Gui, Add, Checkbox, vAutoHarvest gHarvestCheck x90 y75
    GuiControl,, AutoHarvest, %AutoHarvest%

    ; Hidden text for autoharvest
    Gui, Add, Text, x120 y75 Hidden vHarvestEveryText1, every
    Gui, Add, Edit, x150 y72 w50 h20 Hidden vHarvestTimeEdit, %HarvestTime%
    Gui, Add, Text, x205 y75 Hidden vHarvestEveryText2, minutes

    Gosub, HarvestCheck

    Gui, Add, Text, x20 y100, Auto Sell Plants:
    IniRead, AutoSellPlants, config.ini, Settings, AutoSellPlants, 0
    Gui, Add, Checkbox, vAutoSellPlants x120 y100
    GuiControl,, AutoSellPlants, %AutoSellPlants%

    Gui, Add, Button, x20 y125 w18 h18 gInfoWaitForRestocks, ?
    Gui, Add, Text, x40 y125, Wait For Restocks:
    IniRead, WaitForRestocks, config.ini, Settings, WaitForRestocks, 1
    Gui, Add, Checkbox, vWaitForRestocks x140 y125
    GuiControl,, WaitForRestocks, %WaitForRestocks%

    Gui, Add, Button, x20 y150 w18 h18 gInfoMoveSpeed, ?
    Gui, Add, Text, x40 y150, Move Speed:
    Gui, Add, Edit, vMoveSpeedEdit Number x115 y148 w100
    GuiControl,, MoveSpeedEdit, %MoveSpeed%

    Gui, Add, Button, x20 y175 w18 h18 gInfoGardenSize, ?
    Gui, Add, Text, x40 y175, Garden Size:
    Gui, Add, DropDownList, vGardenSize x105 y173 w35, 1|2|3|4|5
    GuiControl, ChooseString, GardenSize, %GardenSize%

    ; === Roblox Tab ===
    Gui, Tab, 2
    Gui, Add, Text, x20 y50, Camera Mode Position:
    Gui, Add, Edit, vCameraModePos Number x150 y48 w100
    GuiControl,, CameraModePos, %CameraModePos%


    ; === Hotkeys Tab ===
    Gui, Tab, 3
    Gui, Add, Text, x20 y50, Start Hotkey:
    Gui, Add, Edit, vStartHotkeyEdit x150 y48 w100
    GuiControl,, StartHotkeyEdit, %StartHotkey%

    Gui, Add, Text, x20 y80, Pause Hotkey:
    Gui, Add, Edit, vPauseHotkeyEdit x150 y78 w100
    GuiControl,, PauseHotkeyEdit, %PauseHotkey%

    Gui, Add, Text, x20 y110, Stop Hotkey:
    Gui, Add, Edit, vStopHotkeyEdit x150 y108 w100
    GuiControl,, StopHotkeyEdit, %StopHotkey%

    ; === Positioning Tab ===
    Gui, Tab, 4
    Gui, Add, Button, x20 y50 w100 h35 gSetBackpackPos, Set Backpack Button Position

    ; === Reconnect Tab ===
    Gui, Tab, 5
    Gui, Add, Text, x20 y40 w150, VIP Server Link:
    Gui, Add, Edit, x20 y60 w200 h20 vVipLink, %VIP_SERVER_LINK%
    Gui, Add, Text, x20 y90 w120, Auto Reconnect:
    Gui, Add, Checkbox, x110 y92 vAutoReconnect
    Gui, Add, Text, x20 y115 w120, Join Public Server:
    Gui, Add, Checkbox, x110 y117 vJoinPublicServer
    GuiControl,, AutoReconnect, %AutoReconnect%
    GuiControl,, JoinPublicServer, %JoinPublicServer%
    Gui, Add, Button, gReconnectToGame x20 y145 w80 h30, Test Reconnect

    Gui, Add, Text, x20 y180, Credit to INNIE for the original reconnect script!

    ; === Save Button ===
    Gui, Tab  ; Ends tab section
    Gui, Add, Button, gSaveSettings x100 y220 w100 h30, Save

    Gui, Show, w300 h260, Settings
return

AutoPlantCheck:
    GuiControlGet, AutoPlant
    if (AutoPlant)
        GuiControl, Show, AutoPlantSettingsBtn
    else
        GuiControl, Hide, AutoPlantSettingsBtn
return

InfoWaitForRestocks:
    MsgBox, Turning this setting on makes the macro wait until the shops restock before buying from then again. When this setting is off, the macro will just repeatedly loop through all shops you have selected.
Return

InfoMoveSpeed:
    MsgBox, To find your move speed, add up the total move speed buff from your pets, and then add 16 to that number. THIS MUST BE CORRECT OR THE MACRO WILL NOT BE ABLE TO WALK!!
Return

InfoGardenSize:
    MsgBox, Set this to the number of rows of plots your garden has
Return

SaveSettings:
    Gui, Submit, NoHide

    ; Save general to INI
    IniWrite, %AutoAlignCamera%, config.ini, Settings, AutoAlignCamera
    IniWrite, %UseEventLanterns%, config.ini, Settings, UseEventLanterns
    IniWrite, %AutoHarvest%, config.ini, Settings, AutoHarvest
    IniWrite, %HarvestTimeEdit%, config.ini, Settings, HarvestTime
    IniWrite, %AutoPlant%, %iniFile%, Settings, AutoPlant
    IniWrite, %AutoSellPlants%, config.ini, Settings, AutoSellPlants
    IniWrite, %MoveSpeedEdit%, config.ini, Settings, MoveSpeed
    IniWrite, %GardenSize%, config.ini, Settings, GardenSize

    ; Save Roblox to INI
    IniWrite, %CameraModePos%, config.ini, Settings, CameraModePos


    ; Save hotkeys to INI
    IniWrite, %StartHotkeyEdit%, config.ini, Settings, StartHotkey
    IniWrite, %PauseHotkeyEdit%, config.ini, Settings, PauseHotkey
    IniWrite, %StopHotkeyEdit%, config.ini, Settings, StopHotkey

    ; Save Reconnect Settings
    IniWrite, %VipLink%, config.ini, Settings, VipServerLink
    IniWrite, %AutoReconnect%, config.ini, Settings, AutoReconnect
    IniWrite, %JoinPublicServer%, config.ini, Settings, JoinPublicServer

    Reload ; hotkey changes take effect
Return

HarvestCheck:
    Gui, Submit, NoHide
    if (AutoHarvest) {
        GuiControl, Show, HarvestEveryText1
        GuiControl, Show, HarvestTimeEdit
        GuiControl, Show, HarvestEveryText2
    } else {
        GuiControl, Hide, HarvestEveryText1
        GuiControl, Hide, HarvestTimeEdit
        GuiControl, Hide, HarvestEveryText2
    }
Return

OpenAutoPlantSettings:
    Gosub, ShowAutoPlantGui
return

ShowAutoPlantGui:

    Gui, AutoPlant:Destroy
    Gui, AutoPlant:New,, Auto Plant Settings

    ; Plots

    Gui, AutoPlant:Add, Text, x80 y10, Garden Layout

    PlotW := 65
    PlotH := 25

    PlotMap := [9,10,7,8,5,6,3,4,1,2]

    Row := 0
    Loop, 5
    {
        Y := 40 + (Row * 27)

        LeftID  := PlotMap[Row*2 + 1]
        RightID := PlotMap[Row*2 + 2]

        Gui, AutoPlant:Add, Picture, x30 y%Y% w%PlotW% h%PlotH% gSelectPlot vPlot%LeftID%, Images\Plot.png
        Gui, AutoPlant:Add, Picture, x140 y%Y% w%PlotW% h%PlotH% gSelectPlot vPlot%RightID%, Images\Plot.png

        Row++
    }

    Gui, AutoPlant:Add, Text, x50 y180 w120 Center, Garden Entrance

    ; Seeds

    Gui, AutoPlant:Add, Text, x240 y10, Seeds

    Gui, AutoPlant:Add, ListView, x240 y30 w200 h180 vSeedLV -Multi, Seeds will be planted in this order

    Gui, AutoPlant:Add, Button, x240 y220 w45 h23 gAddSeed, Add
    Gui, AutoPlant:Add, Button, x290 y220 w55 h23 gRemoveSeed, Remove
    Gui, AutoPlant:Add, Button, x350 y220 w30 h23 gSeedUp, ^
    Gui, AutoPlant:Add, Button, x385 y220 w30 h23 gSeedDown, v

    Gui, AutoPlant:Add, Button, x200 y285 w60 h25 gDoneAutoPlant, Done

    LoadAutoPlantSettings()

    Gui, AutoPlant:Show, w460 h320
return

DoneAutoPlant:
    Gosub, SaveAutoPlantSettings
    Gui, AutoPlant:Destroy
return

SelectPlot: 
    global SelectedPlot 
    Ctrl := A_GuiControl 
    StringTrimLeft, PlotNum, Ctrl, 4 ; reset previous selection 
    if (SelectedPlot) 
        GuiControl, AutoPlant:, Plot%SelectedPlot%, Images\Plot.png 
        SelectedPlot := PlotNum ; set new selection image 
        GuiControl, AutoPlant:, Plot%PlotNum%, Images\PlotSelected.png 
        return

SelectPlotManual(PlotNum := "")
{
    global SelectedPlot

    ; If called from GUI click
    if (PlotNum = "")
    {
        Ctrl := A_GuiControl
        StringTrimLeft, PlotNum, Ctrl, 4
    }

    ; Safety: ignore invalid calls
    if (PlotNum = "")
        return

    ; Reset previous selection (only ONE allowed)
    if (SelectedPlot)
        GuiControl, AutoPlant:, Plot%SelectedPlot%, Images\Plot.png

    SelectedPlot := PlotNum

    ; Set new selection image
    GuiControl, AutoPlant:, Plot%PlotNum%, Images\PlotSelected.png
}

AddSeed:
    InputBox, SeedName, Add Seed, Enter seed name:

    if (ErrorLevel || SeedName = "")
        return

    Gui, AutoPlant:Default
    LV_Add("", SeedName)
return

RemoveSeed:
    Gui, AutoPlant:Default

    Row := LV_GetNext()

    if !Row
        return

    LV_Delete(Row)
return

SeedUp:
    Gui, AutoPlant:Default

    Row := LV_GetNext()

    if (!Row || Row = 1)
        return

    LV_GetText(SeedName, Row)

    LV_Delete(Row)
    LV_Insert(Row - 1, "", SeedName)
    LV_Modify(Row - 1, "Select Focus")

return

SeedDown:
    Gui, AutoPlant:Default

    Row := LV_GetNext()

    if !Row
        return

    Count := LV_GetCount()

    if (Row >= Count)
        return

    LV_GetText(SeedName, Row)

    LV_Delete(Row)
    LV_Insert(Row + 1, "", SeedName)
    LV_Modify(Row + 1, "Select Focus")

return

SaveAutoPlantSettings:
    global SelectedPlot

    ; Save plots

    IniWrite, %SelectedPlot%, %iniFile%, AutoPlant, SelectedPlot


    ; Save seed list

    Gui, AutoPlant:Default

    SeedList := ""

    Loop % LV_GetCount()
    {
        LV_GetText(SeedName, A_Index)

        if (SeedList != "")
            SeedList .= "|"

        SeedList .= SeedName
    }

    IniWrite, %SeedList%, %iniFile%, AutoPlant, Seeds

    Gui, AutoPlant:Destroy

return

LoadAutoPlantSettings()
{
    global iniFile

    IniRead, SelectedPlot, %iniFile%, AutoPlant, SelectedPlot

    IniRead, SeedList, %iniFile%, AutoPlant, Seeds,
    if (ErrorLevel || SeedList = "ERROR")
        SeedList := ""

    Gui, AutoPlant:Default
    LV_Delete()  ; important: clear old items

    Loop, Parse, SeedList, |
    {
        if (A_LoopField != "")
            LV_Add("", A_LoopField)
    }

    SelectPlotManual(SelectedPlot)
}

; Closing GUI exits macro
GuiClose:
    ExitApp
Return

; Gui labels
DynamicDone:
    global CurrentShop, shops, shopKeys, iniFile

    if (CurrentShop = "" || !shops.HasKey(CurrentShop)) {
        MsgBox, 48, Warning, No shop is currently open or invalid!
        return
    }

    shopItems := shops[CurrentShop]       ; array of items
    keyPrefix := shopKeys[CurrentShop]    ; prefix for INI keys

    ; Loop through items and save checkbox states
    for i, item in shopItems {
        controlVar := keyPrefix . "_" . i    ; must match vVariable of the checkbox
        
        GuiControlGet, checked, , %controlVar%
        if (checked = "")                  ; ensure unchecked boxes are saved as 0
            checked := 0

        iniKey := keyPrefix . i            ; desired INI key format: Egg1, Egg2, etc.
        IniWrite, %checked%, %iniFile%, %CurrentShop%, %iniKey%
    }

    CurrentShop := ""                      ; reset after saving
    Gosub, MainGui                         ; return to main GUI
Return


ShowShopGui:
    global shopKeys, shopPrefixes, shops, CurrentShop, iniFile

    shopName := CurrentShop
    if (shopName = "" || !shops.HasKey(shopName)) {
        MsgBox, 48, Error, ShowShopGui called with invalid shop name: "%shopName%"
        return
    }

    capitalized := shopName
    keyPrefix := shopKeys[capitalized]
    if (keyPrefix = "") {
        MsgBox, 48, Error, No key mapping found for shop "%capitalized%"
        return
    }

    shopItems := shops[shopName]

    Gui, Destroy
    Gui, New, +Resize, %capitalized% Selection

    xOffset := 10
    yOffset := 10
    spacingX := 150
    spacingY := 30
    perColumn := 15

    Count := shopItems.MaxIndex()
    if (Count = "")
        Count := 0

    ; Add checkboxes dynamically
    for i, item in shopItems {
        col := Floor((i - 1) / perColumn)
        row := Mod(i - 1, perColumn)
        xPos := xOffset + (col * spacingX)
        yPos := yOffset + (row * spacingY)

        IniRead, checked, %iniFile%, %capitalized%, %keyPrefix%%i%, 0
        ctrlName := keyPrefix . "_" . i
        Gui, Add, Checkbox, v%ctrlName% x%xPos% y%yPos% w140 h25, %item%
        GuiControl,, %ctrlName%, %checked%
    }

    ; Calculate GUI size
    totalCols := Floor((Count - 1) / perColumn) + 1
    totalRows := (Count < perColumn) ? Count : perColumn
    buttonWidth := 100
    buttonSpacing := 20
    buttonsTotalWidth := (buttonWidth * 2) + buttonSpacing
    minWidthForButtons := buttonsTotalWidth + 40  ; extra padding
    calculatedWidth := xOffset + (totalCols * spacingX) + 20
    totalWidth := (calculatedWidth < minWidthForButtons) ? minWidthForButtons : calculatedWidth
    totalHeight := yOffset + (totalRows * spacingY) + 60

    ; Center buttons horizontally
    buttonsTotalWidth := (buttonWidth * 2) + buttonSpacing
    buttonsStartX := (totalWidth - buttonsTotalWidth) / 2
    buttonY := yOffset + (totalRows * spacingY) + 10

    ; Select All/None button
    Gui, Add, Button, x%buttonsStartX% y%buttonY% w%buttonWidth% h30 gToggleSelectAll vSelectAllButton, Select All

    ; Done button
    doneX := buttonsStartX + buttonWidth + buttonSpacing
    Gui, Add, Button, x%doneX% y%buttonY% w%buttonWidth% h30 gDynamicDone, Done

    ; Determine initial Select All/None button label
    allInitiallyChecked := true
    Loop, % Count {
        ctrlName := keyPrefix . "_" . A_Index
        GuiControlGet, state, , %ctrlName%
        if (!state) {
            allInitiallyChecked := false
            break
        }
    }
    initialLabel := allInitiallyChecked ? "Select None" : "Select All"
    GuiControl,, SelectAllButton, %initialLabel%
    
    ; Show GUI after setting correct button label
    Gui, Show, w%totalWidth% h%totalHeight%, %capitalized% Selection
Return

ToggleSelectAll:
    allChecked := true
    Loop, % Count {
        ctrlName := keyPrefix . "_" . A_Index
        GuiControlGet, state, , %ctrlName%
        if (!state) {
            allChecked := false
            break
        }
    }

    newState := allChecked ? 0 : 1
    Loop, % Count {
        ctrlName := keyPrefix . "_" . A_Index
        GuiControl,, %ctrlName%, %newState%
    }

    newLabel := allChecked ? "Select All" : "Select None"
    GuiControl,, SelectAllButton, %newLabel%
Return

; Hotkey Labels
StartHotkeyLabel() {
    global WaitForRestocks

    Gui, Submit

    ; Ensure TASKS exists and remove any stale AutoHarvestLabel entries
    if (!IsObject(TASKS))
        TASKS := []
    i := 1
    while (i <= TASKS.Length()) {
        if (TASKS[i] = "AutoHarvestLabel")
            TASKS.RemoveAt(i)
        else
            i++
    }

    ; Start the auto-harvest timer: align with last harvest time so interval is preserved
    if (AutoHarvest) {
        ; Read last harvest wall-clock time (A_Now format)
        IniRead, lastHarvestStr, %iniFile%, Harvest, LastHarvest, 0
        desired := HarvestTime * 60000
        if (lastHarvestStr = "" || lastHarvestStr = "0") {
            ; No previous harvest recorded: start fresh
            SetTimer, AutoHarvestTimer, % desired
        } else {
            ; Compute target time = lastHarvest + HarvestTime minutes
            target := lastHarvestStr
            EnvAdd, target, %HarvestTime%, minutes

            ; If target already passed, harvest now and schedule next full interval
            if (A_Now >= target) {
                HarvestNow := true
                SetTimer, AutoHarvestTimer, % desired
            } else {
                ; Compute remaining seconds until target by stepping seconds (safe since interval is small)
                cur := A_Now
                secCount := 0
                ; guard: don't loop more than desired/1000 + 10
                maxSec := (desired // 1000) + 10
                while (cur < target) {
                    EnvAdd, cur, 1, seconds
                    secCount += 1
                    if (secCount > maxSec) {
                        break
                    }
                }
                remainingMs := secCount * 1000
                if (remainingMs <= 0) {
                    HarvestNow := true
                    SetTimer, AutoHarvestTimer, % desired
                } else {
                    SetTimer, AutoHarvestTimer, % remainingMs
                }
            }
        }
    } else {
        SetTimer, AutoHarvestTimer, Off
    }

    ; Add tasks
    if WaitForRestocks {
        Gosub, AddOneMinuteTasks
        Gosub, AddFiveMinuteTasks
        Gosub, AddFifteenMinuteTasks
        Gosub, AddThirtyMinuteTasks
    }

    ; Start running
    global NeedsAlignment := true
    ; Initialize lastReportHour for hourly reports
    FormatTime, lastReportHour,, H
    SetTimer, CheckForNewTasks, -1000
    Gosub, MainLoop
}

PauseHotkeyLabel() {
    Pause
}

StopHotkeyLabel() {
    Reload
}

; Positioning Labels
SetBackpackPos:
    MsgBox, 64, Backpack Setup, Click where your backpack button is located.
    Gui, Hide
    ; Wait for left click
    KeyWait, LButton, D
    MouseGetPos, backpackBtnX, backpackBtnY
    MsgBox, 64, Backpack Setup, Backpack button set at X %backpackBtnX% Y %backpackBtnY%

    ; Save the location
    IniWrite, %backpackBtnX%, %iniFile%, Settings, backpackBtnX
    IniWrite, %backpackBtnY%, %iniFile%, Settings, backpackBtnY
    Gui, Show
Return

; Core labels
CheckForNewTasks:
    FormatTime, curMin,, m
    FormatTime, curSec,, s

    ; Detect hour change for hourly reports
    FormatTime, curHour,, H
    if (lastReportHour = "") {
        lastReportHour := curHour
    } else if (curHour != lastReportHour) {
        HourlyReport()
        lastReportHour := curHour
    }

    curMin := curMin + 0
    curSec := curSec + 0

    ; Check at the start of a minute
    if (curSec = 0) {
        Gosub, AddOneMinuteTasks

        if (Mod(curMin, 5) = 0)
            Gosub, AddFiveMinuteTasks

        if (Mod(curMin, 15) = 0)
            Gosub, AddFifteenMinuteTasks

        if (Mod(curMin, 30) = 0)
            Gosub, AddThirtyMinuteTasks
    }

    SetTimer, CheckForNewTasks, -1000

Return

AddOneMinuteTasks:
Return

AddFiveMinuteTasks:
    ; Check if any seeds are selected
    anySeedsSelected := false
    for i, item in seeds {
        IniRead, checked, %iniFile%, Seeds, Seed%i%, 0
        if (checked = "1" || checked = 1) {
            anySeedsSelected := true
            break
        }
    }
    if (anySeedsSelected) {
        AddTask("SeedShopLabel")
    }

    ; Check if any gears are selected (by reading config.ini where SaveGears writes them)
    anyGearsSelected := false
    for i, item in gears {
        IniRead, checked, %iniFile%, Gears, Gear%i%, 0
        if (checked = "1" || checked = 1) {
            anyGearsSelected := true
            break
        }
    }
    if (anyGearsSelected) {
        AddTask("GearShopLabel")
    }

    ; Check if any props are selected
    anyPropsSelected := false
    for i, item in props {
        IniRead, checked, %iniFile%, Props, Prop%i%, 0
        if (checked = "1" || checked = 1) {
            anyPropsSelected := true
            break
        }
    }
    if (anyPropsSelected) {
        AddTask("PropsShoplabel")
    }
    
Return

AddFifteenMinuteTasks:
Return

AddThirtyMinuteTasks:
    ; Check if auto sell plants is on
    if (AutoSellPlants) {
        AddTask("AutoSellPlantsLabel")
    }
Return

; Action Labels

ClearTooltip:
    Tooltip,
Return

AutoHarvestTimer:
    HarvestNow := true
Return

SeedShopLabel:
    SetStatus("Buying Seeds")
    ClickRelative(720, 120, 1)
    Sleep, 1000
    ClickRelative(0.5, 0.5)
    Sleep, 1000
    Send, {e}
    Sleep, 5000
    if PixelColorFound(0x67D147, 514, 200, 1420, 300, 10) {
        SetStatus("Seed Shop Opened")
        Sleep, 1000
        BuyFromShop("Seeds")
        SetStatus("Seeds Completed")
        Sleep, 1000
        ClickRelative(1370, 240, 1)
        Sleep, 1000
        CloseRobuxPrompt()
    } else {
        SetStatus("ERROR: Seed Shop Not Opening")
        global ERRORS += 1
        Sleep, 1000
    }
Return


GearShopLabel:
    SetStatus("Buying Gears")
    ClickRelative(720, 120, 1)
    Sleep, 1000
    ClickRelative(0.5, 0.5)
    Sleep, 2500
    if PixelColorFound(0x67D147, 514, 200, 1420, 300, 10) {
        SetStatus("Alignment Incorrect :(")
        global NeedsAlignment := true
        ClickRelative(1370, 240, 1)
        Sleep, 1000
        Walk("s", 12)
        Send, {a}
        Walk("a", 12)
    } else {
        Walk("d", 21)
    }
    Send, {e}
    Sleep, 5000
    if PixelColorFound(0x00CAFF, 514, 200, 1420, 300, 10) {
        SetStatus("Gear Shop Opened")
        Sleep, 1000
        BuyFromShop("Gears")
        SetStatus("Gear Completed")
        Sleep, 1000
        ClickRelative(1370, 240, 1)
        Sleep, 1000
        CloseRobuxPrompt()
    } else {
        SetStatus("ERROR: Gear Shop Not Opening")
        global ERRORS += 1
        Sleep, 1000
    }
Return

PropsShopLabel:
    SetStatus("Buying Props")
    ClickRelative(720, 120, 1)
    Sleep, 1000
    ClickRelative(0.5, 0.5)
    Sleep, 2500
    if PixelColorFound(0x67D147, 514, 200, 1420, 300, 10) {
        SetStatus("Alignment Incorrect :(")
        global NeedsAlignment := true
        ClickRelative(1370, 240, 1)
        Sleep, 1000
        Walk("s", 31)
        Send, {a}
        Walk("a", 9)
    } else {
        Walk("d", 21)
        Walk("w", 21)
    }
    Send, {e}
    Sleep, 5000
    if PixelColorFound(0xFF9FBA, 514, 200, 1420, 300, 10) {
        SetStatus("Props Shop Opened")
        Sleep, 1000
        BuyFromShop("Props")
        SetStatus("Props Completed")
        Sleep, 1000
        ClickRelative(1370, 240, 1)
        Sleep, 1000
        CloseRobuxPrompt()
    } else {
        SetStatus("ERROR: Props Shop Not Opening")
        global ERRORS += 1
        Sleep, 1000
    }
Return

AutoAlignCameraLabel:
    ; First zoom alignment
    Loop, 25 {
        Send, {WheelUp}
        Sleep, 30
    }
    Sleep, 1000
    Loop, 6 {
        Send, {WheelDown}
        Sleep, 30
    }
    Sleep, 1000

    ; Next, put the camera into a top-down view
    ClickRelative(0.5, .4)
    Sleep, 500
    Click, Right, Down
    Sleep, 250
    ClickRelative(0.5, 0.8)
    Sleep, 250
    Click, Right, Up
    Sleep, 1000

    ; Last align the camera through the shops
    IniRead, AutoAlignCamera, config.ini, Settings, AutoAlignCamera
    if (AutoAlignCamera) {
        global CameraChanged := true
        SetCameraMode(3)

        ; Teleport to shops
        UINavigation("UUUUUUUUUUUUUUUUUUULLLLLLLLLLLLLLLURRRRERRELLERRELLERRELLERRELLERRELLERRELLERRE")
        Sleep, 1000
        ; Chance camera back
        SetCameraMode(1)

        RotateCamera(6)
    }

Return

AutoHarvestLabel:
    global GardenSize, CameraChanged, MoveSpeed

    if (CameraChanged) {
        SetStatus("Reconnecting to Reset Camera")
        Sleep, 1000
        ReconnectToGame()
    }

    oldMoveSpeed := MoveSpeed

    SetStatus("Harvesting Plants")

    ; Camera should be good now
    GoToGarden(1)
    Sleep, 1000

    ; First zoom alignment
    Loop, 25 {
        Send, {WheelUp}
        Sleep, 30
    }
    Sleep, 1000
    Loop, 50 {
        Send, {WheelDown}
        Sleep, 30
    }
    Sleep, 1000

    ; Next, put the camera into a top-down view
    ClickRelative(0.5, .4)
    Sleep, 500
    Click, Right, Down
    Sleep, 250
    ClickRelative(0.5, 0.8)
    Sleep, 250
    Click, Right, Up
    Sleep, 1000

    ; Collect plants
    Loop, 50 {
        Send, {WheelDown}
        Sleep, 50
    }


    ; left side
    SetStatus("Harvesting Left Side")
    Walk("w", 13)
    Walk("a", 9)
    Harvest()

    Walk("a", 21)
    Harvest()
    
    Walk("a", 24)
    Harvest()

    Walk("w", 12)
    Walk("d", 1)
    Harvest()
    Sleep, 5000

    MoveSpeed := (oldMoveSpeed) + 10

    Loop, %GardenSize% {
        Walk("w", 8)
        Harvest()

        Walk("w", 9)
        Harvest()
    }

    Walk("w", 4)
    Walk("d", 24)
    Harvest()

    Walk("d", 21)
    Harvest()

    ; Right side
    SetStatus("Harvesting Right Side")
    MoveSpeed := oldMoveSpeed

    ; Camera should be good now
    GoToGarden(1)
    Sleep, 1000

    ; First zoom alignment
    Loop, 25 {
        Send, {WheelUp}
        Sleep, 30
    }
    Sleep, 1000
    Loop, 50 {
        Send, {WheelDown}
        Sleep, 30
    }
    Sleep, 1000

    ; Next, put the camera into a top-down view
    ClickRelative(0.5, .4)
    Sleep, 500
    Click, Right, Down
    Sleep, 250
    ClickRelative(0.5, 0.8)
    Sleep, 250
    Click, Right, Up
    Sleep, 1000

    ; Collect plants
    Loop, 50 {
        Send, {WheelDown}
        Sleep, 50
    }

    Walk("w", 13)
    Walk("d", 9)
    Harvest()
    ClickRelative(1260, 380, 1)

    Walk("d", 21)
    Harvest()
    ClickRelative(1260, 380, 1)
    
    Walk("d", 24)
    Harvest()
    ClickRelative(1260, 380, 1)

    Walk("w", 12)
    Walk("a", 1)
    Harvest()
    Sleep, 5000

    MoveSpeed := (oldMoveSpeed) + 10

    Loop, %GardenSize% {
        Walk("w", 8)
        Harvest()

        Walk("w", 9)
        Harvest()
    }

    Walk("w", 4)
    Walk("a", 24)
    Harvest()

    Walk("a", 21)
    Harvest()
    
    ; Middle
    SetStatus("Harvesting Middle")

    GoToGarden(1)
    Sleep, 1000

    ; First zoom alignment
    Loop, 25 {
        Send, {WheelUp}
        Sleep, 30
    }
    Sleep, 1000
    Loop, 50 {
        Send, {WheelDown}
        Sleep, 30
    }
    Sleep, 1000

    ; Next, put the camera into a top-down view
    MoveSpeed := oldMoveSpeed

    ClickRelative(0.5, .4)
    Sleep, 500
    Click, Right, Down
    Sleep, 250
    ClickRelative(0.5, 0.8)
    Sleep, 250
    Click, Right, Up
    Sleep, 1000

    ; Collect plants
    Loop, 50 {
        Send, {WheelDown}
        Sleep, 50
    }

    Walk("w", 17)
    Harvest()
    Sleep, 5000

    MoveSpeed := (oldMoveSpeed + 10)

    Loop, %GardenSize% {
        Walk("w", 8)
        Harvest()

        Walk("w", 9)
        Harvest()
    }

    global NeedsAlignment := true
    MoveSpeed := oldMoveSpeed

    ; Restart auto harvest timer
    ; Record last harvest time (wall-clock in A_Now format)
    IniWrite, %A_Now%, %iniFile%, Harvest, LastHarvest
    HarvestNow := False
    SetTimer, AutoHarvestTimer, % (AutoHarvest ? HarvestTime * 60000 : "Off")
Return

AutoSellPlantsLabel:
    UINavigation("UUUUUUUUUUUUUUUUUUUUUUUULLLLLLLLLLLLLLLLLLLLLLURRRRRRE")
    Sleep, 2500
    Send, {E}
    Sleep, 3000
    ClickRelative(1430, 420, 1)
    Sleep, 3000
Return

F6::
Walk("d", 1000, 500, 0)
Return