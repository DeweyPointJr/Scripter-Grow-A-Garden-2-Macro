#NoEnv
SplitPath, A_ScriptDir, , parentDir
SetWorkingDir %parentDir%
Sleep, 1000

; Find extracted folder under the parent project directory
newestTime := 0
extractedDir := ""
Loop, Files, %parentDir%\*.*, D
{
    if InStr(A_LoopFileName, "Scripter-Grow-A-Garden-2-Macro") {
        if (A_LoopFileTimeCreated > newestTime) {
            newestTime := A_LoopFileTimeCreated
            extractedDir := A_LoopFileFullPath
        }
    }
}

if (extractedDir != "") {
    ; Move all non-update files up one level
    Loop, Files, %extractedDir%\*.*, F
    {
        if (A_LoopFileName != "update.ahk" && A_LoopFileName != "config.ini") {
            FileMove, %A_LoopFileFullPath%, %parentDir%\%A_LoopFileName%, 1
        }
    }

    ; Move all folders up one level
    Loop, Files, %extractedDir%\*.*, D
    {
        FileMoveDir, %A_LoopFileFullPath%, %parentDir%\%A_LoopFileName%, 1
    }

    ; If there's a new update.ahk, move it to a staging folder
    updateSource := ""
    if FileExist(extractedDir "\update.ahk")
        updateSource := extractedDir "\update.ahk"
    else if FileExist(extractedDir "\Submacros\update.ahk")
        updateSource := extractedDir "\Submacros\update.ahk"

    if (updateSource != "") {
        FileCreateDir, %parentDir%\update_files
        FileMove, %updateSource%, %parentDir%\update_files\update.ahk, 1
    }

    ; Show update log if available
    logFile := extractedDir "\updatelog.txt"
    if !FileExist(logFile)
        logFile := parentDir "\updatelog.txt"

    if FileExist(logFile) {
        FileRead, updateLog, %logFile%
        if (updateLog != "")
            MsgBox, 64, Update Log, %updateLog%
    }

    FileRemoveDir, %extractedDir%, 1
}

; Cleanup
FileDelete, %parentDir%\update.zip

; Relaunch main macro
Run, %parentDir%\Macro.ahk
ExitApp
