@echo off
rem Copies the current patched addons, tools and client scripts into this repository so the
rem changes can be committed (e.g. in GitHub Desktop). Nothing outside the repository is changed.
setlocal
set "REPO=%~dp0"
set "CLIENT=D:\COA Client"
set "ADDONS=%CLIENT%\Interface\AddOns"
set "TOOLS=C:\Users\dotyt\tools"
set "RC=/MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1"

echo Syncing into %REPO%
robocopy "%ADDONS%\ZygorGuidesViewerRM" "%REPO%addons\ZygorGuidesViewerRM" %RC% /XD _CoA_backup* /XF ZygorQuestDB.lua
robocopy "%ADDONS%\TomTom" "%REPO%addons\TomTom" %RC% /XD _CoA_original _CoA_backup*
robocopy "%ADDONS%\CoAMapProbe" "%REPO%addons\CoAMapProbe" %RC%
robocopy "%TOOLS%\zygor-coa" "%REPO%tools\zygor-coa" %RC% /XD __pycache__ /XF *.new *.pyc
copy /y "%TOOLS%\ascension-extensions-reconstruction-build.bat" "%REPO%tools\" >nul
for %%F in (Restore-CoA-UI.bat Uninstall-ModernRenderer.bat) do if exist "%CLIENT%\%%F" copy /y "%CLIENT%\%%F" "%REPO%client-scripts\" >nul

rem robocopy exit codes below 8 mean success
if %ERRORLEVEL% GEQ 8 (echo Sync reported an error - check the output above.) else (echo Done. Review and commit the changes in GitHub Desktop.)
echo.
pause
