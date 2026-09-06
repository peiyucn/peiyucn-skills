#Requires -Version 5.1
<#
.SYNOPSIS
obscura serve 常驻服务管理（CDP WebSocket 服务，Puppeteer/Playwright 可连）。

用法:
  .\obscura-serve.ps1 -Action start [-Port 9223] [-Workers 1] [-Local] [-Stealth]
  .\obscura-serve.ps1 -Action status
  .\obscura-serve.ps1 -Action stop
  .\obscura-serve.ps1 -Action mcp-start [-McpPort 8080] [-Stealth]   # 有状态 MCP 服务（会话保持，agent 首选）
  .\obscura-serve.ps1 -Action mcp-status
  .\obscura-serve.ps1 -Action mcp-stop

默认端口 9223（本机 9222 被 msedgewebview2 调试端口占用，勿碰）。
注意：serve 的 CDP 会话在客户端断开时页面会重置（实测 v0.2.2），
多步交互/会话连续性请用 mcp-start（MCP 工具调用之间页面保持存活）。

说明:
  start  后台启动（Start-Process 脱离当前 shell），PID 写入 ~/.obscura/run/obscura-serve.pid
  status 检查 PID 存活 + /json/version HTTP 探测
  stop   只杀 PID 文件记录的 obscura 进程（核验进程名，绝不批量按名杀）
  -Local  加 --allow-private-network（默认 SSRF 拦截内网，访问 localhost/LAN 才用）
  -Stealth 反指纹 + 追踪域名拦截

输出格式: SERVE_STATUS=<ready|running|degraded|starting|stopped|already-stopped> ...
#>
param(
    [Parameter(Mandatory = $true)]
    [ValidateSet('start', 'stop', 'status', 'mcp-start', 'mcp-stop', 'mcp-status')]
    [string]$Action,
    [int]$Port = 9223,
    [int]$McpPort = 8080,
    [int]$Workers = 1,
    [switch]$Local,
    [switch]$Stealth
)

$ErrorActionPreference = 'Stop'

$exe = Join-Path $env:USERPROFILE '.obscura\bin\obscura.exe'
$runDir = Join-Path $env:USERPROFILE '.obscura\run'
$logDir = Join-Path $env:USERPROFILE '.obscura\logs'
$pidFile = Join-Path $runDir 'obscura-serve.pid'
$mcpPidFile = Join-Path $runDir 'obscura-mcp.pid'

function Test-ObscuraProcess([int]$procId) {
    if ($procId -le 0) { return $false }
    $p = Get-Process -Id $procId -ErrorAction SilentlyContinue
    return ($null -ne $p -and $p.ProcessName -eq 'obscura')
}

function Read-PidFileAt([string]$path) {
    if (Test-Path $path) {
        $raw = (Get-Content $path -Raw).Trim()
        if ($raw -match '^\d+$') { return [int]$raw }
    }
    return 0
}

switch ($Action) {
    'status' {
        $procId = Read-PidFileAt $pidFile
        if ($procId -gt 0 -and (Test-ObscuraProcess $procId)) {
            try {
                $v = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/version" -TimeoutSec 3
                Write-Host "SERVE_STATUS=ready pid=$procId port=$Port browser=$($v.Browser) ws=ws://127.0.0.1:$Port"
            } catch {
                Write-Host "SERVE_STATUS=degraded pid=$procId port=$Port (进程在但 /json/version 无响应，看 $logDir)"
            }
        } elseif ($procId -gt 0) {
            Write-Host "SERVE_STATUS=stopped (PID 文件残留: $procId，进程已不在)"
        } else {
            Write-Host "SERVE_STATUS=stopped (无 PID 文件)"
        }
    }

    'start' {
        $procId = Read-PidFileAt $pidFile
        if ($procId -gt 0 -and (Test-ObscuraProcess $procId)) {
            Write-Host "SERVE_STATUS=running pid=$procId port=$Port (已在运行，先 stop 才能改参数)"
            exit 0
        }
        if (-not (Test-Path $exe)) { throw "未安装 obscura（$exe 不存在），先跑 install-obscura.ps1" }

        New-Item -ItemType Directory -Force -Path $runDir, $logDir | Out-Null
        $args = @('serve', '--port', "$Port", '--workers', "$Workers")
        if ($Local) { $args += '--allow-private-network' }
        if ($Stealth) { $args += '--stealth' }

        $p = Start-Process -FilePath $exe -ArgumentList $args -WindowStyle Hidden `
            -RedirectStandardOutput (Join-Path $logDir 'serve.out.log') `
            -RedirectStandardError (Join-Path $logDir 'serve.err.log') -PassThru
        Set-Content -Path $pidFile -Value $p.Id

        Start-Sleep -Seconds 2
        if (-not (Test-ObscuraProcess $p.Id)) {
            $errTail = (Get-Content (Join-Path $logDir 'serve.err.log') -Tail 5 -ErrorAction SilentlyContinue) -join ' | '
            if (Test-Path $pidFile) { Remove-Item $pidFile -Force }
            Write-Host "SERVE_STATUS=failed pid=$($p.Id) (启动即退出，多半端口被占，换 -Port 重试；错误: $errTail)"
            exit 1
        }
        try {
            $v = Invoke-RestMethod -Uri "http://127.0.0.1:$Port/json/version" -TimeoutSec 5
            Write-Host "SERVE_STATUS=ready pid=$($p.Id) port=$Port browser=$($v.Browser) ws=ws://127.0.0.1:$Port"
        } catch {
            Write-Host "SERVE_STATUS=starting pid=$($p.Id) port=$Port (几秒后再 status；日志: $logDir)"
        }
    }

    'stop' {
        $procId = Read-PidFileAt $pidFile
        if ($procId -gt 0 -and (Test-ObscuraProcess $procId)) {
            Stop-Process -Id $procId
            Start-Sleep -Milliseconds 500
            Write-Host "SERVE_STATUS=stopped pid=$procId"
        } else {
            Write-Host "SERVE_STATUS=already-stopped (PID 文件残留已清理)"
        }
        if (Test-Path $pidFile) { Remove-Item $pidFile -Force }
    }

    'mcp-start' {
        $mProcId = Read-PidFileAt $mcpPidFile
        if ($mProcId -gt 0 -and (Test-ObscuraProcess $mProcId)) {
            Write-Host "MCP_STATUS=running pid=$mProcId port=$McpPort (先 mcp-stop 才能改参数)"
            exit 0
        }
        if (-not (Test-Path $exe)) { throw "未安装 obscura（$exe 不存在），先跑 install-obscura.ps1" }
        New-Item -ItemType Directory -Force -Path $runDir, $logDir | Out-Null
        $margs = @('mcp', '--http', '--port', "$McpPort")
        if ($Stealth) { $margs += '--stealth' }
        $mp = Start-Process -FilePath $exe -ArgumentList $margs -WindowStyle Hidden `
            -RedirectStandardOutput (Join-Path $logDir 'mcp.out.log') `
            -RedirectStandardError (Join-Path $logDir 'mcp.err.log') -PassThru
        Set-Content -Path $mcpPidFile -Value $mp.Id
        Start-Sleep -Seconds 2
        if (-not (Test-ObscuraProcess $mp.Id)) {
            $errTail = (Get-Content (Join-Path $logDir 'mcp.err.log') -Tail 5 -ErrorAction SilentlyContinue) -join ' | '
            if (Test-Path $mcpPidFile) { Remove-Item $mcpPidFile -Force }
            Write-Host "MCP_STATUS=failed pid=$($mp.Id) (错误: $errTail)"
            exit 1
        }
        $listen = Get-NetTCPConnection -LocalPort $McpPort -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.OwningProcess -eq $mp.Id }
        if ($listen) {
            Write-Host "MCP_STATUS=ready pid=$($mp.Id) port=$McpPort endpoint=http://127.0.0.1:$McpPort/mcp"
        } else {
            Write-Host "MCP_STATUS=starting pid=$($mp.Id) port=$McpPort (几秒后再 mcp-status；日志: $logDir)"
        }
    }

    'mcp-status' {
        $mProcId = Read-PidFileAt $mcpPidFile
        if ($mProcId -gt 0 -and (Test-ObscuraProcess $mProcId)) {
            $listen = Get-NetTCPConnection -LocalPort $McpPort -State Listen -ErrorAction SilentlyContinue | Where-Object { $_.OwningProcess -eq $mProcId }
            if ($listen) { Write-Host "MCP_STATUS=ready pid=$mProcId port=$McpPort endpoint=http://127.0.0.1:$McpPort/mcp" }
            else { Write-Host "MCP_STATUS=degraded pid=$mProcId (进程在但端口未监听，看 $logDir)" }
        } elseif ($mProcId -gt 0) {
            Write-Host "MCP_STATUS=stopped (PID 文件残留: $mProcId)"
        } else {
            Write-Host "MCP_STATUS=stopped (无 PID 文件)"
        }
    }

    'mcp-stop' {
        $mProcId = Read-PidFileAt $mcpPidFile
        if ($mProcId -gt 0 -and (Test-ObscuraProcess $mProcId)) {
            Stop-Process -Id $mProcId
            Start-Sleep -Milliseconds 500
            Write-Host "MCP_STATUS=stopped pid=$mProcId"
        } else {
            Write-Host "MCP_STATUS=already-stopped (PID 文件残留已清理)"
        }
        if (Test-Path $mcpPidFile) { Remove-Item $mcpPidFile -Force }
    }
}
