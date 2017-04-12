module.exports = function (Mocha, casper, utils) {
  var currentDone,
      currentTest,
      f = utils.format,

  reportError = function() {
    casper.checker = null
    if (currentDone && (!currentTest || !currentTest.state)) {
      // the first error takes priority
      currentDone(currentTest.errors && currentTest.errors[0])
    }
  },

  failTest = function(error) {
    casper.unwait()
    clearInterval(casper.checker)

    if (currentTest.errors) {
      currentTest.errors.push(error)
    } else {
      currentTest.errors = [error]
    }

    if ( casper.step < casper.steps.length ) {
      casper.run(function() {
        reportError();
      });
    } else {
      reportError();
    }
  },

  resetSteps = function() {
    casper.bypass(casper.steps.length)
  }

  Mocha.prototype.failCurrentTest = failTest;

  // hookup to all the various casper error events and save that error to report to mocha later
  [
    'error',
    'wait.error',
    'waitFor.timeout.error',
    'event.error',
    'complete.error',
    'step.error'
  ].forEach(function(event) {
    casper.on(event, function(error) {
      failTest(error)
    })
  })

  casper.on('waitFor.timeout', function(timeout, details) {
    resetSteps()
    var message = f('waitFor timeout of %dms occured', timeout)
    details = details || {}

    if (details.selector) {
      message = f(details.waitWhile ? '"%s" never went away in %dms' : '"%s" still did not exist %dms', details.selector, timeout)
    }
    else if (details.visible) {
      message = f(details.waitWhile ? '"%s" never disappeared in %dms' : '"%s" never appeared in %dms', details.visible, timeout)
    }
    else if (details.url) {
      message = f('%s did not load in %dms', details.url, timeout)
    }
    else if (details.popup) {
      message = f('%s did not pop up in %dms', details.popup, timeout)
    }
    else if (details.text) {
      message = f('"%s" did not appear in the page in %dms', details.text, timeout)
    }
    else if (details.selectorTextChange) {
      message = f('"%s" did not have a text change in %dms', details.selectorTextChange, timeout)
    }
    else if (typeof details.testFx === 'Function') {
      message = f('"%s" did not appear in the page in %dms', details.testFx.toString(), timeout)
    }

    failTest(new Error(message))
  })

  casper.on('step.timeout', function(step) {
    resetSteps()
    failTest(new Error(f('step %d timed out (%dms)', step, casper.options.stepTimeout)))
  })
  casper.on('timeout', function() {
    resetSteps()
    failTest(new Error(f('Load timeout of (%dms)', casper.options.timeout)))
  })

  // clear Casper's default handlers for these as we handle everything through events
  casper.options.onTimeout = casper.options.onWaitTimeout = casper.options.onStepTimeout = function() {}

  // casper will exit on step failure by default
  casper.options.silentErrors = true

  // Method for patching mocha to run casper steps is inspired by https://github.com/domenic/mocha-as-promised
  //
  Object.defineProperties(Mocha.Runnable.prototype, {
    fn: {
      configurable: true,
      enumerable: true,
      get: function () {
        return this.casperWraperFn;
      },
      set: function (fn) {
        Object.defineProperty(this, 'casperWraperFn', {
          value: function (done) {
            currentTest = this.test
            currentDone = done

            // Run the original `fn`, passing along `done` for the case in which it's callback-asynchronous.
            // Make sure to forward the `this` context, since you can set variables and stuff on it to share
            // within a suite.
            fn.call(this, done)

            // only flush the casper steps on test Runnables,
            // and if there are steps not ran,
            // and no set of steps are running (casper.checker is the setInterval for the checkSteps call)

            if (currentTest && casper.steps && casper.steps.length &&
                casper.step < casper.steps.length && !casper.checker) {
              casper.run(function () {
                casper.checker = null
                if (!currentTest || !currentTest.state) {
                  done()
                }
              })
            } else if (fn.length === 0 && currentTest && !currentTest.state) {
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

  // Mocha needs the formating feature of console.log so copy node's format function and
  // monkey-patch it into place. This code is copied from node's, links copyright applies.
  // https://github.com/joyent/node/blob/master/lib/util.js
  console.format = function (f) {
    var i;
    if (typeof f !== 'string') {
      var objects = [];
      for (i = 0; i < arguments.length; i++) {
        objects.push(JSON.stringify(arguments[i]));
      }
      return objects.join(' ');
    }
    i = 1;
    var args = arguments;
    var len = args.length;
    var str = String(f).replace(/%[sdj%]/g, function(x) {
      if (x === '%%') return '%';
      if (i >= len) return x;
      switch (x) {
        case '%s': return String(args[i++]);
        case '%d': return Number(args[i++]);
        case '%j': return JSON.stringify(args[i++]);
        default:
          return x;
      }
    });
    for (var x = args[i]; i < len; x = args[++i]) {
      if (x === null || typeof x !== 'object') {
        str += ' ' + x;
      } else {
        str += ' ' + JSON.stringify(x);
      }
    }
    return str;
  };

  var origError = console.error,
      origLog = console.log
  console.error = function() { origError.call(console, console.format.apply(console, arguments)) }
  console.log = function() { origLog.call(console, console.format.apply(console, arguments)) }

  // Since we're using the precompiled version of mocha usually meant for the browser, 
  // patch the expossed process object (thanks mocha-phantomjs users for ensuring it's exposed)
  // https://github.com/visionmedia/mocha/issues/770
  Mocha.process = Mocha.process || {}
  Mocha.process.stdout = require('system').stdout
}
