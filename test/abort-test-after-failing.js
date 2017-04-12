describe('Should abort the test if it fails on the step in the first level', function() {
  before(function() {
    casper.start('http://www.google.com/')
  })

  it('First test', function() {
    casper.then(function() {
      console.log('THEN 1')
      casper.waitForSelector('#qwerty')
    })
    casper.then(function() {
      console.log('THEN 2')
    })
  })

  it('Second test', function() {
    casper.then(function() {
      console.log('THEN 3')
    })
  })
})
