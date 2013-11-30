if (typeof chai === 'undefined' || !('inDOM' in chai.Assertion.prototype)) {
  console.log('This example requires chai and casper-chai to be installed adjacent to mocha-casperjs')
  casper.exit(-1)
}

describe('Google searching', function() {
  before(function() {
    casper.start('http://www.google.fr/')
  })

  it('should retrieve 10 or more results', function() {
    casper.then(function() {
      'Google'.should.matchTitle
      'form[action="/search"]'.should.be.inDOM.and.be.visible
      this.fill('form[action="/search"]', {
        q: 'casperjs'
      }, true)
    })

    casper.waitForUrl(/q=casperjs/, function() {
      (/casperjs/).should.matchTitle
    })
  })
})
