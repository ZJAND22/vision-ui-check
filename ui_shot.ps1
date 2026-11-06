# ui_shot.ps1 — 一键：启动游戏 → 截图 → 生成审查图 + 指标报告
#
# 用法:
#   .\ui_shot.ps1 -ExePath "C:\path\Game.exe"
#   .\ui_shot.ps1 -ExePath "...\Game.exe" -GameArgs "-prologue" -Name prologue
#   .\ui_shot.ps1 -ExePath "...\Game.exe" -OutDir ".\shots" -Python "python"
param(
    [Parameter(Mandatory = $true)][string]$ExePath,
    [string]$OutDir = ".\shots",
    [string]$GameArgs = "",
    [string]$Name = "",
    [int]$WaitSeconds = 14,
    [string]$Python = "python",
    [int]$ClientWidth = 1280,
    [int]$ClientHeight = 720
)

$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
if (-not (Test-Path $OutDir)) { New-Item -ItemType Directory -Force -Path $OutDir | Out-Null }

if ([string]::IsNullOrWhiteSpace($Name)) {
    if ($GameArgs -match "prologue") { $Name = "prologue" }
    elseif ($GameArgs -match "level") { $Name = "level" }
    else { $Name = "ui" }
}
$stamp = Get-Date -Format "HHmmss"
$png = Join-Path $OutDir ("ui_{0}_{1}.png" -f $Name, $stamp)

$cap = Join-Path $root "capture_window.ps1"
$args1 = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $cap,
           "-ExePath", $ExePath, "-Out", $png, "-WaitSeconds", $WaitSeconds,
           "-ClientWidth", $ClientWidth, "-ClientHeight", $ClientHeight)
if ($GameArgs) { $args1 += @("-GameArgs", $GameArgs) }
& powershell @args1
if ($LASTEXITCODE -ne 0 -or -not (Test-Path $png)) { throw "截图失败：$png" }

$review = Join-Path $root "shot_review.py"
& $Python $review $png --out-dir $OutDir

Write-Output "SHOT=$png"
