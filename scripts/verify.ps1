param([string]$MoonHome = $env:MOON_HOME)
$ErrorActionPreference = 'Stop'
if ($MoonHome) {
    $env:MOON_HOME = (Resolve-Path -LiteralPath $MoonHome).Path
    $env:PATH = "$env:MOON_HOME\bin;$env:PATH"
}
function Invoke-Moon {
    & moon @args
    if ($LASTEXITCODE -ne 0) { throw "moon failed: $args" }
}
Invoke-Moon version --all
Invoke-Moon fmt --check
foreach ($backend in @('wasm-gc', 'js')) {
    Invoke-Moon check --deny-warn --target $backend
    Invoke-Moon build --deny-warn --target $backend
    Invoke-Moon test --deny-warn --target $backend
    Invoke-Moon run examples/demo --target $backend
}
Invoke-Moon info --target wasm-gc
Invoke-Moon run cmd/main --target js -- inspect fixtures/contention.locks
Invoke-Moon run cmd/main --target js -- chain fixtures/contention.locks 3
Invoke-Moon run cmd/main --target js -- range fixtures/contention.locks 08:01:42 99 99
python scripts/verify_cli.py
if ($LASTEXITCODE -ne 0) { throw 'CLI verification failed' }
python scripts/verify_task_cli.py
if ($LASTEXITCODE -ne 0) { throw 'Task CLI verification failed' }
