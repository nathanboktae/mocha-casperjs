@ECHO OFF
set MOCHA_CASPER_PATH=%~dp0
%MOCHA_CASPER_PATH%\..\node_modules\casperjs\bin\casperjs.bat %MOCHA_CASPER_PATH%\cli.js --mocha-casperjs-path=%MOCHA_CASPER_PATH%.. %*