@echo off
powershell -ExecutionPolicy Bypass -Command "Start-Process pwsh -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Manutenzione_PRO_MAX_v3.ps1\"' -Verb RunAs"
if %errorlevel% neq 0 (
    powershell -ExecutionPolicy Bypass -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0Manutenzione_PRO_MAX_v3.ps1\"' -Verb RunAs"
)