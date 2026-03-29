@echo off
setlocal enabledelayedexpansion

set ROOT=%~dp0
set TOOLS=%ROOT%tools
set HACPACK=%TOOLS%\hacpack.exe
set NPDMTOOL=%TOOLS%\npdmtool.exe
set PYTHON=python

set KEYS=%ROOT%keys.dat

:: ─────────────────────────────────────────────────────────────────────────────
:: Configuration — edit these fields only!
:: ─────────────────────────────────────────────────────────────────────────────

set "TITLE=Gandalf Sax"
set "AUTHOR=Gandalf"
set DISPLAY_VER=1.0.0
set TITLE_ID=0400000000400000
set KEYGEN=19
set SDK_VER=13030000
set SYS_VER=19.0.0

:: ─────────────────────────────────────────────────────────────────────────────
:: STOP EDITING - Dont touch anything below this line or there may be demons!
:: ─────────────────────────────────────────────────────────────────────────────

:: Optional signing keys — presence determines whether flags are added
set ACID_KEY=%ROOT%acid_private.pem
set NCASIG1_KEY=%ROOT%ncasig1_private.pem
set NCASIG2_KEY=%ROOT%ncasig2_private.pem
set NCASIG2_MOD=%ROOT%ncasig2_modulus.bin

:: ─────────────────────────────────────────────────────────────────────────────
:: Sanity checks
:: ─────────────────────────────────────────────────────────────────────────────

if not exist "%HACPACK%"      ( echo ERROR: hacpack.exe not found in tools\        & goto :fail )
if not exist "%NPDMTOOL%"     ( echo ERROR: npdmtool.exe not found in tools\       & goto :fail )
if not exist "%KEYS%"         ( echo ERROR: keys.dat not found in root             & goto :fail )
if not exist "%ROOT%logo"     ( echo ERROR: logo\ folder not found                 & goto :fail )
if not exist "%ROOT%icon.jpg" ( echo ERROR: icon.jpg not found in repo root        & goto :fail )
if not exist "%ROOT%npdm.json" ( echo ERROR: npdm.json not found in repo root      & goto :fail )
if not exist "%TOOLS%\generate_control.py" ( echo ERROR: tools\generate_control.py not found & goto :fail )

:: ─────────────────────────────────────────────────────────────────────────────
:: Step -1 — Detect content type and stage exefs
:: ─────────────────────────────────────────────────────────────────────────────

echo.
echo [-1/7] Detecting content type...

if exist "%ROOT%video\index.html" (
    echo   Found video\index.html - using template\index\exefs
    if not exist "%ROOT%template\index\exefs\main" ( echo ERROR: template\index\exefs\main not found & goto :fail )
    if exist "%ROOT%exefs" rmdir /s /q "%ROOT%exefs"
    mkdir "%ROOT%exefs"
    copy /y "%ROOT%template\index\exefs\main" "%ROOT%exefs\main" >nul
    if errorlevel 1 ( echo ERROR: Failed to copy template\index\exefs\main & goto :fail )
) else if exist "%ROOT%video\video.mp4" (
    echo   Found video\video.mp4 - using template\video\exefs
    if not exist "%ROOT%template\video\exefs\main" ( echo ERROR: template\video\exefs\main not found & goto :fail )
    if exist "%ROOT%exefs" rmdir /s /q "%ROOT%exefs"
    mkdir "%ROOT%exefs"
    copy /y "%ROOT%template\video\exefs\main" "%ROOT%exefs\main" >nul
    if errorlevel 1 ( echo ERROR: Failed to copy template\video\exefs\main & goto :fail )
) else (
    echo ERROR: video\ must contain either index.html or video.mp4 - neither found
    goto :fail
)

:: ─────────────────────────────────────────────────────────────────────────────
:: Step 0 — Patch npdm.json and build NPDM
:: ─────────────────────────────────────────────────────────────────────────────

echo.
echo [0/7] Building NPDM...

%PYTHON% -c "import json; d=json.load(open(r'%ROOT%npdm.json')); d['title_id']='0x%TITLE_ID%'; d['program_id']='0x%TITLE_ID%'; d['program_id_range_min']='0x%TITLE_ID%'; d['program_id_range_max']='0x%TITLE_ID%'; json.dump(d,open(r'%ROOT%npdm_patched.json','w'),indent=4)"
if errorlevel 1 ( echo ERROR: npdm.json patch failed & goto :fail )

"%NPDMTOOL%" "%ROOT%npdm_patched.json" "%ROOT%exefs\main.npdm"
if errorlevel 1 ( echo ERROR: npdmtool failed & goto :fail )

:: ─────────────────────────────────────────────────────────────────────────────
:: Step 1 — Derive ncasig2 modulus from PEM (only if key is present)
:: ─────────────────────────────────────────────────────────────────────────────

echo.
echo [1/7] Deriving ncasig2 modulus...

if exist "%NCASIG2_KEY%" (
    openssl rsa -in "%NCASIG2_KEY%" -noout -modulus > "%TEMP%\modulus_hex.txt" 2>nul
    if errorlevel 1 ( echo ERROR: openssl failed - is it on your PATH? & goto :fail )
    %PYTHON% -c ^
        "import binascii; raw = open(r'%TEMP%\modulus_hex.txt').read().strip(); hex_str = raw.split('=',1)[1].strip(); open(r'%NCASIG2_MOD%', 'wb').write(binascii.unhexlify(hex_str))"
    if errorlevel 1 ( echo ERROR: Python modulus conversion failed & goto :fail )
    echo   Modulus derived from %NCASIG2_KEY%
) else (
    echo   ncasig2_private.pem not found - skipping modulus derivation
)

:: ─────────────────────────────────────────────────────────────────────────────
:: Step 2 — Generate control romfs
:: ─────────────────────────────────────────────────────────────────────────────

echo.
echo [2/7] Generating control romfs...

if not exist "%ROOT%control_romfs" mkdir "%ROOT%control_romfs"
if not exist "%ROOT%nca"           mkdir "%ROOT%nca"
if not exist "%ROOT%nsp"           mkdir "%ROOT%nsp"

%PYTHON% "%TOOLS%\generate_control.py" "%ROOT%icon.jpg" "%ROOT%control_romfs" --titleid %TITLE_ID% --title "%TITLE%" --author "%AUTHOR%" --displayver %DISPLAY_VER%
if errorlevel 1 ( echo ERROR: generate_control.py failed & goto :fail )

:: ─────────────────────────────────────────────────────────────────────────────
:: Step 3 — Build Control NCA
:: ─────────────────────────────────────────────────────────────────────────────

echo.
echo [3/7] Building Control NCA...

set FLAGS=-k "%KEYS%" -o "%ROOT%nca" --type nca --keygeneration %KEYGEN% --sdkversion %SDK_VER% --ncatype control --titleid %TITLE_ID% --romfsdir "%ROOT%control_romfs"
if exist "%NCASIG1_KEY%" set FLAGS=!FLAGS! --ncasig1privatekey "%NCASIG1_KEY%"

"%HACPACK%" !FLAGS!
if errorlevel 1 ( echo ERROR: Control NCA build failed & goto :fail )

set CONTROL_NCA=
for %%F in ("%ROOT%nca\*.nca") do set CONTROL_NCA=%%~nxF
if "!CONTROL_NCA!"=="" ( echo ERROR: No NCA found after control build & goto :fail )
echo   Control NCA: !CONTROL_NCA!

:: ─────────────────────────────────────────────────────────────────────────────
:: Step 4 — Build Program NCA
:: ─────────────────────────────────────────────────────────────────────────────

echo.
echo [4/7] Building Program NCA...

set FLAGS=-k "%KEYS%" -o "%ROOT%nca" --type nca --keygeneration %KEYGEN% --sdkversion %SDK_VER% --ncatype program --titleid %TITLE_ID% --exefsdir "%ROOT%exefs" --logodir "%ROOT%logo"
if exist "%NCASIG2_KEY%" (
    set FLAGS=!FLAGS! --ncasig2privatekey "%NCASIG2_KEY%"
    if exist "%NCASIG2_MOD%" set FLAGS=!FLAGS! --ncasig2modulus "%NCASIG2_MOD%"
)
if exist "%ACID_KEY%"    set FLAGS=!FLAGS! --acidsigprivatekey "%ACID_KEY%"
if exist "%NCASIG1_KEY%" set FLAGS=!FLAGS! --ncasig1privatekey "%NCASIG1_KEY%"

"%HACPACK%" !FLAGS!
if errorlevel 1 ( echo ERROR: Program NCA build failed & goto :fail )

set PROGRAM_NCA=
for %%F in ("%ROOT%nca\*.nca") do (
    if not "%%~nxF"=="!CONTROL_NCA!" set PROGRAM_NCA=%%~nxF
)
if "!PROGRAM_NCA!"=="" ( echo ERROR: Could not identify program NCA & goto :fail )
echo   Program NCA: !PROGRAM_NCA!

:: ─────────────────────────────────────────────────────────────────────────────
:: Step 5 — Build Manual NCA
:: ─────────────────────────────────────────────────────────────────────────────

echo.
echo [5/7] Building Manual NCA...

:: Stage video contents into required html-document\.htdocs\ structure
set MANUAL_STAGE=%ROOT%manual_stage
if exist "%MANUAL_STAGE%" rmdir /s /q "%MANUAL_STAGE%"
mkdir "%MANUAL_STAGE%\html-document\.htdocs"
xcopy /e /i /q "%ROOT%video\*" "%MANUAL_STAGE%\html-document\.htdocs\"
if errorlevel 1 ( echo ERROR: Failed to stage manual content & goto :fail )

set FLAGS=-k "%KEYS%" -o "%ROOT%nca" --type nca --keygeneration %KEYGEN% --sdkversion %SDK_VER% --ncatype manual --titleid %TITLE_ID% --romfsdir "%MANUAL_STAGE%"
if exist "%NCASIG1_KEY%" set FLAGS=!FLAGS! --ncasig1privatekey "%NCASIG1_KEY%"

"%HACPACK%" !FLAGS!
if errorlevel 1 ( echo ERROR: Manual NCA build failed & goto :fail )

set MANUAL_NCA=
for %%F in ("%ROOT%nca\*.nca") do (
    if not "%%~nxF"=="!CONTROL_NCA!" (
        if not "%%~nxF"=="!PROGRAM_NCA!" set MANUAL_NCA=%%~nxF
    )
)
if "!MANUAL_NCA!"=="" ( echo ERROR: Could not identify manual NCA & goto :fail )
echo   Manual NCA: !MANUAL_NCA!

:: ─────────────────────────────────────────────────────────────────────────────
:: Step 6 — Build Meta NCA
:: ─────────────────────────────────────────────────────────────────────────────

echo.
echo [6/7] Building Meta NCA...

set FLAGS=-k "%KEYS%" -o "%ROOT%nca" --type nca --keygeneration %KEYGEN% --sdkversion %SDK_VER% --ncatype meta --titletype application --titleid %TITLE_ID% --requiredsystemversion %SYS_VER% --programnca "%ROOT%nca\!PROGRAM_NCA!" --controlnca "%ROOT%nca\!CONTROL_NCA!" --htmldocnca "%ROOT%nca\!MANUAL_NCA!"
if exist "%NCASIG1_KEY%" set FLAGS=!FLAGS! --ncasig1privatekey "%NCASIG1_KEY%"

"%HACPACK%" !FLAGS!
if errorlevel 1 ( echo ERROR: Meta NCA build failed & goto :fail )

:: ─────────────────────────────────────────────────────────────────────────────
:: Step 7 — Build NSP
:: ─────────────────────────────────────────────────────────────────────────────

echo.
echo [7/7] Building NSP...

"%HACPACK%" -k "%KEYS%" -o "%ROOT%nsp" --type nsp --ncadir "%ROOT%nca" --titleid %TITLE_ID%
if errorlevel 1 ( echo ERROR: NSP build failed & goto :fail )

:: Rename to friendly name
set NSP_IN=%ROOT%nsp\%TITLE_ID%.nsp
if exist "%NSP_IN%" ren "%NSP_IN%" "%TITLE% [%TITLE_ID%][v0].nsp"

:: ─────────────────────────────────────────────────────────────────────────────
:: Cleanup
:: ─────────────────────────────────────────────────────────────────────────────

if exist "%NCASIG2_MOD%"              del "%NCASIG2_MOD%"
if exist "%TEMP%\modulus_hex.txt"     del "%TEMP%\modulus_hex.txt"
if exist "%ROOT%npdm_patched.json"    del "%ROOT%npdm_patched.json"
if exist "%ROOT%control_romfs"        rmdir /s /q "%ROOT%control_romfs"
if exist "%ROOT%manual_stage"         rmdir /s /q "%ROOT%manual_stage"
if exist "%ROOT%exefs"                rmdir /s /q "%ROOT%exefs"
if exist "%ROOT%nca"                  rmdir /s /q "%ROOT%nca"
if exist "%ROOT%hacpack_backup"       rmdir /s /q "%ROOT%hacpack_backup"
if exist "%ROOT%hacpack_temp"         rmdir /s /q "%ROOT%hacpack_temp"

echo.
echo ---------------------------------------------------------
echo  Build complete.
echo  NSP: nsp\%TITLE% [%TITLE_ID%][v0].nsp
echo ---------------------------------------------------------
goto :end

:fail
echo.
echo Build failed. See error above.
if exist "%NCASIG2_MOD%"              del "%NCASIG2_MOD%"
if exist "%TEMP%\modulus_hex.txt"     del "%TEMP%\modulus_hex.txt"
if exist "%ROOT%npdm_patched.json"    del "%ROOT%npdm_patched.json"
if exist "%ROOT%control_romfs"        rmdir /s /q "%ROOT%control_romfs"
if exist "%ROOT%manual_stage"         rmdir /s /q "%ROOT%manual_stage"
if exist "%ROOT%exefs"                rmdir /s /q "%ROOT%exefs"
if exist "%ROOT%nca"                  rmdir /s /q "%ROOT%nca"
if exist "%ROOT%hacpack_backup"       rmdir /s /q "%ROOT%hacpack_backup"
if exist "%ROOT%hacpack_temp"         rmdir /s /q "%ROOT%hacpack_temp"
exit /b 1

:end
endlocal