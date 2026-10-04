@echo off
rem Moves saved addon settings from realm "Conquest of Azeroth" to "Nozdormu" after the realm rename.
rem Close the game first, and run it BEFORE logging in on Nozdormu.
rem   Migrate-RealmName.bat           dry run: shows what would change, writes nothing
rem   Migrate-RealmName.bat --apply   do it
cd /d "%~dp0"
python realm_migrate.py %*
echo.
pause
