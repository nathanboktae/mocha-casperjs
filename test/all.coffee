spawn = require('child_process').spawn
util = require 'util'
fs = require 'fs'

chai = require 'chai'
chai.should()

runMochaCasperJsTest = (test, callback) ->
  if typeof test is 'string'
    testfile = test
  else if typeof test is 'object'
    testfile = __dirname + '/temptest.js'
    fs.readFile __dirname + '/test.template',
      encoding: 'utf8'
    , (err, template) ->
      throw err if err
      testContents = util.format template, test.reporter or 'spec', test.before or (-> casper.start('sample.html')), test.test, test.after or (->)
      fs.writeFile testfile, testContents, (err) -> throw err if err

  process = spawn('casperjs', [testfile])
  output = ''

  process.stdout.on 'data', (data) ->
    output += data

  process.on 'close', (code) ->
    callback output, code

thisShouldPass = (test, done) ->
  runMochaCasperJsTest test, (output, code) ->
    if code isnt 0
      console.log output
      throw new Error 'expected the test to pass, but it did not. Output above'
    done()

thisShouldFailWith = (test, failureText, done) ->
  runMochaCasperJsTest test, (output, code) ->
    if code is 0 or output.indexOf(failureText) < 0
      console.log output
      throw new Error 'expected the test to fail with "' + failureText + '" in the failures, but it passed'
    done()

describe 'Mocha Runnable shim', ->
  server = null
  port = 10473
  before ->
    server = require('http').createServer (req, res) ->
      echoStatus = req.url?.match(/echo\/(\d+)/)
      if echoStatus?[1]
        res.statusCode = echoStatus[1]
        res.end()
    server.listen port
  
  it 'should flush all the steps at the end of a test', (done) ->
    thisShouldPass
      test: ->
        casper.then ->  
          mocha.stepsRan = true
      after: ->
        mocha.stepsRan.should.be.true.mmmkay
    , done

  it 'should not flush steps at other hooks', (done) ->
    thisShouldPass
      before: ->
        casper.start 'http://bing.com/'
      test: ->
        casper.steps.length.should.be.above 0
    , done

  it 'should work as normal when no steps were added', (done) ->
    thisShouldPass
      test: ->
        1.should.be.ok
    , done

  it 'should fail when a step failz', (done) ->
    thisShouldFailWith
      test: ->
        casper.then ->
          1.should.not.be.ok
    , 'AssertionError', done

  it 'should fail when a step fails in before', (done) ->
    thisShouldFailWith
      before: ->
        casper.start 'sample.html', ->
          throw new Error 'boom'
      test: ->
        casper.then ->
          1.should.be.ok
    , 'boom', done

  it 'should fail when waitFor times out', (done) ->
    thisShouldFailWith
      before: ->
        casper.start 'http://bing.com'
      test: ->
        casper.waitForSelector 'h1.nonexistant', ->
          throw new Error 'we found it?!?'
        casper.then -> throw new Error 'this shouldnt get here'
    , 'timeout', done

  after -> server.close()

describe 'Mocha process.stdout redirection', ->
  it 'should output results to the console', (done) ->
    runMochaCasperJsTest
      reporter: 'json',
      test: ->
        casper.then ->  
          1.should.be.ok
    , (output, code) ->
      results = JSON.parse output
      results.stats.passes.should.equal 1
      results.stats.failures.should.equal 0
      results.failures.should.be.empty
      done()

    