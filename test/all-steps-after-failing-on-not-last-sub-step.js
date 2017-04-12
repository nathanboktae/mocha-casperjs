describe('Should run all steps if the previous test failed on not last sub step', function() {
  before(function() {
    casper.start('http://localhost:10473/sample')
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
    casper
      .waitForSelector('article')
      .then(function() {
        console.log('THEN 4')
      })
      .then(function() {
        console.log('THEN 5')
      })
  })
})
