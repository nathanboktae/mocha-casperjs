describe('Should abort the test if it fails on substep', function() {
  before(function() {
    casper.start('http://www.google.com/')
  })

  it('First test', function() {
    casper.then(function() {
      casper.then(function() {
        console.log('THEN 1')
        casper.waitForSelector('#qwerty')
      })
      casper.then(function() {
        console.log('THEN 2')
      })
    })
    casper.then(function() {
      console.log('THEN 3')
    })
  })

  it('Second test', function() {
    casper.then(function() {
      console.log('THEN 4')
    })
  })
})
