@ECHO OFF
set MOCHA_CASPER_PATH=%~dp0
casperjs.bat %MOCHA_CASPER_PATH%\cli.js --mocha-casperjs-path=%MOCHA_CASPER_PATH%.. %*