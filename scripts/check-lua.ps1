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
    $files = @(
        'lua/ppqka/ppq_ka_manager.lua',
        'lua/ppqka/ppq_ka_reporter.lua',
        'lua/ppqka/config/ppqka_config_example.lua'
    )

    foreach ($localConfig in @('config/ppqka_config.lua', 'config/ppqka/ppqka_config.lua')) {
        if (Test-Path -LiteralPath $localConfig) {
            $files += $localConfig
        }
    }

    $lua = @"
local files = {
$($files | ForEach-Object { "  '$($_ -replace '\\', '/')'," } | Out-String)
}

for _, file in ipairs(files) do
  assert(loadfile(file))
end

print('syntax ok')
"@

    & $luaJitPath -e $lua
}
finally {
    Pop-Location
}
