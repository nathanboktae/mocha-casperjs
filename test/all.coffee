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

  fs.writeFile testfile, "
    describe('in casperjs', function() {
      before(#{ test.before or (-> casper.start('http://localhost:10473/sample')) });
      it('the test', #{ test.test });
      after(#{ test.after or (->) });
    });", (err) -> throw err if err

  process = spawn './bin/mocha-casperjs', ['--mocha-path=node_modules/mocha', '--chai-path=node_modules/chai', testfile].concat(test.params or [])
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


describe 'mocha-casperjs', ->
  server = null
  before ->
    server = require('http').createServer (req, res) ->
      echoStatus = req.url?.match(/echo\/(\d+)/)
      if echoStatus?[1]
        res.statusCode = echoStatus[1]
        res.end()
      else if req.url is '/sample'
        res.writeHead '200', 
          'Content-Type': 'text/html'
        res.end sampleHtml
      else if req.url is '/timeout'
        res.writeHead '200'
        setTimeout ->
          res.end()
        , 100000
      else
        res.write '404'
        res.end()
    server.listen 10473
  

  describe 'Mocha Runnable shim', ->
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

    it 'should have a simple test pass', (done) ->
      thisShouldPass
        params: ['--casper-chai-path=node_modules/casper-chai']
        test: ->
          casper.waitForSelector 'h1', ->
            /mocha-casperjs/.should.matchTitle
          casper.then ->
            'h1'.should.have.text 'Hello World!'
      , done


  describe 'CasperJS error handling', ->   
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
      , '5000ms', done

    it 'should fail when the page times out', (done) ->
      thisShouldFailWith
        params: ['--casper-timeout=3000']
        before: ->
          casper.start 'http://localhost:10473/timeout'
        test: ->
          casper.then ->
            throw new Error 'we should have timed out'
      , 'timeout', done

    it 'should not fail a test twice', (done) ->
      runMochaCasperJsTest
        params: ['--timeout=500', '--no-color']
        before: ->
          casper.start()
        test: (done) ->
          casper.then ->
            casper.wait 400, ->
              1.should.not.be.ok
      , (output, code) ->
        output.should.not.contain 'multiple'
        output.should.contain '1 failing'
        code.should.not.equal 0
        done()

    it 'failCurrentTest should allow tests to be failed', (done) ->
      runMochaCasperJsTest
        test: ->
          casper.on 'page.error', (msg, trace) ->
            mocha.failCurrentTest new Error('error from page: ' + msg)
          casper.evaluate ->  
            window.foobarkaboom.blahblah
      , (output, code) ->
        code.should.not.equal 0
        output.should.contain('1 failing')
              .and.contain('0 passing')
              .and.contain('foobarkaboom')
        done()

  describe 'Mocha process.stdout redirection', ->
    it 'should output results to the console', (done) ->
      runMochaCasperJsTest
        params: ['--reporter=json'],
        test: ->
          casper.then ->  
            1.should.be.ok
      , (output, code) ->
        results = JSON.parse output
        results.stats.passes.should.equal 1
        results.stats.failures.should.equal 0
        results.failures.should.be.empty
        done()

  describe 'Command line options', ->
    it '--expect should expose chai.expect globally', (done) ->
      thisShouldPass
        params: ['--expect'],
        before: (->)
        test: ->
          expect('hi').to.be.a 'string'
      , done

    it '--casper-timeout should set Casper\'s timeout value', (done) ->
      thisShouldFailWith
        params: ['--casper-timeout=1234']
        before: ->
          casper.start 'http://localhost:10473/timeout'
        test: ->
          casper.then ->
            throw new Error 'we should have timed out'
      , '1234', done

    it '--timeout should set Mocha\'s timeout value', (done) ->
      thisShouldFailWith
        params: ['--timeout=789']
        before: ->
          casper.start 'http://localhost:10473/timeout'
        test: ->
          casper.then ->
            throw new Error 'we should have timed out'
      , 'timeout of 789ms exceeded', done

    it '--grep should filter tests', (done) ->
      runMochaCasperJsTest
        params: ['--grep=nonexistanttest']
        test: ->
          throw new Error 'test ran'
      , (output, code) ->
        output.should.not.contain 'failing'
        output.should.not.contain 'test ran'
        output.should.contain '0 passing'
        done()

    it '--grep with --invert should filter out tests', (done) ->
      runMochaCasperJsTest
        params: ['--grep=casperjs', '--invert']
        test: ->
          throw new Error 'test ran'
      , (output, code) ->
        output.should.not.contain 'failing'
        output.should.not.contain 'test ran'
        output.should.contain '0 passing'
        done()

    it '--no-color should turn off color codes', (done) ->
      runMochaCasperJsTest
        params: ['--no-color']
        test: ->
          1.should.be.ok
      , (output, code) ->
        output.should.contain '1 passing'
        output.should.not.contain '[0m'
        done()

    it '--slow should set the slow threshold', (done) ->
      runMochaCasperJsTest
        params: ['--slow=30000', '--no-color']
        test: ->
          casper.wait 1000, ->
            console.log 'slow but not that slow'
      , (output, code) ->
        output.should.not.match /\d+ms/
        done()

    it '--file should pipe reporter output to a file', (done) ->
      runMochaCasperJsTest
        params: ['--file=filepipe.json', '--reporter=json', '--log-level=info']
        test: ->
          casper.log 'bla blah that is not valid json', 'info'
          1.should.be.ok
      , (output, code) ->
        results = JSON.parse fs.readFileSync 'filepipe.json'
        fs.unlink 'filepipe.json', (->)
        results.stats.passes.should.equal 1
        results.stats.failures.should.equal 0
        results.failures.should.be.empty
        done()

    describe 'mocha-casperjs.opts', ->
      afterEach ->
        fs.unlinkSync 'mocha-casperjs.opts'

      it 'should apply options from the file if available', (done) ->
        fs.writeFileSync 'mocha-casperjs.opts', '--expect'
        thisShouldPass
          test: ->
            expect('hi').to.be.a 'string'
        , done

      it 'should merge with command line opitons, prioritizing the command line', (done) ->
        fs.writeFileSync 'mocha-casperjs.opts', 'reporter=min\n--expect'
        runMochaCasperJsTest
          params: ['--reporter=json']
          test: ->
            expect('hi').to.be.a 'string'
        , (output, code) ->
          results = JSON.parse output
          results.stats.passes.should.equal 1
          results.stats.failures.should.equal 0
          done()       

  after -> server.close()
    