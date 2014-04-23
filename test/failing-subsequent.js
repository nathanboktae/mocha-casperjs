describe('subsequent failures', function() {
  before(function() {
    casper.start('http://localhost:10473/sample')
  })

  describe('failing block', function() {
    it('should fail', function() {
      casper.then(function() {
        casper.waitForSelector('.nonexistent', null, null, 500);
      })
    })
  })

  describe('adjacent block', function() {
    it('should run and pass', function() {
      casper.then(function() {
        'h1'.should.contain.text('Hello')
      })
    })

    it('should run and fail', function() {
      casper.then(function() {
        casper.waitForSelector('.subsequent-failure', null, null, 500);
      })
    })
  })
})