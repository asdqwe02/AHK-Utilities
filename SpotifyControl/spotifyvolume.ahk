#Requires AutoHotkey v2.0


global nircmdPath := A_ScriptDir . "\Plugins\nircmdc.exe"
global spotifyIcon := A_ScriptDir . "\Icons\spotify_icon.png"

global spotifyVolume := 20  
global barWidth := 180, barHeight := 6  
global overlayGui, progressBar, volText, hideTimer  

; Initialize volume on script start
InitSpotifyVolume()
CreateVolumeOverlay()  
F13::ChangeSpotifyVolume(-2)  ; Reduce by 2 instead of 5
F14::ChangeSpotifyVolume(2)   ; Increase by 2 instead of 5

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
    global overlayGui, progressBar, volText, hideTimer  

    overlayGui := Gui("+AlwaysOnTop -Caption +ToolWindow +Border")  
    overlayGui.BackColor := "0x2C2C2C"  

    if FileExist(spotifyIcon) {
        overlayGui.Add("Picture", "x10 y5 w22 h23", spotifyIcon)  
    }

    progressBar := overlayGui.Add("Progress", "x40 y14 w" barWidth " h" barHeight " Background0x9F9F9F")  
    progressBar.Opt("+Smooth")  
    DllCall("SendMessage", "Ptr", progressBar.Hwnd, "UInt", 0x409, "Ptr", 0, "UInt", 0x54BB1C)  

    volText := overlayGui.Add("Text", "x" (40 + barWidth + 10) " y4 w40 h24 cWhite Center +0x200", spotifyVolume)
    volText.SetFont("s14 Bold", "Arial")  

    overlayGui.Show("xCenter y90 NoActivate")  
    WinSetTransparent(255, overlayGui)  

    hideTimer := ObjBindMethod(overlayGui, "Hide")  
}

UpdateVolumeOverlay(volume) {
    global overlayGui, progressBar, volText, hideTimer  

    progressBar.Value := volume  
    volText.Text := volume  

    SetTimer(hideTimer, 0)  ; Cancel previous hide timer  
    overlayGui.Show("xCenter y90 NoActivate")  

    SetTimer(hideTimer, -1500)  ; Hide after 1.5s of inactivity  
}

RunWaitOne(command) {
    shell := ComObject("WScript.Shell")
    exec := shell.Exec("cmd /c " command " 2>nul")  
    return Trim(exec.StdOut.ReadAll())
}
