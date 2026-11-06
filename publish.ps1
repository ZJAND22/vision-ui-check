# publish.ps1 — 一键把本仓库发布到 GitHub（需要先 gh auth login）
# 用法: .\publish.ps1 [-RepoName vision-ui-check] [-Private]
param(
    [string]$RepoName = "vision-ui-check",
    [switch]$Private,
    [string]$GhPath = "C:\Program Files\GitHub CLI\gh.exe"
)

$ErrorActionPreference = "Stop"
$env:HTTPS_PROXY = "http://127.0.0.1:7890"
$env:HTTP_PROXY = "http://127.0.0.1:7890"

if (-not (Test-Path $GhPath)) { throw "找不到 gh：$GhPath" }

& $GhPath auth status 2>&1 | Out-Host
if ($LASTEXITCODE -ne 0) {
    Write-Host "`n尚未登录，请先运行：" -ForegroundColor Yellow
    Write-Host '  $env:HTTPS_PROXY="http://127.0.0.1:7890"; $env:HTTP_PROXY=$env:HTTPS_PROXY' -ForegroundColor Cyan
    Write-Host "  & `"$GhPath`" auth login --web" -ForegroundColor Cyan
    throw "未登录 GitHub"
}

$vis = if ($Private) { "--private" } else { "--public" }
$exists = & $GhPath repo view $RepoName 2>$null
if ($LASTEXITCODE -ne 0) {
    Write-Host "创建仓库 $RepoName ..." -ForegroundColor Cyan
    & $GhPath repo create $RepoName $vis --source . --push
} else {
    Write-Host "仓库已存在，直接推送 ..." -ForegroundColor Cyan
    git remote remove origin 2>$null
    $url = (& $GhPath repo view $RepoName --json sshUrl -q .sshUrl)
    git remote add origin "https://github.com/$((& $GhPath api user -q .login))/$RepoName.git"
    git push -u origin HEAD
}

Write-Host "创建 v0.1.0 Release ..." -ForegroundColor Cyan
& $GhPath release create v0.1.0 --title "v0.1.0 — 让 AI 看见 UI 的工具包" --notes-file RELEASE.md

& $GhPath repo view $RepoName --web
