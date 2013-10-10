spawn = require('child_process').spawn

runMochaCasperJsTest = (test, callback) ->
  if typeof test is 'string'
    testname = test
  else if typeof test is 'function'
    # todo
    throw new Error 'need to implement the write on the fly test'

  process = spawn('casperjs', [test])
  output = ''

  process.stdout.on 'data', (data) ->
    output += data

  process.on 'close', (code) ->
    console.log 'Output: '
    console.log output
    result = JSON.parse output
    result.exitCode = code
    callback result

describe 'simple stuff', ->
  it 'should work', (done) ->
   runMochaCasperJsTest __dirname + '/simple.coffee', (res) ->
    console.log 'success!'
    done()
    