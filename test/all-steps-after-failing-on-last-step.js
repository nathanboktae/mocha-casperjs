describe('Should run all steps if the previous test failed on the last step', function() {
  before(function() {
    casper.start('http://www.google.com/')
  })

  it('First test', function() {
    casper.then(function() {
      console.log('THEN 1')
      casper.waitForSelector('#qwerty')
    })
  })

  it('Second test', function() {
    casper.then(function() {
      console.log('THEN 2')
    })
    casper.then(function() {
      console.log('THEN 3')
    })
  })
})
