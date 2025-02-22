#Requires AutoHotkey v2.0
#Include %A_ScriptDir%\Plugins\GDIp_All.ahk

global nircmdPath := A_ScriptDir . "\Plugins\nircmdc.exe"
global spotifyIcon := A_ScriptDir . "\Icons\spotify_icon.png"

global spotifyVolume := 20  
global barWidth := 150, barHeight := 6  
global overlayGui, volText, hideTimer, hbm, hdc, pGraphics, pBitmap, progressPic
global bgColor := 0xFF9F9F9F, fillColor := 0xFF1CBB54  
global rounding := barHeight // 2  

; GUI Positioning
global guiX := "xCenter", guiY := "y90"
global iconX := 10, iconY := 5, iconW := 22, iconH := 23
global progressX := 40, progressY := 12
global textX := progressX + barWidth + 10, textY := 4, textW := 40, textH := 24

global fontSize := "s14", fontStyle := "Bold", fontName := "Arial"

global transparency := 255, hideDelay := 1500

; Initialize volume on script start
InitSpotifyVolume()
CreateVolumeOverlay()  
F13::ChangeSpotifyVolume(-2)  
F14::ChangeSpotifyVolume(2)   

ChangeSpotifyVolume(step) {
    global spotifyVolume
    spotifyVolume := Clamp(spotifyVolume + step, 0, 100)
    Run(nircmdPath " setappvolume spotify.exe " spotifyVolume/100.0, , "Hide")
    UpdateVolumeOverlay(spotifyVolume)
}

InitSpotifyVolume() {
    global spotifyVolume
    volume := GetSpotifyVolume()
    if volume is number
        spotifyVolume := volume
}

GetSpotifyVolume() {
    try {
        output := RunWaitOne(nircmdPath " getappvolume spotify.exe")
        return output ? Round(output * 100) : spotifyVolume  
    } catch {
        return spotifyVolume
    }
}

Clamp(value, min, max) {
    return value < min ? min : (value > max ? max : value)
}

CreateVolumeOverlay() {
    global overlayGui, volText, hideTimer, hbm, hdc, pGraphics, pBitmap, progressPic  
    
    overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")  
    overlayGui.BackColor := "0x2C2C2C"  

    if FileExist(spotifyIcon) {
        overlayGui.Add("Picture", Format("x{} y{} w{} h{}", iconX, iconY, iconW, iconH), spotifyIcon)  
    }

    if !Gdip_Startup() {
        MsgBox("Failed to initialize GDI+!")
        ExitApp()
    }

    hbm := CreateDIBSection(barWidth, barHeight)
    hdc := CreateCompatibleDC()
    SelectObject(hdc, hbm)
    pBitmap := Gdip_CreateBitmapFromHBITMAP(hbm)
    pGraphics := Gdip_GraphicsFromImage(pBitmap)
    Gdip_SetSmoothingMode(pGraphics, 4)  ; Higher quality anti-aliasing

    progressPic := overlayGui.Add("Picture", Format("x{} y{} w{} h{}", progressX, progressY, barWidth, barHeight))
    
    volText := overlayGui.Add("Text", Format("x{} y{} w{} h{} cWhite Center +0x200", textX, textY, textW, textH), spotifyVolume)
    volText.SetFont(Format("{} {}", fontSize, fontStyle), fontName)  

    overlayGui.Show(Format("{} {} NoActivate", guiX, guiY))  
    WinSetTransparent(transparency, overlayGui)  

    hideTimer := ObjBindMethod(overlayGui, "Hide")  

    UpdateVolumeOverlay(spotifyVolume)  
}

UpdateVolumeOverlay(volume) {
  global overlayGui, volText, hideTimer, hdc, pGraphics, pBitmap, hbm, barWidth, barHeight, rounding, bgColor, fillColor, progressPic  

    ; Ensure the background is fully transparent
    Gdip_GraphicsClear(pGraphics, 0x00000000)

    ; Create brushes
    hBgBrush := Gdip_BrushCreateSolid(bgColor) 
    hFillBrush := Gdip_BrushCreateSolid(fillColor)

    ; Ensure proper rounding calculation
    effectiveRounding := Max(0, Min(rounding, Floor(barWidth) // 2))  ; Prevent invalid values

    ; Draw background with improved transparency and rounded edges
    Gdip_FillRoundedRectangle(pGraphics, hBgBrush, 0, 0, barWidth, barHeight, effectiveRounding)

    ; Calculate filled width
    fillWidth := (volume / 100) * barWidth
    effectiveFillRounding := Max(0, Min(rounding, Floor(fillWidth) // 2))  ; Keep smooth edges

    ; Draw filled section with better rounding
    if fillWidth > 2 * effectiveFillRounding {
        Gdip_FillRoundedRectangle(pGraphics, hFillBrush, 0, 0, fillWidth, barHeight, effectiveFillRounding)
    } else {
        Gdip_FillEllipse(pGraphics, hFillBrush, 0, 0, fillWidth, barHeight)  ; Use ellipse if very small
    }

    ; Update GUI with new image
    hbmNew := Gdip_CreateHBITMAPFromBitmap(pBitmap)
    progressPic.Value := "HBITMAP:*" hbmNew  

    ; Cleanup brushes
    Gdip_DeleteBrush(hBgBrush)
    Gdip_DeleteBrush(hFillBrush)
    DeleteObject(hbmNew)

    ; Update volume text
    volText.Text := volume  

    ; Reset timer for hiding
    SetTimer(hideTimer, 0)  
    overlayGui.Show("xCenter y90 NoActivate")  
    SetTimer(hideTimer, -1500)  
}

RunWaitOne(command) {
    shell := ComObject("WScript.Shell")
    exec := shell.Exec("cmd /c " command " 2>nul")  
    return Trim(exec.StdOut.ReadAll())
}
