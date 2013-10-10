require 'setup'

describe 'casper steps', ->
  before -> casper.open 'http://www.google.fr/'

  it 'should flush and run all steps at the end of a test', ->
  	casper.then ->
      'Google'.should.matchTitle
      'form[action="/search"]'.should.be.inDOM
      @fill 'form[action="/search"]',
        q: 'casperjs'
      , true

    casper.then ->
      'casperjs - Recherche Google'.should.matchTitle
      (/q=casperjs/).should.matchUrl
