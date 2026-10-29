# Repeatable backend DB setup (Windows PowerShell).
# Run from anywhere:  .\scripts\setup_db.ps1
# If psql asks for a password, either let it prompt or set $env:PGPASSWORD first.
param(
    [string]$DbUser = "postgres",
    [string]$DbHost = "localhost",
    [int]$Port = 5432,
    [string]$DbName = "parkkeys_db"
)

$ErrorActionPreference = "Stop"
$Root = Split-Path -Parent $PSScriptRoot
$psql = "psql"

function Invoke-Psql([string[]]$PsqlArgs) {
    & $psql -U $DbUser -h $DbHost -p $Port @PsqlArgs
    if ($LASTEXITCODE -ne 0) { throw "psql failed: $($PsqlArgs -join ' ')" }
}

Write-Host "==> Creating database $DbName (if missing)"
$exists = (& $psql -U $DbUser -h $DbHost -p $Port -d postgres -tAc "SELECT 1 FROM pg_database WHERE datname = '$DbName'").Trim()
if ($exists -ne "1") {
    Invoke-Psql @("-d", "postgres", "-c", "CREATE DATABASE $DbName;")
}

Write-Host "==> Loading schema"
Invoke-Psql @("-d", $DbName, "-v", "ON_ERROR_STOP=1", "-f", "$Root\database\schema.sql")

Write-Host "==> Loading 31 barangays + demo users + synthetic demand history"
Invoke-Psql @("-d", $DbName, "-v", "ON_ERROR_STOP=1", "-f", "$Root\database\seed_data.sql")

Write-Host "==> Setting bcrypt hashes for demo accounts"
$python = Join-Path $Root "backend\venv\Scripts\python.exe"
if (-not (Test-Path $python)) { $python = "python" }
Push-Location (Join-Path $Root "backend")
try {
    & $python "scripts\seed_users.py"
    if ($LASTEXITCODE -ne 0) { throw "seed_users.py failed" }
} finally {
    Pop-Location
}

Write-Host ""
Write-Host "Database ready: $DbName"
Write-Host "Next: copy .env.example to backend\.env, set DATABASE_URL, then run uvicorn."
