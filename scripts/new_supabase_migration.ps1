param(
  [Parameter(Mandatory = $true)]
  [string]$Name,

  [string]$Source = "supabase/migrations/20260418120000_initial_public_schema.sql"
)

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$sourcePath = Join-Path $repoRoot $Source
$migrationsDir = Join-Path $repoRoot "supabase\migrations"

if (-not (Test-Path $sourcePath)) {
  throw "Source SQL file not found: $sourcePath"
}

if (-not (Test-Path $migrationsDir)) {
  New-Item -ItemType Directory -Path $migrationsDir | Out-Null
}

$timestamp = Get-Date -Format "yyyyMMddHHmmss"
$safeName = ($Name.ToLower() -replace "[^a-z0-9]+", "_").Trim("_")
$fileName = "${timestamp}_${safeName}.sql"
$targetPath = Join-Path $migrationsDir $fileName

Copy-Item -Path $sourcePath -Destination $targetPath
Write-Host "Created migration: $targetPath"
Write-Host "Next: commit this file and push to main to auto-apply via GitHub Action."
