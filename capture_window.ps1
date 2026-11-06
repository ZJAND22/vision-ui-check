# capture_window.ps1 — 抓取任意 Windows 程序窗口（含 D3D/IMGUI）为客户区 PNG
#
# 用法:
#   .\capture_window.ps1 -ExePath "C:\path\Game.exe" -Out ".\shot.png"
#   .\capture_window.ps1 -ExePath "...\Game.exe" -Out ".\shot.png" -GameArgs "-prologue"
#   .\capture_window.ps1 -ProcessName Game -Out ".\shot.png"      # 进程已在运行
param(
    [string]$ExePath = "",
    [string]$ProcessName = "",
    [string]$Out = ".\shot.png",
    [string]$GameArgs = "",
    [int]$WaitSeconds = 12,
    [int]$ClientWidth = 1280,
    [int]$ClientHeight = 720,
    [switch]$KeepRunning
)

$ErrorActionPreference = "Stop"
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32Cap {
    [DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
    [DllImport("user32.dll")] public static extern IntPtr FindWindow(string cls, string title);
    [DllImport("user32.dll")] public static extern bool GetClientRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr h, out RECT r);
    [DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr h);
    [DllImport("user32.dll")] public static extern bool ShowWindow(IntPtr h, int cmd);
    [DllImport("user32.dll")] public static extern bool SetWindowPos(IntPtr h, IntPtr after, int x, int y, int cx, int cy, uint flags);
    [DllImport("user32.dll")] public static extern bool PrintWindow(IntPtr h, IntPtr hdc, uint flags);
    [DllImport("gdi32.dll")] public static extern bool BitBlt(IntPtr hdcDst, int x, int y, int w, int h, IntPtr hdcSrc, int sx, int sy, int rop);
    [DllImport("user32.dll")] public static extern IntPtr GetDC(IntPtr h);
    [DllImport("user32.dll")] public static extern int ReleaseDC(IntPtr h, IntPtr dc);
    [StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
}
"@

function Grab([int]$w, [int]$h, [IntPtr]$hwnd) {
    $bmp = New-Object System.Drawing.Bitmap $w, $h
    $g = [System.Drawing.Graphics]::FromImage($bmp)
    $hdcDst = $g.GetHdc()
    $ok = [Win32Cap]::PrintWindow($hwnd, $hdcDst, 2)   # PW_RENDERFULLCONTENT
    if (-not $ok) {
        $hdcSrc = [Win32Cap]::GetDC($hwnd)
        [Win32Cap]::BitBlt($hdcDst, 0, 0, $w, $h, $hdcSrc, 0, 0, 0x00CC0020) | Out-Null
        [Win32Cap]::ReleaseDC($hwnd, $hdcSrc) | Out-Null
    }
    $g.ReleaseHdc($hdcDst)
    $g.Dispose()
    return $bmp
}

function FrameStd($bmp) {
    $vals = New-Object System.Collections.Generic.List[double]
    $sx = [Math]::Max(1, [int]($bmp.Width / 32)); $sy = [Math]::Max(1, [int]($bmp.Height / 24))
    for ($y = 0; $y -lt $bmp.Height; $y += $sy) {
        for ($x = 0; $x -lt $bmp.Width; $x += $sx) {
            $c = $bmp.GetPixel($x, $y)
            $vals.Add(($c.R + $c.G + $c.B) / 3.0)
        }
    }
    $avg = ($vals | Measure-Object -Average).Average
    $sum = 0.0
    foreach ($v in $vals) { $sum += ($v - $avg) * ($v - $avg) }
    return [Math]::Sqrt($sum / $vals.Count)
}

# --- 启动或定位进程 ---
$started = $false
$proc = $null
if ($ProcessName) { $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1 }
if (-not $proc) {
    if (-not $ExePath -or -not (Test-Path $ExePath)) { throw "找不到 exe：$ExePath（或改用 -ProcessName）" }
    $argStr = "-screen-fullscreen 0 -screen-width $ClientWidth -screen-height $ClientHeight"
    if ($GameArgs) { $argStr = "$argStr $GameArgs" }
    Start-Process -FilePath $ExePath -ArgumentList $argStr | Out-Null
    $started = $true
    Start-Sleep -Seconds $WaitSeconds
    if (-not $ProcessName) { $ProcessName = [System.IO.Path]::GetFileNameWithoutExtension($ExePath) }
    $proc = Get-Process -Name $ProcessName -ErrorAction SilentlyContinue | Select-Object -First 1
}
if (-not $proc) { throw "进程未启动：$ProcessName" }

$hwnd = $proc.MainWindowHandle
for ($i = 0; $i -lt 30 -and $hwnd -eq [IntPtr]::Zero; $i++) {
    Start-Sleep -Milliseconds 500
    $proc.Refresh(); $hwnd = $proc.MainWindowHandle
}
if ($hwnd -eq [IntPtr]::Zero) { throw "没有主窗口" }

[Win32Cap]::SetProcessDPIAware() | Out-Null
[Win32Cap]::ShowWindow($hwnd, 9) | Out-Null          # SW_RESTORE
[Win32Cap]::SetForegroundWindow($hwnd) | Out-Null
Start-Sleep -Milliseconds 800

# --- 把客户区调成指定尺寸（按边框差值补偿） ---
$wr = New-Object Win32Cap+RECT; $cr = New-Object Win32Cap+RECT
[Win32Cap]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
[Win32Cap]::GetClientRect($hwnd, [ref]$cr) | Out-Null
$dW = ($wr.Right - $wr.Left) - ($cr.Right - $cr.Left)
$dH = ($wr.Bottom - $wr.Top) - ($cr.Bottom - $cr.Top)
if ($ClientWidth -gt 0 -and $ClientHeight -gt 0) {
    [Win32Cap]::SetWindowPos($hwnd, [IntPtr]::Zero, 60, 40, $ClientWidth + $dW, $ClientHeight + $dH, 0x0040) | Out-Null
    Start-Sleep -Milliseconds 1200
}

# --- 重新读取实际窗口/客户区尺寸（SetWindowPos 之后） ---
[Win32Cap]::GetWindowRect($hwnd, [ref]$wr) | Out-Null
[Win32Cap]::GetClientRect($hwnd, [ref]$cr) | Out-Null
$winW = $wr.Right - $wr.Left
$winH = $wr.Bottom - $wr.Top
$cliW = $cr.Right - $cr.Left
$cliH = $cr.Bottom - $cr.Top
$barH = $winH - $cliH
if ($winW -le 0 -or $winH -le 0) { throw "窗口尺寸异常：$winW x $winH" }

# --- 等画面渲染就绪（避免抓到白屏） ---
$bmp = $null
for ($try = 0; $try -lt 25; $try++) {
    $bmp = Grab $winW $winH $hwnd
    $sd = FrameStd $bmp
    if ($sd -gt 12) { break }
    $bmp.Dispose(); $bmp = $null
    Start-Sleep -Milliseconds 900
}
if ($null -eq $bmp) {
    if ($started) { Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue }
    throw "画面一直空白（可能未渲染完成或被遮挡）"
}

# --- 裁掉标题栏/边框，只留客户区 ---
if ($barH -gt 0 -and $barH -lt ($winH - 40) -and $cliW -gt 100 -and $cliH -gt 100) {
    $crop = New-Object System.Drawing.Bitmap $cliW, $cliH
    $gc = [System.Drawing.Graphics]::FromImage($crop)
    $gc.DrawImage($bmp, (New-Object System.Drawing.Rectangle 0, 0, $cliW, $cliH), (New-Object System.Drawing.Rectangle 0, $barH, $cliW, $cliH), [System.Drawing.GraphicsUnit]::Pixel)
    $gc.Dispose(); $bmp.Dispose(); $bmp = $crop
}

$dir = Split-Path -Parent $Out
if ($dir -and -not (Test-Path $dir)) { New-Item -ItemType Directory -Force -Path $dir | Out-Null }
$capW = $bmp.Width; $capH = $bmp.Height
$bmp.Save($Out, [System.Drawing.Imaging.ImageFormat]::Png)
$sd = FrameStd $bmp
$bmp.Dispose()
Write-Output ("captured {0}x{1} std={2} -> {3}" -f $capW, $capH, [Math]::Round($sd, 1), $Out)

if ($started -and -not $KeepRunning) {
    Start-Sleep -Milliseconds 300
    Stop-Process -Id $proc.Id -Force -ErrorAction SilentlyContinue
}


