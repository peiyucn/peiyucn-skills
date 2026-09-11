#Requires -Version 5.1
<#
.SYNOPSIS
安装 / 升级 Obscura（Windows x86_64 官方 release），幂等。

用法:
  .\install-obscura.ps1                     # 已装则跳过
  .\install-obscura.ps1 -Force              # 强制重装最新 release
  .\install-obscura.ps1 -Force -Variant stealth   # 换变体

变体对照（官方 release 资产）:
  render             obscura-x86_64-windows.zip                渲染，无反检测
  stealth            obscura-x86_64-windows-stealth.zip        渲染 + 反检测（含渲染）
  no-render          obscura-x86_64-windows-no-render.zip      纯抓取最轻
  no-render-stealth  obscura-x86_64-windows-no-render-stealth.zip

装到 ~/.obscura/bin/（obscura.exe + obscura-worker.exe）。
#>
param(
    [switch]$Force,
    [ValidateSet('render', 'stealth', 'no-render', 'no-render-stealth')]
    [string]$Variant = 'render'
)

$ErrorActionPreference = 'Stop'

$installDir = Join-Path $env:USERPROFILE '.obscura\bin'
$exe = Join-Path $installDir 'obscura.exe'
$assetName = @{
    render             = 'obscura-x86_64-windows.zip'
    stealth            = 'obscura-x86_64-windows-stealth.zip'
    'no-render'        = 'obscura-x86_64-windows-no-render.zip'
    'no-render-stealth' = 'obscura-x86_64-windows-no-render-stealth.zip'
}[$Variant]

if ((Test-Path $exe) -and -not $Force) {
    Write-Host "INSTALL_STATUS=skipped (obscura.exe 已存在: $exe；-Force 重装)"
    exit 0
}

Write-Host ">> 查询 GitHub 最新 release ..."
$release = Invoke-RestMethod -Uri 'https://api.github.com/repos/h4ckf0r0day/obscura/releases/latest'
$asset = $release.assets | Where-Object { $_.name -eq $assetName }
if (-not $asset) { throw "release $($release.tag_name) 没有资产 $assetName" }
Write-Host ">> 版本 $($release.tag_name)，下载 $assetName ($([math]::Round($asset.size / 1MB, 1)) MB) ..."

$zip = Join-Path $env:TEMP $assetName
try {
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip
} catch {
    Write-Host ">> 直连失败，改走代理 http://127.0.0.1:7897 ..."
    Invoke-WebRequest -Uri $asset.browser_download_url -OutFile $zip -Proxy 'http://127.0.0.1:7897'
}

Write-Host ">> 解压到 $installDir ..."
New-Item -ItemType Directory -Force -Path $installDir | Out-Null
Expand-Archive -Path $zip -DestinationPath $installDir -Force
Remove-Item $zip -Force

if (-not (Test-Path $exe)) { throw "解压后没找到 $exe" }

Write-Host ">> 自检: fetch https://example.com ..."
$check = Join-Path $env:TEMP 'obscura-install-check.txt'
& $exe fetch https://example.com --dump text --output $check --quiet
if (Test-Path $check) {
    Write-Host ("    内容预览: " + ((Get-Content $check -TotalCount 3) -join ' | '))
    Remove-Item $check -Force
} else {
    Write-Host "    警告: 未生成自检文件，手动验证: $exe fetch https://example.com --dump text"
}

Write-Host "INSTALL_STATUS=ok version=$($release.tag_name) variant=$Variant path=$exe"
