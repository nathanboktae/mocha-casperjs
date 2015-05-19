describe('cascading failures', function() {
  before(function() {
    casper.start('http://localhost:10473/sample')
  })
  it('should run and report 1 failure', function() {
    casper.then(function() {
      '1'.should.equal('2')
    })
    casper.then(function() {
      '1'.should.equal('3')
    })
    casper.then(function() {
      '1'.should.equal('4')
    })
  })
  it('should pass', function() {
    casper.then(function() {
      '1'.should.equal('1')
    })
  })
  it('should pass a second time', function() {
    casper.then(function() {
      '1'.should.equal('1')
    })
  })
  it('should fail a second time', function() {
    casper.then(function() {
      '1'.should.equal('5')
    })
  })
  it('should pass a third time', function() {
    casper.then(function() {
      '1'.should.equal('1')
    })
  })
})
