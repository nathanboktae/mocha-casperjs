@casper = require('./setup') require 'casper'

mocha.setup
  ui: 'bdd',
  reporter: 'json'

describe 'simple', ->
  before -> casper.start 'http://www.google.fr/'

  it 'can search google', ->
    casper.then ->
      'Google'.should.matchTitle
      'form[action="/search"]'.should.be.inDOM
      @fill 'form[action="/search"]',
          q: 'casperjs'
      , true

    casper.then ->
      'casperjs - Recherche Google'.should.matchTitle;
      (/q=casperjs/).should.matchUrl

mocha.run -> casper.exit()