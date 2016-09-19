var cli = require('cli'),
    cliOptions = cli.parse(require('system').args.slice(1)),
    opts = cliOptions.options,
    optsFile = opts.opts || 'mocha-casperjs.opts',
    fs = require('fs'),
    Casper = require('casper'),
    extraArgs = [],

getPathForModule = function(what) {
  return fs.absolute(opts[what + '-path'] || opts['mocha-casperjs-path'] + '/../../node_modules/' + what)
}

if (fs.exists(optsFile)) {
  var extraOpts = cli.parse(['blah'].concat(fs.read(optsFile).split('\n'))).options
  extraArgs = cli.parse((fs.read(optsFile).split('\n'))).args;

  for (var p in extraOpts) {
    if (opts[p] == null) {
      opts[p] = extraOpts[p]
    }
  }
}

// Load casper
this.casper = Casper.create({
  exitOnError: true,
  timeout: opts['casper-timeout'],
  verbose: !!opts.verbose || opts['log-level'] === 'debug',
  logLevel: opts['log-level'] || 'warning',
  pageSettings: {
    userAgent: opts['user-agent']
  },
  viewportSize: {
    width: opts['viewport-width'],
    height: opts['viewport-height']
  }
})
if (typeof opts['client-scripts'] === 'string') {
  this.casper.options.clientScripts = opts['client-scripts'].split(',')
}
if (typeof opts['wait-timeout'] === 'number') {
  this.casper.options.waitTimeout = opts['wait-timeout']
}
if (typeof opts['step-timeout'] === 'number') {
  this.casper.options.stepTimeout = opts['step-timeout']
}

this.xpath = Casper.selectXPath

if (phantom.casperVersion.major !== 1 && phantom.capserVersion.minor < 1) {
  console.log('mocha-casperjs requires CasperJS >= 1.1.0-beta3')
  casper.exit(-1)
}

// Load the precompiled mocha from the root of it's module directory
require(getPathForModule('mocha') + '/mocha')

try {
  this.chai = require(getPathForModule('chai'))
  this.chai.should()

  // ugly but isolated hack for #40
  if (['function', 'object'].indexOf(typeof casper.__proto__.fetchText) > -1 && casper.__proto__.fetchText.toString().indexOf('fetchText') === -1) {
    casper.log('restoring Casper#fetchText', 'debug', 'mocha-casperjs')
    casper.__proto__.fetchText = function(selector) {
      this.checkStarted()
      return this.callUtils("fetchText", selector)
    }
  }

  // expect globally if requested
  this.expect = this.chai.expect

  // optionally try to use casper-chai if available
  try {
    this.chai.use(require(getPathForModule('casper-chai')))
    casper.log('using casper-chai', 'debug', 'mocha-casperjs')
  }
  catch (e) {
    casper.log('could not load casper-chai: ' + e, 'debug', 'mocha-casperjs')
  }
} catch (e) {
  casper.log('could not load chai ' + e, 'debug', 'mocha-casperjs')
}

// Initialize the core of mocha-casperjs given the loaded Mocha class and casper instance
require(fs.absolute((opts['mocha-casperjs-path'] || '..') + '/mocha-casperjs'))(Mocha, casper, require('utils'))

mocha.setup({
  ui: opts.ui || 'bdd',
  timeout: opts.timeout || 30000,
  bail: opts.bail || false,
  useColors: !opts['no-color']
})

if (typeof process === 'undefined') {
  // a poor node.js process shim - totally not great
  var sys = require('system')
  this.process = {
    pid: sys.pid,
    env: sys.env,
    argv: sys.args.splice(),
    stdin: sys.stdin,
    stdout: sys.stdout,
    stderr: sys.stderr
  }
}

// Remember that PhantomJS is not Node.js - the modules available to phantomjs are different than node's.
// If you need access to built-in Mocha reporters, access them off of `Mocha.reporters`, like `Mocha.reporters.Base`.
// fall back to spec by default
var reporter = 'spec'

if (opts.reporter) {
  // CasperJS's patched require searches it's own modules folder which has an `xunit` reporter already.
  // See https://github.com/nathanboktae/mocha-casperjs/issues/68
  // For a few well-known reporters let's just directly load them.
  if (['spec', 'xunit', 'json'].indexOf(opts.reporter) !== -1) {
    reporter = opts.reporter
  }
  else {
    // check to see if it is a third party reporter
    try {
      // I don't want to use isAbsolute here as it could be a node module or a relative path
      if (opts.reporter.indexOf('.') === 0) {
        opts.reporter = fs.absolute(opts.reporter)
      }
      reporter = require(opts.reporter)
    } catch (e) {
      reporter = opts.reporter
    }
  }
}

// If a third party error throws an error, exit.
try {
  mocha.reporter(reporter)
} catch(e) {
  casper.exit(-2);
}


if (opts.grep) {
  mocha.grep(opts.grep)
  if (opts.invert) {
    mocha.invert()
  }
}

if (opts.file) {
  Mocha.process.stdout = fs.open(opts.file, 'w')
  if (this.process) {
    this.process.stdout = Mocha.process.stdout
  }
}

if (opts.slow) {
  mocha.slow(opts.slow)
}

if (opts.require) {
  require(fs.absolute(opts.require));
}

// load the user's tests
var tests = []

if (cliOptions.args.length > 1) {
  // use tests if they specified them explicty
  tests = cliOptions.args.slice()
  tests.shift()
} else {
  // otherwise, load files from the opts directory, test or tests directory like Mocha does
  var testDir = extraArgs.length && extraArgs[0] || null
  if (!fs.isDirectory(testDir)) {
    if (fs.isDirectory('test')) {
        testDir = 'test'
    } else if (fs.isDirectory('tests')) {
      testDir = 'tests'
    } else {
      console.log('No tests specified. List them in the console, or add your tests to a "test" or "tests" folder in the current working directory.')
      casper.exit(-4)
    }
  }
  tests = fs.list(testDir).filter(function(test) {
    return test.match(/(\.js|\.coffee)$/)
  }).map(function(test) {
    return testDir + fs.separator + test
  })
}

tests.map(function(test) {
  return fs.absolute(test).replace('.coffee', '').replace('.js', '')
}).forEach(function(test) {
  require(test)
})

// You can now set breakpoints in your scripts since they are loaded now
debugger;

// for convience, expose the current runner on the mocha global
mocha.runner = mocha.run(function() {
  if (opts.file) {
    Mocha.process.stdout.close()
  }
  casper.exit(typeof (mocha.runner && mocha.runner.stats && mocha.runner.stats.failures) === 'number' ? mocha.runner.stats.failures : -1);
});
