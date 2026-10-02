@echo off
setlocal
rem Undoes the CoA UI switch: puts back the previous Extensions.dll and the five
rem CoA-modified addon folders saved in _CoA_UI_backup (see _CoA_UI_backup\README.txt).

cd /d "%~dp0"
set "BACKUP=_CoA_UI_backup"

if not exist "%BACKUP%\Extensions.dll.old" (
    echo The backup in %BACKUP% was not found. Nothing has been changed.
    goto :end
)
tasklist /fi "imagename eq Ascension.exe" 2>nul | find /i "Ascension.exe" >nul
if not errorlevel 1 (
    echo The game is running. Close it first, then run this again.
    goto :end
)
choice /c YN /m "Restore the previous Extensions.dll and CoA addon folders"
if errorlevel 2 (
    echo Cancelled. Nothing has been changed.
    goto :end
)

copy /y "%BACKUP%\Extensions.dll.old" "Extensions.dll" >nul || (echo Could not restore Extensions.dll. & goto :end)
echo Restored Extensions.dll.

for %%D in (Ascension_Collections Ascension_AppearanceUI Ascension_VanityCollection Ascension_Manastorm Ascension_HelpUI) do (
    if exist "%BACKUP%\%%D\" (
        if exist "Interface\AddOns\%%D\" (
            echo Interface\AddOns\%%D already exists - left as it is.
        ) else (
            move "%BACKUP%\%%D" "Interface\AddOns\%%D" >nul && echo Restored Interface\AddOns\%%D
        )
    )
)
echo.
echo Done. The backup folder keeps Extensions.dll.old and README.txt; delete it when you no longer need it.

:end
echo.
pause
