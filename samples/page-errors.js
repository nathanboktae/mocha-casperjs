casper.on('page.error', function(err, trace) {
  mocha.failCurrentTest(new Error('Error from page: ' + err + '\nStack trace: ' + JSON.stringify(trace)))
})

describe('catching javascript errors in the page', function() {
  it('should fail when errors happen', function() {
    casper
      .start('http://bing.com')
      .then(function() {
        this.evaluate(function() {
          return window.foobar.somethingelse.kaboom
        })
      }).then(function() {
        throw new Error('you will not get to here')
      })
  })
})