debugger;
var cli = require('cli').parse(phantom.args),
    fs = require('fs'),
    searchPaths = ['./node_modules', '../node_modules', '/usr/local/node_modules'],
    chai,

find = function(what, optional) {
  for (var i = 0; i < searchPaths.length; i++) {
    var pathItem = searchPaths[i] + fs.separator + what;
    if (fs.exists(pathItem)) {
      return fs.absolute(pathItem)
    }
  }

  if (optional) return
  console.log('Unable to find "' + what + '". Try specifying the path explicity via --' + what)
  casper.exit(-3)
}

// Load casper
this.casper = require('casper').create({
  exitOnError: false
})

// find where Mocha lives, then load the precompiled mocha from the root of it's module directory
require((cli.options['mocha-path'] || find('mocha')) + '/mocha')

// find where Chai lives and load it's precompiled version at the root of it's module directory
// this shouldn't be needed for chai or casper-chai once casperjs removes the patchedRequire
var chaiPath = cli.options['chai-path'] || find('chai', true)
if (chaiPath) {
  chai = require(chaiPath)
  chai.should()

  // optionally try to use casper-chai if available
  try {
    chai.use(require('casper-chai'))
    console.log('using casper-chai')
  } catch(e) { }
}

// Initialize the core of mocha-casperjs given the loaded Mocha class and casper instance
require(fs.absolute('../mocha-casperjs'))(Mocha, casper)

mocha.setup({
  ui: 'bdd',
  reporter: 'spec',
  timeout: 5000
});

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

console.log(JSON.stringify(tests))
tests.map(function(test) {
  return fs.absolute(test).replace('.coffee', '').replace('.js', '')
}).forEach(function(test) {
  console.log('loading test ' + test)
  require(test)
})

// for convience, expose the current runner on the mocha global
mocha.runner = mocha.run(function() {
  casper.exit(typeof (mocha.runner && mocha.runner.stats && mocha.runner.stats.failures) === 'number' ? mocha.runner.stats.failures : -1);
});