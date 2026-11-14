# Syntax-checks every Luau file in src/ using luau-compile (catches parse errors before Studio does)
$root = Split-Path $PSScriptRoot -Parent
$compiler = "$env:USERPROFILE\.luau\luau-compile.exe"
$fail = 0
Get-ChildItem -Recurse "$root\src" -Filter *.luau | ForEach-Object {
	$out = & $compiler --null $_.FullName 2>&1
	if ($LASTEXITCODE -ne 0) {
		Write-Host "FAIL $($_.Name)" -ForegroundColor Red
		$out | ForEach-Object { Write-Host "   $_" }
		$fail++
	} else {
		Write-Host "OK   $($_.Name)" -ForegroundColor Green
	}
}
if ($fail -gt 0) { exit 1 }
