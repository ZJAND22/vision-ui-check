# check.ps1 — 本地自检（等价于 CI 的检查项，不需要 workflow 权限）
# 用法: .\check.ps1
$ErrorActionPreference = "Stop"
$fail = 0

Write-Host "[1/3] Python 语法检查 ..." -ForegroundColor Cyan
if (Get-Command python -ErrorAction SilentlyContinue) {
    python -m py_compile shot_review.py
    if ($LASTEXITCODE -ne 0) { $fail++ }
} else {
    Write-Host "  跳过：没装 python" -ForegroundColor Yellow
}

Write-Host "[2/3] PowerShell 语法解析 ..." -ForegroundColor Cyan
foreach ($f in @("capture_window.ps1", "ui_shot.ps1")) {
    $errors = $null
    [System.Management.Automation.Language.Parser]::ParseFile((Resolve-Path $f), [ref]$null, [ref]$errors) | Out-Null
    if ($errors.Count -gt 0) {
        Write-Host ("  " + $f + " 解析错误：" + ($errors -join "; ")) -ForegroundColor Red
        $fail++
    } else {
        Write-Host ("  " + $f + " OK") -ForegroundColor Green
    }
}

Write-Host "[3/3] 示例截图冒烟测试 ..." -ForegroundColor Cyan
if (Get-Command python -ErrorAction SilentlyContinue) {
    python shot_review.py examples/prologue.png --out-dir examples/_out | Out-Null
    if ($LASTEXITCODE -ne 0) { $fail++ } else { Write-Host "  审查脚本 OK" -ForegroundColor Green }
}

if ($fail -gt 0) { Write-Host "`n检查未通过（$fail 项）" -ForegroundColor Red; exit 1 }
Write-Host "`n全部通过 ✅" -ForegroundColor Green
