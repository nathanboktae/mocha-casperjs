module.exports = (casper) ->
  casperInstance = casper.create
    exitOnError: false

  require('../node_modules/mocha/mocha')
  require('../mocha-casperjs')(Mocha, casperInstance)

  chai = require '../node_modules/chai/chai'
  chai.use require 'casper-chai'
  chai.should()

  return casperInstance