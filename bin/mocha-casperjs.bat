@echo off
set MOCHA_CASPER_PATH=%~dp0

set showhelp=false
IF "%1"=="/?" set showhelp=true
IF "%1"=="-h" set showhelp=true
IF "%1"=="--help" set showhelp=true

IF "%showhelp%" == "true" (
 echo    mocha-casperjs usage
 echo       options must be in the format of --option=value
 echo.
 echo    --casper-timeout    Set Casper's timeout. Defaults to 5 seconds. You will want this less than Mocha's.
 echo    --file              Pipe reporter output to the specified file instead of standard out.
 echo    --mocha-path        Override path for mocha
 echo    --chai-path         Override path for chai
 echo    --casper-chai-path  Override path for casper-chai
 echo.
 echo    Mocha options
 echo    --reporter          Reporter to use. Use relative or absolute paths for 3rd party reporters.
 echo    --timeout           Set the timeout for Mocha tests
 echo    --grep              Only run tests matching a pattern
 echo    --invert            Only run tests not matching the pattern specified by --grep
 echo    --ui                Tests style ['bdd', 'tdd', or 'exports']
 echo    --no-color          Disable color output
 echo    --slow              Sets the threshold for marking tests as slow running
 echo    --require           require the given module
 echo    --bail              Exit on the first test failure

 echo    Casper Options
 echo    --user-agent        User agent string to use on requests
 echo    --viewport-width    Size of the viewport width
 echo    --viewport-height   Size of the viewport height
 echo    --client-scripts    Comma-separated array of lists to inject on the client every page load
 exit /b 0
)
%MOCHA_CASPER_PATH%.\..\..\casperjs\bin\casperjs.exe %MOCHA_CASPER_PATH%\cli.js --mocha-casperjs-path=%MOCHA_CASPER_PATH%.. %*