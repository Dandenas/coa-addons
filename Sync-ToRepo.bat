@echo off
rem Copies the current patched addons, tools and client scripts into this repository so the
rem changes can be committed (e.g. in GitHub Desktop). Nothing outside the repository is changed.
setlocal
set "REPO=%~dp0"
set "CLIENT=D:\COA Client"
set "ADDONS=%CLIENT%\Interface\AddOns"
set "TOOLS=C:\Users\dotyt\tools"
set "RC=/MIR /NFL /NDL /NJH /NJS /NP /R:1 /W:1"

rem This file must stay in the root of the coa-addons repository; anywhere else it would copy into the wrong folder.
if not exist "%REPO%.git" goto :wrongplace
if not exist "%REPO%addons" goto :wrongplace

echo Syncing into %REPO%
robocopy "%ADDONS%\ZygorGuidesViewerRM" "%REPO%addons\ZygorGuidesViewerRM" %RC% /XD _CoA_backup* /XF ZygorQuestDB.lua
robocopy "%ADDONS%\TomTom" "%REPO%addons\TomTom" %RC% /XD _CoA_original _CoA_backup*
robocopy "%ADDONS%\CoAMapProbe" "%REPO%addons\CoAMapProbe" %RC%
robocopy "%ADDONS%\HealBot" "%REPO%addons\HealBot" %RC% /XD _CoA_original _CoA_backup*
robocopy "%ADDONS%\ButtonForge" "%REPO%addons\ButtonForge" %RC% /XD _CoA_original _CoA_backup*
for %%Q in (Questie-X Questie-X-AscensionDB Questie-X-WotLKDB Questie-X-CoADB) do robocopy "%ADDONS%\%%Q" "%REPO%addons\%%Q" %RC% /XD _CoA_original _CoA_backup*
rem Questie-X tools: the CoA map generator and the CoADB plugin builder (not the downloads, the server export or caches)
robocopy "%TOOLS%\questie-x" "%REPO%tools\questie-x" %RC% /XD src zips __pycache__ Questie-X-CoADB /XF *.json.gz stock_index.tsv dump_err.txt *.pyc
robocopy "%TOOLS%\zygor-coa" "%REPO%tools\zygor-coa" %RC% /XD __pycache__ /XF *.new *.pyc
copy /y "%TOOLS%\ascension-extensions-reconstruction-build.bat" "%REPO%tools\" >nul
for %%F in (Restore-CoA-UI.bat Uninstall-ModernRenderer.bat) do if exist "%CLIENT%\%%F" copy /y "%CLIENT%\%%F" "%REPO%client-scripts\" >nul
set "SYNCERR=0"
if %ERRORLEVEL% GEQ 8 set "SYNCERR=1"

rem The public per-addon repositories next to this one (coa-zygor, coa-tomtom, coa-healbot, coa-buttonforge).
rem Each holds only its addon folder; README, LICENSE and .gitattributes at their root are left alone.
set "PUB=%REPO%..\"
call :pub coa-zygor ZygorGuidesViewerRM
call :pub coa-tomtom TomTom
call :pub coa-healbot HealBot
call :pub coa-buttonforge ButtonForge
rem coa-questie holds four addon folders plus the public tools
for %%Q in (Questie-X Questie-X-WotLKDB Questie-X-AscensionDB Questie-X-CoADB) do call :pub coa-questie %%Q
if exist "%PUB%coa-questie\.git" robocopy "%TOOLS%\questie-x" "%PUB%coa-questie\tools" %RC% /XD src zips __pycache__ Questie-X-CoADB /XF README.md CoAExtraZones.lua *.json.gz stock_index.tsv dump_err.txt *.pyc
if %ERRORLEVEL% GEQ 8 set "SYNCERR=1"

rem robocopy exit codes below 8 mean success
if %SYNCERR%==1 (echo Sync reported an error - check the output above.) else (echo Done. Review and commit the changes in GitHub Desktop, in each repository that shows changes.)
echo.
pause
exit /b

:pub
if not exist "%PUB%%1\.git" (echo Skipped %1 - repository not found. & exit /b)
robocopy "%ADDONS%\%2" "%PUB%%1\%2" %RC% /XD _CoA_original _CoA_backup* /XF ZygorQuestDB.lua
if %ERRORLEVEL% GEQ 8 set "SYNCERR=1"
exit /b

:wrongplace
echo Nothing was synced: this script is not in the root of the coa-addons repository.
echo It is in %REPO%
echo Move it back to C:\Users\dotyt\Documents\GitHub\coa-addons\ and run it from there.
echo.
pause
exit /b 1
