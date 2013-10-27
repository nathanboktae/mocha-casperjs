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
      testContents = util.format template, test.reporter or 'spec', test.before or (-> casper.start('http://localhost:10473/sample')), test.test, test.after or (->)
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

sampleHtml = '<!doctype html>
  <html>
    <head>
      <title>mocha-casperjs tests</title>
    </head>
  <body>
    <h1>Hello World!</h1>
    <article></article>
  </body>
  </html>'

describe 'Mocha Runnable shim', ->
  server = null
  before ->
    server = require('http').createServer (req, res) ->
      echoStatus = req.url?.match(/echo\/(\d+)/)
      if echoStatus?[1]
        res.statusCode = echoStatus[1]
        res.end()
      if req.url is '/sample'
        res.writeHead '200', 
          'Content-Type': 'text/html'
        res.end sampleHtml
    server.listen 10473
  
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
      test: ->
        casper.steps.length.should.be.above 0
    , done

  it 'should work as normal when no steps were added', (done) ->
    thisShouldPass
      test: ->
        1.should.be.ok
    , done

  it 'should fail when a step fails', (done) ->
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
      test: ->
        casper.waitForSelector 'h1.nonexistant', ->
          throw new Error 'we found it?!?'
        casper.then -> throw new Error 'this shouldnt get here'
    , 'timeout', done

  it 'should fail when the page times out', (done) ->
    thisShouldFailWith
      before: ->
        casper.start 'http://localhost:10473/'
      test: ->
        casper.then ->
          /mocha-casperjs/.should.matchTitle
    , 'timeout', done

  xit 'should fail when the page doesnt exist', (done) ->
    # this should probably be configurable.
    thisShouldFailWith
      before: ->
        casper.start 'http://localhost:10473/echo/404'
      test: ->
        casper.then ->
          /mocha-casperjs/.should.matchTitle
    , 'timeout', done

  xit 'should fail when the page has an error', (done) ->
    thisShouldFailWith
      before: ->
        casper.start 'http://localhost:10473/echo/500'
      test: ->
        casper.then ->
          /mocha-casperjs/.should.matchTitle
    , '500', done

  it 'should have a simple test pass', (done) ->
    thisShouldPass
      test: ->
        casper.waitForSelector 'h1', ->
          /mocha-casperjs/.should.matchTitle
        casper.then ->
          'h1'.should.have.textMatch 'Hello World!'
    , done

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

    