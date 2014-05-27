@ECHO OFF
set MOCHA_CASPER_PATH=%~dp0
%MOCHA_CASPER_PATH%.\..\..\casperjs\bin\casperjs.exe %MOCHA_CASPER_PATH%\cli.js --mocha-casperjs-path=%MOCHA_CASPER_PATH%.. %*