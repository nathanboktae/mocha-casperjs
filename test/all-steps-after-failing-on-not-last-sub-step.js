describe('Should run all steps if the previous test failed on not last sub step', function() {
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
  })

  it('Second test', function() {
    casper.then(function() {
      console.log('THEN 3')
    })
    casper.then(function() {
      console.log('THEN 4')
    })
  })
})
