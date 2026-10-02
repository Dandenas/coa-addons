@echo off
rem Re-applies the Conquest of Azeroth changes to Zygor Guides Viewer RM, TomTom and HealBot
rem after installing a new version of any of them. Close the game first.
rem   Apply-ZygorCoA.bat            apply and run the tests
rem   Apply-ZygorCoA.bat --dry-run  only report what would change
cd /d "%~dp0kit"
python apply_coa_patch.py %*
echo.
pause
