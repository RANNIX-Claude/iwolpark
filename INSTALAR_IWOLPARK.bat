@echo off
title Instalador IwolPark - Plaza IWOL
color 0A
echo.
echo  ============================================
echo   IwolPark - Sistema de Estacionamiento
echo   Plaza IWOL - Metepec, Edo. Mexico
echo   RANNIX Consulting 2026
echo  ============================================
echo.

:: Crear carpeta destino
set DEST=C:\Park\files
if not exist "%DEST%" mkdir "%DEST%"
echo  [1/6] Carpeta: %DEST%

:: Copiar archivos HTML
echo  [2/6] Copiando archivos...
copy /Y "%~dp0IwolPark_TABLET.html"              "%DEST%\IwolPark_TABLET.html"              >nul
copy /Y "%~dp0IwolPark_Pensiones.html"            "%DEST%\IwolPark_Pensiones.html"            >nul
copy /Y "%~dp0IwolPark_Dashboard_Admin.html"      "%DEST%\IwolPark_Dashboard_Admin.html"      >nul
copy /Y "%~dp0IwolPark_Dashboard_Corporativo.html" "%DEST%\IwolPark_Dashboard_Corporativo.html" >nul
echo      Archivos copiados OK

:: Detectar Chrome 64-bit o 32-bit
set CHROME=
if exist "C:\Program Files\Google\Chrome\Application\chrome.exe" (
  set CHROME="C:\Program Files\Google\Chrome\Application\chrome.exe"
  echo  [3/6] Chrome 64-bit detectado
) else if exist "C:\Program Files (x86)\Google\Chrome\Application\chrome.exe" (
  set CHROME="C:\Program Files (x86)\Google\Chrome\Application\chrome.exe"
  echo  [3/6] Chrome 32-bit detectado
) else (
  echo  [3/6] ADVERTENCIA: Chrome no encontrado en rutas estandar
  echo        Edita ABRIR_CAJERO.bat con la ruta correcta de Chrome
  set CHROME="C:\Program Files\Google\Chrome\Application\chrome.exe"
)

:: Crear BAT cajero (kiosk-printing para impresion directa)
echo  [4/6] Creando accesos directos...
(
echo @echo off
echo taskkill /f /im chrome.exe ^>nul 2^>^&1
echo taskkill /f /im chromedriver.exe ^>nul 2^>^&1
echo timeout /t 2 /nobreak ^>nul
echo %CHROME% --kiosk-printing --app="file:///C:/Park/files/IwolPark_TABLET.html"
) > "%DEST%\ABRIR_CAJERO.bat"

:: Crear BAT admin plaza
(
echo @echo off
echo taskkill /f /im chrome.exe ^>nul 2^>^&1
echo timeout /t 1 /nobreak ^>nul
echo %CHROME% --app="file:///C:/Park/files/IwolPark_Dashboard_Admin.html"
) > "%DEST%\ABRIR_ADMIN.bat"

:: Crear BAT pensiones
(
echo @echo off
echo %CHROME% --app="file:///C:/Park/files/IwolPark_Pensiones.html"
) > "%DEST%\ABRIR_PENSIONES.bat"

:: Crear accesos directos en escritorio
echo  [5/6] Creando iconos en escritorio...

powershell -Command "$ws=New-Object -ComObject WScript.Shell; $s=$ws.CreateShortcut('%USERPROFILE%\Desktop\IwolPark Cajero.lnk'); $s.TargetPath='%DEST%\ABRIR_CAJERO.bat'; $s.IconLocation='shell32.dll,258'; $s.Description='IwolPark Cajero - Plaza IWOL'; $s.Save()" 2>nul

powershell -Command "$ws=New-Object -ComObject WScript.Shell; $s=$ws.CreateShortcut('%USERPROFILE%\Desktop\IwolPark Admin.lnk'); $s.TargetPath='%DEST%\ABRIR_ADMIN.bat'; $s.IconLocation='shell32.dll,21'; $s.Description='IwolPark Dashboard Admin'; $s.Save()" 2>nul

powershell -Command "$ws=New-Object -ComObject WScript.Shell; $s=$ws.CreateShortcut('%USERPROFILE%\Desktop\IwolPark Pensiones.lnk'); $s.TargetPath='%DEST%\ABRIR_PENSIONES.bat'; $s.IconLocation='shell32.dll,23'; $s.Description='IwolPark Pensiones'; $s.Save()" 2>nul

:: Configurar impresora POS-58 como predeterminada
echo  [6/6] Configurando impresora POS-58...
powershell -Command "$p=Get-Printer | Where-Object {$_.Name -like '*POS*' -or $_.Name -like '*58*' -or $_.Name -like '*GHIA*' -or $_.Name -like '*thermal*'}; if($p){Set-DefaultPrinter $p[0].Name; Write-Host '     Impresora' $p[0].Name 'configurada'} else {Write-Host '     POS-58 no detectada - configurar manualmente en Panel de Control'}"

echo.
echo  ============================================
echo   INSTALACION COMPLETADA
echo  ============================================
echo.
echo   En el escritorio encontraras 3 iconos:
echo.
echo   [IwolPark Cajero]    - Pantalla operativa
echo                          Impresion directa POS-58
echo                          Iniciar con este para el turno
echo.
echo   [IwolPark Admin]     - Dashboard administrador
echo                          KPIs, movimientos, reportes
echo.
echo   [IwolPark Pensiones] - Modulo de pensionados
echo                          Cobranza y semaforo
echo.
echo   NIP cajero default:  1111
echo   NIP admin default:   111111
echo   (Cambiar en parametros despues de instalar)
echo.
echo   Soporte: Roberto Aguilar - RANNIX Consulting
echo   www.rannix.com
echo  ============================================
echo.
pause
