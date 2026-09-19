# browser-use skill installer for Windows (PowerShell 5.1 or 7).
# Installs the four browser tools, registers the Chrome DevTools MCP server for Claude Code,
# and copies the skill into ~/.claude/skills. Safe to run again.
#
#   .\install.ps1               tools + MCP + skill
#   .\install.ps1 -SkipSkill    tools + MCP only (use this if you installed the skill as a plugin)
#   .\install.ps1 -SkipMcp      do not register the Chrome DevTools MCP server

param(
    [switch]$SkipSkill,
    [switch]$SkipMcp
)

# Not 'Stop': in Windows PowerShell 5.1 that turns any stderr line from npm or claude into a fatal error.
# Failures are checked through $LASTEXITCODE instead.
$ErrorActionPreference = 'Continue'

function Step($msg) { Write-Host "`n== $msg" -ForegroundColor Cyan }
function Ok($msg)   { Write-Host "   ok: $msg" -ForegroundColor Green }
function Warn($msg) { Write-Host "   warning: $msg" -ForegroundColor Yellow }

Step 'Checking Node.js'
if (-not (Get-Command node -ErrorAction SilentlyContinue)) {
    throw 'Node.js 18 or newer is required. Install it from https://nodejs.org and run this script again.'
}
$nodeMajor = [int]((node -v).TrimStart('v').Split('.')[0])
if ($nodeMajor -lt 18) { throw "Node.js 18 or newer is required (found $(node -v))." }
Ok "node $(node -v)"

Step 'Installing the browser CLIs'
# dev-browser 1.0 ships no Windows build yet; 0.2.9 does. Keep it pinned on Windows.
npm install -g agent-browser '@playwright/cli@latest' 'chrome-devtools-mcp@latest' 'dev-browser@0.2.9'
if ($LASTEXITCODE -ne 0) { throw 'npm install failed.' }
Ok 'agent-browser, playwright-cli, chrome-devtools-mcp, dev-browser 0.2.9'

Step 'Downloading browsers (about 300 MB, can be slow)'
# The default download timeout is short and fails on slow lines; give it ten minutes.
$env:PLAYWRIGHT_DOWNLOAD_CONNECTION_TIMEOUT = '600000'
foreach ($tool in @('dev-browser', 'agent-browser')) {
    $done = $false
    for ($i = 1; $i -le 3 -and -not $done; $i++) {
        & $tool install
        if ($LASTEXITCODE -eq 0) { $done = $true } else { Warn "$tool install failed (attempt $i of 3)" }
    }
    if ($done) { Ok "$tool browser ready" } else { Warn "$tool could not download its browser. Run '$tool install' again later." }
}

if (-not $SkipMcp) {
    Step 'Registering the Chrome DevTools MCP server'
    if (Get-Command claude -ErrorAction SilentlyContinue) {
        $existing = cmd /c "claude mcp get chrome-devtools 2>nul"
        if ($LASTEXITCODE -eq 0 -and $existing) {
            Ok 'already registered'
        } else {
            claude mcp add chrome-devtools --scope user -- cmd /c chrome-devtools-mcp
            if ($LASTEXITCODE -eq 0) { Ok 'registered at user scope as chrome-devtools' } else { Warn 'registration failed; run the claude mcp add command above by hand' }
        }
    } else {
        Warn "Claude Code CLI not found. Register it later with: claude mcp add chrome-devtools --scope user -- cmd /c chrome-devtools-mcp"
    }
}

if (-not $SkipSkill) {
    Step 'Installing the skill'
    $src = Join-Path $PSScriptRoot 'plugins\browser-use\skills\browser-use\SKILL.md'
    $dst = Join-Path $HOME '.claude\skills\browser-use'
    New-Item -ItemType Directory -Force -Path $dst | Out-Null
    Copy-Item -Force $src (Join-Path $dst 'SKILL.md')
    Ok "copied to $dst"
}

Step 'Done'
Write-Host '   Start a new Claude Code session so the skill and the MCP tools load.'
