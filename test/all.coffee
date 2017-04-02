spawn = require('child_process').spawn
util = require 'util'
fs = require 'fs'

chai = require 'chai'
chai.should()

runMochaCasperJsTest = (test, callback) ->
  if typeof test is 'string' or typeof test.test is 'string'
    testfile = "#{__dirname}/#{test.test or test}"
  else if typeof test is 'object'
    testfile = __dirname + '/temptest.js'
    fs.writeFile testfile, "
      describe('in casperjs', function() {
        before(#{ test.before or (-> casper.start('http://localhost:10473/sample')) });
        it('the test', #{ test.test });
        #{ if test.after then 'after(' + (->) + ');' else '' }
      });", (err) -> throw err if err

  process = spawn './node_modules/casperjs/bin/casperjs', [
    './bin/cli.js',
    '--mocha-path=node_modules/mocha',
    '--chai-path=node_modules/chai',
    '--casper-chai-path=node_modules/casper-chai',
    testfile].concat(test.params or [])
  output = ''

  process.stdout.on 'data', (data) ->
    output += data

  process.stderr.on 'data', (data) ->
    output += data

  process.on 'close', (code) ->
    callback output, code

thisShouldPass = (test, done) ->
  runMochaCasperJsTest test, (output, code) ->
    if code isnt 0
      console.log output
      throw new Error 'expected the test to pass, but it did not. Output above'
    done()

thisShouldFailWith = (test, failureText, expectedCode, done) ->
  done = expectedCode if not done?
  runMochaCasperJsTest test, (output, code) ->
    if code is 0 or output.indexOf(failureText) < 0 and (typeof expectedCode isnt 'number' or code is expectedCode)
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
        test: ->
          casper.waitForSelector 'h1', ->
            /mocha-casperjs/.should.matchTitle
          casper.then ->
            'h1'.should.have.text 'Hello World!'
      , done

    it 'should expose the selectXPath module as the `xpath` global', (done) ->
      thisShouldPass
        test: ->
          xpath.should.be.a('function')
      , done

  describe 'CasperJS error handling', ->
    it 'should fail when a step fails', (done) ->
      thisShouldFailWith
        test: ->
          casper.then ->
            1.should.not.be.ok
      , 'AssertionError', done

    it 'should not exit abruptly when a step fails', (done) ->
      runMochaCasperJsTest
        params: ['--reporter=json'],
        test: ->
          casper.then ->
            1.should.not.be.ok
      , (output, code) ->
        try
          results = JSON.parse output
        catch
          throw new Error 'Expected JSON output from the reporter, instead was' + output
        results.stats.passes.should.equal 0
        results.stats.failures.should.equal 1
        code.should.equal 1
        done()

    it 'should fail when a step fails in before', (done) ->
      thisShouldFailWith
        before: ->
          casper.start 'sample.html', ->
            throw new Error 'boom'
        test: ->
          casper.then ->
            1.should.be.ok
      , 'boom', done

    it 'should fail nested tests if a before fails', (done) ->
      thisShouldFailWith 'failing-before.js', '"before all" hook', 1, done

    it 'should not fail subsequent tests if a before fails in another describe block', (done) ->
      thisShouldFailWith 'failing-subsequent.js', 'subsequent-failure', 2, done

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
        params: ['--timeout=400', '--no-color']
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

    it 'should ensure all errors in a particular test are reported for that test', (done) ->
      runMochaCasperJsTest
        params: ['--reporter=json']
        before: ->
          casper.start()
        test: 'failing-cascading.js'
      , (output, code) ->
        results = JSON.parse output

        (failure.title for failure in results.failures).should.deep.equal [
          'should run and report 1 failure', 'should fail a second time']

        (pass.title for pass in results.passes).should.deep.equal [
          'should pass', 'should pass a second time', 'should pass a third time']

        code.should.equal(2)
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
    it 'should always expose chai.expect globally', (done) ->
      thisShouldPass
        before: (->)
        test: ->
          expect('hi').to.be.a 'string'
      , done

    it '--timeout should set Mocha\'s timeout value', (done) ->
      thisShouldFailWith
        params: ['--timeout=139']
        before: ->
          casper.start 'http://localhost:10473/timeout'
        test: ->
          casper.then ->
            throw new Error 'we should have timed out'
      , 'timeout of 139ms exceeded', done

    it '--casper-timeout should set Casper\'s timeout value', (done) ->
      thisShouldFailWith
        params: ['--casper-timeout=414']
        before: ->
          casper.start 'http://localhost:10473/timeout'
        test: ->
          casper.then ->
            throw new Error 'we should have timed out'
      , '414', done

    it '--wait-timeout should set Casper\'s waitTimeout for wait* functions', (done) ->
      thisShouldFailWith
        params: ['--wait-timeout=105']
        test: ->
          casper.waitForSelector '.nonexistant', ->
            throw new Error 'we should have timed out'
      , '105', done

    it '--step-timeout should set Casper\'s stepTimeout for steps', (done) ->
      thisShouldFailWith
        params: ['--step-timeout=139']
        test: ->
          casper.then ->
            casper.wait 800, -> throw new Error 'this should not happen'
      , '139', done

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

    it '--require should require files before tests are run', (done) ->
      thisShouldPass
        params: ['--require=./test/helper.js']
        test: ->
          helper()
          casper.waitForSelector 'h1', ->
            /mocha-casperjs/.should.matchTitle
          casper.then ->
            'h1'.should.have.text 'Hello World!'
      , done

    it '--require should require the last file if multiple --require are passed', (done) ->
      thisShouldPass
        params: ['--require=./test/does-not-exist.js', '--require=./test/helper.js']
        test: ->
          helper()
          casper.waitForSelector 'h1', ->
            /mocha-casperjs/.should.matchTitle
          casper.then ->
            'h1'.should.have.text 'Hello World!'
      , done

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

    it '--reporter should import a third-party reporter module', (done) ->
      runMochaCasperJsTest
        params: ['--reporter=./reporters/jason']
        test: ->
          1.should.be.ok
      , (output, code) ->
        results = JSON.parse output
        results.stats.passes.should.equal 1
        results.stats.failures.should.equal 0
        results.failures.should.be.empty
        done()

    it 'should support the xunit reporter and avoid CasperJS xunit module', (done) ->
      runMochaCasperJsTest
        params: ['--reporter=xunit']
        test: ->
          1.should.be.ok
      , (output, code) ->
        code.should.equal 0
        output.should.match /<testsuite/
        done()

    it 'using --file with a third-party reporter should pipe it\'s output to that file', (done) ->
      runMochaCasperJsTest
        params: ['--reporter=./reporters/jason', '--file=filepipe.json']
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

    it 'a third-party reporter should have access to stdout and stderr', (done) ->
      runMochaCasperJsTest
        params: ['--reporter=./test/process-reporter']
        test: ->
          1.should.be.ok
      , (output, code) ->
        output.indexOf("Can\'t find variable: process").should.equal(-1)
        output.indexOf('stdout').should.be.above(-1)
        output.indexOf('stderr').should.be.above(-1)
        done()

    it '--bail should fail on the first failure', (done) ->
      thisShouldFailWith
        params: ['--bail', '--reporter=dot'],
        test: 'failing-subsequent'
      , '1 failing', 1, done

    it '--user-agent should set the user agent', (done) ->
      thisShouldPass
        params: ['--user-agent=mocha-casperjs-tests'],
        test: ->
          casper.page.settings.userAgent.should.equal 'mocha-casperjs-tests'
      , done

    it '--viewport-width and --viewport-height should set the viewport dimentions', (done) ->
      thisShouldPass
        params: ['--viewport-height=400', '--viewport-width=300'],
        test: ->
          (-> window.innerWidth).should.evaluate.to.equal 300
          (-> window.innerHeight).should.evaluate.to.equal 400
      , done

    it '--client-scripts should inject client scripts via casper options', (done) ->
      thisShouldPass
        params: ['--client-scripts=test/client-injection-1.js'],
        test: ->
          (-> window.injection1).should.evaluate.to.equal 'Client Injection script one'
      , done

    it '--client-scripts should allow multiple scripts', (done) ->
      thisShouldPass
        params: ['--client-scripts=test/client-injection-1.js,test/client-injection-2.js'],
        test: ->
          (-> window.injection1).should.evaluate.to.equal 'Client Injection script one'
          (-> window.injection2).should.evaluate.to.equal 'Client Injection script two'
      , done

    it 'should handle lots of args', (done) ->
      thisShouldPass
        params: ['--slow=30000', '--no-color', '--reporter=json', '--some-flag', '--foo=bar', '--theanswer=42'],
        test: ->
          1.should.be.ok
      , done

    describe 'mocha-casperjs.opts', ->
      afterEach ->
        fs.unlinkSync 'mocha-casperjs.opts'
      after ->
        fs.unlinkSync 'some-other-mocha-casperjs.opts'

      it 'should apply options from the file if available', (done) ->
        fs.writeFileSync 'mocha-casperjs.opts', '--reporter=json'
        runMochaCasperJsTest
          test: ->
            'hi'.should.be.a 'string'
        , (output, code) ->
          results = JSON.parse output
          results.stats.passes.should.equal 1
          results.stats.failures.should.equal 0
          done()

      it 'should merge with command line options, prioritizing the command line', (done) ->
        fs.writeFileSync 'mocha-casperjs.opts', '--reporter=spec\n--user-agent=mocha-casperjs-tests'
        runMochaCasperJsTest
          params: ['--reporter=json']
          test: ->
            casper.page.settings.userAgent.should.equal 'mocha-casperjs-tests'
        , (output, code) ->
          results = JSON.parse output
          results.stats.passes.should.equal 1
          results.stats.failures.should.equal 0
          done()

      it 'should use an opts file from another location', (done) ->
        fs.writeFileSync 'mocha-casperjs.opts', '--user-agent=wrong-optsfile'
        fs.writeFileSync 'some-other-mocha-casperjs.opts', '--user-agent=some-other-mocha-casperjs-opts'
        runMochaCasperJsTest
          params: ['--reporter=json', '--opts=some-other-mocha-casperjs.opts']
          test: ->
            casper.page.settings.userAgent.should.equal 'some-other-mocha-casperjs-opts'
        , (output, code) ->
          results = JSON.parse output
          results.stats.passes.should.equal 1
          results.stats.failures.should.equal 0
          done()

  describe 'Steps checking', ->
    describe 'Should run all steps if the previous test failed', ->
      it 'should run all steps if the previous test failed on the last step', (done) ->
        runMochaCasperJsTest
          test: 'all-steps-after-failing-on-last-step.js'
        , (output, code) ->
          code.should.equal 1
          output.should.contain 'THEN 1'
          output.should.contain 'THEN 2'
          output.should.contain 'THEN 3'
          done()

      it 'should run all steps if the previous test failed on not last step', (done) ->
        runMochaCasperJsTest
          test: 'all-steps-after-failing-on-not-last-step.js'
        , (output, code) ->
          code.should.equal 1
          output.should.contain 'THEN 1'
          output.should.contain 'THEN 3'
          output.should.contain 'THEN 4'
          done()

      it 'should run all steps if the previous test failed on the last sub step', (done) ->
        runMochaCasperJsTest
          test: 'all-steps-after-failing-on-last-sub-step.js'
        , (output, code) ->
          code.should.equal 1
          output.should.contain 'THEN 1'
          output.should.contain 'THEN 2'
          output.should.contain 'THEN 3'
          done()

      it 'should run all steps if the previous test failed on not last sub step', (done) ->
        runMochaCasperJsTest
          test: 'all-steps-after-failing-on-not-last-sub-step.js'
        , (output, code) ->
          code.should.equal 1
          output.should.contain 'THEN 1'
          output.should.contain 'THEN 3'
          output.should.contain 'THEN 4'
          done()

  after -> server.close()
