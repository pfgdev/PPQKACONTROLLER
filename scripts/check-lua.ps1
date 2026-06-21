$ErrorActionPreference = 'Stop'

$repoRoot = Split-Path -Parent $PSScriptRoot
$luaJit = Get-Command luajit -ErrorAction SilentlyContinue
$luaJitPath = $null

if ($luaJit) {
    $luaJitPath = $luaJit.Source
}
else {
    $defaultLuaJit = Join-Path $env:LOCALAPPDATA 'Programs\LuaJIT\bin\luajit.exe'
    if (Test-Path -LiteralPath $defaultLuaJit) {
        $luaJitPath = $defaultLuaJit
    }
}

if (-not $luaJitPath) {
    throw 'LuaJIT was not found. Install with: winget install DEVCOM.LuaJIT'
}

Push-Location $repoRoot
try {
    & $luaJitPath -e "assert(loadfile('lua/ppqka/ppq_ka_manager.lua')); assert(loadfile('lua/ppqka/config/ppq_g1.lua')); print('syntax ok')"
}
finally {
    Pop-Location
}
