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
