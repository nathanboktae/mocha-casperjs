describe('failing before', function() {
  before(function() {
    casper.start('http://localhost:10473/sample')
    casper.waitForSelector('.nonexistent', null, null, 500);
  })

  it('should fail the first test', function() {
    casper.then(function() {
      'hi'.should.be.ok
    })
  })

  describe('nested', function() {
    it('should fail other tests', function() {
      casper.then(function() {
        'hi'.should.be.ok
      })
    })
  })
})