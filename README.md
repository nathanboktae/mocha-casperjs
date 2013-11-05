# CasperJS automation via Mocha [![Build Status](https://secure.travis-ci.org/nathanboktae/mocha-casperjs.png?branch=master)](https://travis-ci.org/nathanboktae/mocha-casperjs)

Combine the power of [casperjs][]' automation with [Mocha][]'s robust testing framework features

## Features
- automatically load Casper, Mocha, and optionally [chai][] and [casper-chai][]
- automatically run your Casper steps after each test
- use any Mocha reporter that can run in the [phantomjs][] or [slimerjs][] environment

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

Like Mocha, if you place your tests in the `test` or `tests` directory, it will find them and run them. You can also specify tests to run individually instead.

## Command Line Options

````
--reporter
--timeout
--grep
````

These are all [Mocha command line options](http://visionmedia.github.io/mocha/#usage) that mocha-casperjs supports. Currently the default timeout is 30 seconds, not two, as writing end to end tests takes more time.

Note the CasperJS cli parser does not support shorthands or spaces between parameters. So rather than `-g foo` and `--grep foo`, use `--grep=foo`

`--casper-timeout=<timeout in ms>`

Set Casper's timeout. Defaults to 5 seconds. You will want this less than Mocha's.

`--expect`

Expose `chai.expect` as global `expect`

`--file=<file>`

Pipe reporter output to the specified file instead of standard out. Use this if you have to filter out console messages from reporter output, like for `json`, `xunit`, etc. type of reporters


`--mocha-path=<path>`

Load [Mocha][] from the specified path

`--chai-path=<path>`

Load [Chai][] from the specified path

`--casper-chai-path=<path>`

Load [casper-chai][] from the specified path

## How it works

mocha-casperjs is a big conglomeration of various ideas and approaches.
- It patches Mocha's `Runnable` to have every runabble be async and flush the casper tests - an approach taken from [mocha-as-promised][].
- It replaces `Mocha.process.stdout` with phantom's, including formatting - an approach taken from [mocha-phantomjs][]
- It attaches to Casper error events and fails the test with the last error that occoured.

[CasperJS]: http://casperjs.org/
[Chai]: http://chaijs.com/
[Mocha]: http://visionmedia.github.com/mocha/
[mocha-as-promised]: http://github.com/domenic/mocha-as-promised
[mocha-phantomjs]: http://github.com/metaskills/mocha-phantomjs
[casper-chai]: https://github.com/brianmhunt/casper-chai
[npm]: https://npmjs.org/
[Tester]: http://casperjs.org/api.html#tester
[slimerjs]: http://www.slimerjs.org/
[phantomjs]: http://www.phantomjs.org/
