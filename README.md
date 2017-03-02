# CasperJS automation via Mocha [![Build Status](https://secure.travis-ci.org/nathanboktae/mocha-casperjs.png?branch=master)](https://travis-ci.org/nathanboktae/mocha-casperjs)

[![Join the chat at https://gitter.im/nathanboktae/mocha-casperjs](https://badges.gitter.im/nathanboktae/mocha-casperjs.svg)](https://gitter.im/nathanboktae/mocha-casperjs?utm_source=badge&utm_medium=badge&utm_campaign=pr-badge&utm_content=badge)

Combine the power of [casperjs][]' automation with [Mocha][]'s robust testing framework features

## Features
- automatically load Casper, Mocha, and optionally [chai][] and [casper-chai][]
- automatically run your Casper steps after each test
- use any Mocha reporter that can run in the [phantomjs][] environment

For example, let's rewrite Casper's [google testing example](http://docs.casperjs.org/en/latest/testing.html#browser-tests)

````javascript
describe('Google searching', function() {
  before(function() {
    casper.start('http://www.google.fr/')
  })

  it('should retrieve 10 or more results', function() {
    casper.then(function() {
      'Google'.should.matchTitle
      'form[action="/search"]'.should.be.inDOM.and.be.visible
      this.fill('form[action="/search"]', {
        q: 'casperjs'
      }, true)
    })

    casper.waitForUrl(/q=casperjs/, function() {
      (/casperjs/).should.matchTitle
    })
  })
})
````

## How to use

````
npm install -g mocha-casperjs
mocha-casperjs
````

For the sample above you also need `chai` and `casper-chai`, a great assertion library and a plugin that works well with casperjs (more info below)

```
npm install -g chai casper-chai
```

Like Mocha, if you place your tests in the `test` or `tests` directory, it will find them and run them. You can also specify tests to run individually instead.

Note that mocha-casperjs has peer dependencies on casper and mocha, and will be installed ajacent to where you are installing mocha-casperjs (e.g. if you install mocha-casperjs globally, you'll have mocha and casperjs also installed globally).

Note that [slimerjs][] isn't [supported at the moment](https://github.com/nathanboktae/mocha-casperjs/issues/5)

Remember that your tests *do not run in node.js*, but whatever engine you choose from casperjs, so your language and API features will depend on that.

#### Windows users

You need to use `mocha-casperjs.bat` that will call into `casperjs.exe`. Please also refer to [CasperJS' Installation Instructions on Windows](http://docs.casperjs.org/en/latest/installation.html#casperjs-on-windows).

I no longer have access to a Windows box or VM to develop on, so you'll have to dig into any issues with the batch file yourselves and send a pull request. In the end it's a shell and `PATH` issue and you can always call `casperjs.exe` yourself.

## Additional Conveniences

If [chai][] is discovered (it must be installed adjacent to mocha-casperjs), it will automatically use the `should` style as well as expose `expect` globally.

If [casper-chai][] is discovered, it will be used with chai.

The [selectXPath](http://casperjs.readthedocs.org/en/latest/selectors.html#index-2) casper helper method is exposed globally as `xpath`.

## Command Line Options

In addition to specifying options on the command line, you can add them to a `mocha-casperjs.opts` [like mocha.opts](http://mochajs.org#mochaopts), except it looks for this file in the current directory.

````
--reporter
--timeout
--grep
--ui
--invert
--no-color
--slow
--bail
--require
````

These are all [Mocha command line options](http://mochajs.org/#usage) that mocha-casperjs supports. Currently the default timeout is 30 seconds, not two, as writing end to end tests takes more time.

Note the CasperJS cli parser does not support shorthands or spaces between parameters. So rather than `-g foo` and `--grep foo`, use `--grep=foo`

`--casper-timeout=<timeout in ms>`

Set Casper's timeout. If not set, no timeout will happen. This is one overall timeout for the entire test run.

`--wait-timeout=<timeout in ms>`

Set Casper's waitTimeout, the timeout used by the `waitFor*` family of functions. If not set, the casper default is used (as of this writting, it is 5 seconds)

`--step-timeout=<timeout in ms>`

Set Casper's stepTimeout, the timeout for individual steps. If not set, the casper default is used (as of this writing, no timeout is set).

`--file=<file>`

Pipe reporter output to the specified file instead of standard out. Use this if you have to filter out console messages from reporter output, like for `json`, `xunit`, etc. type of reporters. However, this only works if you the reporter uses `process.stdout.write`. If it uses `console.log`, mocha-casperjs cannot distinquish reporter output from test output. In that case, simply pipe the output to a file.

`--mocha-path=<path>`

Load [Mocha][] from the specified path, otherwise look for it adjacent to mocha-casperjs

`--chai-path=<path>`

Load [Chai][] from the specified path, otherwise look for it adjacent to mocha-casperjs

`--casper-chai-path=<path>`

Load [casper-chai][] from the specified path, otherwise look for it adjacent to mocha-casperjs

### CasperJS options

Also, you can add [CasperJS options](http://docs.casperjs.org/en/latest/modules/casper.html#index-1) to `mocha-casperjs.opts`. Below are the supported options:

````
--user-agent
--viewport-width
--viewport-height
--client-scripts
````

`--user-agent=<userAgent>`

Sets the `User-Agent` string (like `Mozilla/4.0 (compatible; MSIE 6.0; Windows NT 5.1)`) to send through headers when performing requests. 

`--viewport-width=<pixels> --viewport-height=<pixels>`

Sets the `PhantomJS` viewport to custom size. Useful for testing media queries and capturing screenshots:

```
casper.on('load.finished', function (resource) {
  this.captureSelector(screenshots_path + 'body.png', 'body');
});
```

`--client-scripts=<file1>,<file2>`

A comma seperated list of files to inject into the remote client every page load.

### PhantomJS options

Any phantomjs options (use `phantomjs --help` - online documentation is very old) will be passed through as-is to casperjs, which then passes them to phantomjs. Note you cannot pass them via `mocha-casperjs.opts` file, as these options are only for specific options that `mocha-casperjs` knows about.

## Custom 3rd party Reporters

You can provide your own reporter via the `--reporter` flag. mocha-phantomjs will try to `require` the module and load it. Some things to take note of:

- Both node modules and script files can be required, so for relative paths to scripts, make sure they start with '.'. E.g. use `--reporter=./foo` to load `foo.js` that is in the current directory. CoffeeScript files can be directly required too, as phantomjs has coffeescript built in.
- *PhantomJS is not node.js.* You won't have access to standard node modules like `url`, `http`, etc. Refer to [PhantomJS's built in modules](https://github.com/ariya/phantomjs/wiki/API-Reference#wiki-module-api). However, mocha-casperjs does provide a very minimalistic `process` shim to PhantomJS's `system` module.
- If you want access to built-in Mocha reporters, they are available on `Mocha.reporters`. For example, `Mocha.reporters.Base`.

## Tips to writing tests

1. Only call `casper.start` once. casper initializes state in this call and it doesn't support being called twice. use `casper.thenOpen` if you need to navigate to another page later on
2. Make sure your casper operations are in a step. If a step isn't added in a test or test hook, mocha-casperjs will not tell mocha to wait for casper.
3. Capser's timeout is overall for the entire test run, and mocha's timeout is per hook/test. Casper uses separate timeouts for waits, and they can be overridden every `waitFor` call. Mocha also allows overridding timeout per test and hook.

## How it works

mocha-casperjs is a big conglomeration of various ideas and approaches.
- It patches Mocha's `Runnable` to have every runabble be async and flush the casper tests - an approach taken from [mocha-as-promised][].
- It replaces `Mocha.process.stdout` with phantom's, including formatting - an approach taken from [mocha-phantomjs][]
- It attaches to Casper error events and fails the test with the last error that occoured.

[CasperJS]: http://casperjs.org/
[Chai]: http://chaijs.com/
[Mocha]: http://mochajs.org/
[mocha-as-promised]: http://github.com/domenic/mocha-as-promised
[mocha-phantomjs]: http://github.com/metaskills/mocha-phantomjs
[casper-chai]: https://github.com/brianmhunt/casper-chai
[npm]: https://npmjs.org/
[Tester]: http://casperjs.org/api.html#tester
[slimerjs]: http://www.slimerjs.org/
[phantomjs]: http://www.phantomjs.org/
