@echo off
rem Refreshes the CoA Talent Advisor's build data from Ascension Sidekick (ascensionsidekick.com),
rem regenerates ZygorTalentAdvisorCOA\Data.lua, updates the re-apply kit and runs the advisor's test.
rem Close the game first; the new data loads on the next full game start.
setlocal
set "ADDON=D:\COA Client\Interface\AddOns\ZygorGuidesViewerRM"
cd /d "%~dp0talentdata" || exit /b 1
curl -sSL -o data.js.new https://ascensionsidekick.com/data.js || (echo Download failed - nothing changed. & goto :end)
move /y data.js.new data.js >nul
python build_ztacoa_data.py "%ADDON%\ZygorTalentAdvisorCOA\Data.lua" || (echo Data generation failed. & goto :end)
copy /y "%ADDON%\ZygorTalentAdvisorCOA\Data.lua" "%~dp0kit\files\zygor\ZygorTalentAdvisorCOA\Data.lua" >nul
cd /d "%~dp0"
"C:\Users\dotyt\tools\lua-5.1.5\lua5.1.exe" test_ztacoa.lua "%ADDON%" < nul
:end
echo.
pause
