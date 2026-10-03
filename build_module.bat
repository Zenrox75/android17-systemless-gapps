@echo off
REM Builds a Magisk module zip from an extracted MindTheGapps folder.
REM Usage: build_module.bat GApps16
REM Needs Windows 10+ (tar is built in). Run from the folder that contains the GApps folder.

if "%~1"=="" (
  echo Usage: build_module.bat ^<extracted_gapps_folder^>
  exit /b 1
)

set SRC=%~1

if not exist "%SRC%\system" (
  echo ERROR: "%SRC%\system" not found. Point this at the extracted GApps folder.
  exit /b 1
)

if not exist "%SRC%\system\product\priv-app\GmsCore" (
  echo ERROR: GmsCore not found in %SRC%\system\product\priv-app
  echo This package has no Play services. Do not continue.
  exit /b 1
)

if not exist module.prop (
  echo ERROR: module.prop not found next to this script.
  exit /b 1
)

if exist _module rmdir /s /q _module
mkdir _module

echo Copying files...
xcopy "%SRC%\system" "_module\system" /E /I /Q
if exist "_module\system\addon.d" rmdir /s /q "_module\system\addon.d"
copy /y module.prop _module\module.prop >nul

echo Zipping (this can take several minutes on slow drives)...
if exist gapps_module.zip del gapps_module.zip
pushd _module
tar -a -cf ..\gapps_module.zip *
popd

echo.
echo Done: gapps_module.zip
echo Verify module.prop is at the zip root:
echo    tar -tf gapps_module.zip ^| findstr /i "module.prop"
echo Then: adb push gapps_module.zip /sdcard/Download/
