@echo off
setlocal
rem Removes Modern WoW Renderer (github.com/Corfirean/modern-wow-renderer) from this client
rem and puts back the original d3d9.dll (DXVK 2.5.3) saved in _ModernRenderer_backup.
rem Only files the renderer installed or can create are deleted. See
rem _ModernRenderer_backup\INSTALL-RECORD.txt for the list.

cd /d "%~dp0"
set "BACKUP=_ModernRenderer_backup"
set "ORIGINAL_HASH=3D6B529DC4F7F55639AAD580E81B2939AB1489CDBB9F1550DCE74E41656BBF5B"

echo Modern WoW Renderer uninstaller
echo Client folder: %CD%
echo.

if not exist "%BACKUP%\d3d9.dll" (
    echo The backup of the original d3d9.dll was not found in %BACKUP%.
    echo Nothing has been changed.
    goto :end
)

tasklist /fi "imagename eq Ascension.exe" 2>nul | find /i "Ascension.exe" >nul
if not errorlevel 1 (
    echo The game is running. Close it first, then run this again.
    echo Nothing has been changed.
    goto :end
)

echo This removes the renderer and restores the original d3d9.dll.
choice /c YN /m "Continue"
if errorlevel 2 (
    echo Cancelled. Nothing has been changed.
    goto :end
)

rem 1. Restore the original d3d9.dll.
copy /y "%BACKUP%\d3d9.dll" "d3d9.dll" >nul
if errorlevel 1 (
    echo Could not restore d3d9.dll. Nothing else has been changed.
    goto :end
)
certutil -hashfile "d3d9.dll" SHA256 2>nul | find /i "%ORIGINAL_HASH%" >nul
if errorlevel 1 (
    echo WARNING: the restored d3d9.dll does not match the recorded original.
) else (
    echo Restored the original d3d9.dll ^(DXVK^).
)

rem 2. Remove the renderer's settings files.
del /q "ModernWoWRenderer.ini" "GraphicsEffects.ini" "EnvironmentProfiles.ini" 2>nul

rem 3. Remove logs and diagnostic output the renderer can create.
for %%F in (ModernWoWRenderer.log MaterialCache.log NativeShadowDiagnostics.log Atmosphere.log CelestialProbe.log VolumeEffects.log WaterEffect.log WeatherVisuals.log LocalLighting.log DistanceFog.log WaterReflection.log) do del /q "%%F" 2>nul
for %%D in (MaterialCache NativeShadowShaders CelestialDiagnostics WaterDiagnostics) do if exist "%%D\" rmdir /s /q "%%D"

rem 4. Remove the weather textures it installed, then the folders if nothing else is in them.
for %%F in (raindrop01.png raindropsplash01.dds raindropsplash01.png snowflake01.dds snowflake01.png snowmist01.dds snowmist01.png weathermistgrainy01.dds weathermistgrainy01.png) do del /q "textures\weather\%%F" 2>nul
rmdir "textures\weather" 2>nul
rmdir "textures" 2>nul

echo.
echo Done. The renderer is removed and the game will use DXVK again.
echo The backup folder %BACKUP% was kept; delete it yourself once you are happy.

:end
echo.
pause
