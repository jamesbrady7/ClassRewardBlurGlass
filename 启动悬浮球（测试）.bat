@echo off
cd /d "%~dp0"
REM FloatBall (test build) - close this console to quit
REM If taps do not respond, run:  set FLOAT_NOACTIVATE=0  then start again
python _float_test.py
pause
