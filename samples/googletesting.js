var casper = require('casper').create({
  exitOnError: false,
  pageSettings: {
    loadImages: false,
    loadPlugins: false
  },
  onLoadError: function (_casper, url) {
    console.log('[onLoadError]: ' + url);
  },
  onTimeout: function (err) {
    console.log('[Timeout]: ' + err);
  }
});

require('../node_modules/mocha/mocha')
require('../mocha-casperjs')(Mocha, casper)

var chai = require('../node_modules/chai/chai')
var casperChai = require('../../casper-chai/lib/casper-chai')

chai.use(casperChai)
chai.should()

mocha.setup({
  ui: 'bdd',
  reporter: 'spec'
})

describe('Google searching', function() {
  before(function() {
    casper.start('http://www.google.fr/')
  })

  it('should retrieve 10 or more results', function() {
    casper.then(function() {
      'Google'.should.matchTitle
      'form[action="/search"]'.should.be.inDOM
      this.fill('form[action="/search"]', {
          q: 'casperjs'
        }, true)
    })

    casper.then(function() {
      'casperjs - Recherche Google'.should.matchTitle;
      (/q=casperjs/).should.matchUrl
    })
  })
})

mocha.run(function() {
  casper.exit()
})