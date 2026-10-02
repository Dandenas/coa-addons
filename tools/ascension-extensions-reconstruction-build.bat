@echo off
rem Builds Extensions.dll from C:\Users\dotyt\tools\ascension-extensions-reconstruction
rem (32-bit MSVC from VS 2022 Build Tools, with the CMake and Ninja that ship with them).
set "VS=C:\Program Files (x86)\Microsoft Visual Studio\2022\BuildTools"
set "PATH=C:\Program Files (x86)\Microsoft Visual Studio\Installer;%PATH%"
call "%VS%\VC\Auxiliary\Build\vcvars32.bat" >nul || exit /b 1
set "PATH=%VS%\Common7\IDE\CommonExtensions\Microsoft\CMake\CMake\bin;%VS%\Common7\IDE\CommonExtensions\Microsoft\CMake\Ninja;%PATH%"
cd /d "%~dp0ascension-extensions-reconstruction" || exit /b 1
cmake -G Ninja -DCMAKE_BUILD_TYPE=RelWithDebInfo -S . -B build || exit /b 1
cmake --build build || exit /b 1
echo BUILD OK: %CD%\build\Extensions.dll
