var cli = require('cli').parse(phantom.args),
    fs = require('fs'),
    searchPaths = ['./node_modules', '../node_modules', '/usr/local/node_modules'],

getPathForModule = function(what, optional) {
  var pathParam = cli.options[what + '-path']
  if (pathParam) {
    return fs.absolute(pathParam)
  }

  for (var i = 0; i < searchPaths.length; i++) {
    var pathItem = searchPaths[i] + fs.separator + what;
    if (fs.exists(pathItem)) {
      return fs.absolute(pathItem)
    }
  }

  if (optional) return
  console.log('Unable to find "' + what + '". Try specifying the path explicity via --' + what + '-path')
  casper.exit(-3)
}

// Load casper
this.casper = require('casper').create({
  exitOnError: true,
  timeout: cli.options['casper-timeout'] || 10000,
  verbose: !!cli.options.verbose || cli.options['log-level'] === 'debug',
  logLevel: cli.options['log-level'] ||'warning'
})

// find where Mocha lives, then load the precompiled mocha from the root of it's module directory
require(getPathForModule('mocha') + '/mocha')

// find where Chai lives and load it if found
var chaiPath = getPathForModule('chai', true)
if (chaiPath) {
  this.chai = require(chaiPath)
  this.chai.should()

  // expose expect globally if requested
  if (cli.options.expect) {
    this.expect = this.chai.expect
  }

  // optionally try to use casper-chai if available
  var casperChaiPath = getPathForModule('casper-chai', true)
  if (casperChaiPath) {
    this.chai.use(require(casperChaiPath))
  }
}

// Initialize the core of mocha-casperjs given the loaded Mocha class and casper instance
require(fs.absolute((cli.options['mocha-casperjs-path'] || '..') + '/mocha-casperjs'))(Mocha, casper, require('utils'))

mocha.setup({
  ui: 'bdd',
  reporter: cli.options.reporter || 'spec',
  timeout: cli.options.timeout || 30000
})

if (cli.options.grep) {
  mocha.grep(cli.options.grep)
}

// load the user's tests
var tests = []
if (cli.args.length > 1) {
  // use tests if they specified them explicty
  tests = cli.args.slice()
  tests.shift()
} else {
  // otherwise, load files from the test or tests directory like Mocha does
  var testDir = 'test'
  if (!fs.isDirectory(testDir)) {
    if (fs.isDirectory('tests')) {
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
  casper.exit(typeof (mocha.runner && mocha.runner.stats && mocha.runner.stats.failures) === 'number' ? mocha.runner.stats.failures : -1);
});