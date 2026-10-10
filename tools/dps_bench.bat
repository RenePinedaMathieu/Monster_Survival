@echo off
rem Banco de DPS: los 3 heroes contra blancos quietos, una horda de 40 y
rem un jefe (tools\dps_bench\dps_bench.gd), con 3 semillas, y una partida
rem real por heroe (run_bot.gd: en que nivel termina cada oleada). Tarda
rem unos 6 minutos. Al final muestra el resumen y lo deja en
rem build\dps_bench\informe.txt.
rem Necesita tools\godot\ (lo arma actualizar_mapas.bat) y Python.
cd /d "%~dp0.."
set GODOT=tools\godot\Godot_v4.7.2-stable_win64_console.exe
if not exist "%GODOT%" (
  echo Falta Godot en tools\godot\: corre antes tools\actualizar_mapas.bat
  pause
  exit /b 1
)
set OUT=%CD%\build\dps_bench
if not exist "%OUT%" mkdir "%OUT%"
rem El banco escribe el guardado (estadisticas, logros) y las mejoras de
rem la tienda cambiarian los numeros: se aparta el tuyo y vuelve al final.
set SAVE=%APPDATA%\OneLastHero\save.cfg
set HAD_SAVE=0
if exist "%SAVE%" (
  set HAD_SAVE=1
  move /Y "%SAVE%" "%SAVE%.banco" >nul
)
set RUN="%GODOT%" --headless --fixed-fps 60 --path . --script res://tools/dps_bench/dps_bench.gd --
for %%h in (swordman elara doren) do (
  echo === %%h ===
  %RUN% hero=%%h mode=dummy "out=%OUT%\%%h_dummy.jsonl" >nul 2>&1
  for %%s in (1000 2000 3000) do (
    %RUN% hero=%%h mode=horde seed=%%s "out=%OUT%\%%h_horde_%%s.jsonl" >nul 2>&1
    %RUN% hero=%%h mode=boss seed=%%s "out=%OUT%\%%h_boss_%%s.jsonl" >nul 2>&1
  )
  "%GODOT%" --headless --fixed-fps 60 --path . --script res://tools/dps_bench/run_bot.gd -- hero=%%h seed=1 "out=%OUT%\%%h_run_1.jsonl" >nul 2>&1
)
if exist "%SAVE%" del "%SAVE%"
if "%HAD_SAVE%"=="1" move /Y "%SAVE%.banco" "%SAVE%" >nul
python tools\dps_bench\report.py "%OUT%"
pause
