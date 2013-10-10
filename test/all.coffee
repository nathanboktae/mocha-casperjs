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
      testContents = util.format template, test.before or (-> casper.start()), test.test, test.after or (->)
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

describe 'Mocha Runnable shim', ->
  it 'should flush all the steps at the end of a test', (done) ->
    thisShouldPass
      test: ->
        casper.then ->  
          mocha.stepsRan = true
      after: ->
        mocha.stepsRan.should.be.true.mmmkay
    , done
    