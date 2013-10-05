var duckPunchedAlready = false

module.exports = function (mocha, casper) {
  if (duckPunchedAlready) {
    return;
  }
  duckPunchedAlready = true

  // Method for patching mocha to run casper steps is inspired by https://github.com/domenic/mocha-as-promised
  //
  Object.defineProperties(mocha.Runnable.prototype, {
    fn: {
      configurable: true,
      enumerable: true,
      get: function () {
        return this.casperWraperFn;
      },
      set: function (fn) {
        Object.defineProperty(this, 'casperWraperFn', {
          value: function (done) {
            // Run the original `fn`, passing along `done` for the case in which it's callback-asynchronous.
            // Make sure to forward the `this` context, since you can set variables and stuff on it to share
            // within a suite.
            fn.call(this, done);

            if (casper.steps.length) {
              // There are casper steps queued up for this test. Run them now.
              casper.run(function () {
                // we're wrapping done here with a function as we do not want arguments passed to it.
                done()
              })
            } else if (fn.length === 0) {
              // If `fn` is synchronous (i.e. didn't have a `done` parameter and didn't return a promise),
              // call `done` now. (If it's callback-asynchronous, `fn` will call `done` eventually since
              // we passed it in above.)
              done()
            }
          },
          writable: true,
          configurable: true
        })

        this.casperWraperFn.toString = function () {
          return fn.toString();
        }
      }
    },
    async: {
      configurable: true,
      enumerable: true,
      get: function () {
        return typeof this.casperWraperFn === 'function'
      },
      set: function () {
        // Ignore Mocha trying to set this - tests are always asyncronous with our wrapper
      }
    }
  })
}