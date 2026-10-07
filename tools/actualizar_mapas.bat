@echo off
rem Doble clic: importa los mapas de Tiled (bosque, desierto, pantano) y
rem arma el juego para Windows en build\windows\OneLastHero.exe.
rem La primera vez saca Godot del zip de Descargas a tools\godot\.
cd /d "%~dp0.."
set GODOT=tools\godot\Godot_v4.7.2-stable_win64_console.exe
if not exist "%GODOT%" (
  echo Sacando Godot del zip de Descargas...
  powershell -NoProfile -Command "Expand-Archive -Force '%USERPROFILE%\Downloads\Godot_v4.7.2-stable_win64.exe.zip' 'tools\godot'"
)
if not exist "%GODOT%" (
  echo No encontre Godot: pon Godot_v4.7.2-stable_win64.exe y su _console.exe en tools\godot\
  pause
  exit /b 1
)
echo.
echo === Importando archivos nuevos ===
"%GODOT%" --headless --path . --import >nul 2>&1
for %%m in (bosque desierto pantano) do (
  echo === Mapa %%m ===
  "%GODOT%" --headless --path . --script tools/import_tiled_map.gd -- %%m 2>&1 | findstr /i "scn error falta"
)
echo.
echo === Armando el juego ===
"%GODOT%" --headless --path . --export-release "Windows Desktop" build/windows/OneLastHero.exe >nul 2>&1
echo.
echo Listo. En Tiled, la capa "vista choque" muestra en rojo lo que no se camina
echo (si no se ve el cambio, cierra y vuelve a abrir el mapa).
echo El juego esta en build\windows\OneLastHero.exe
pause
