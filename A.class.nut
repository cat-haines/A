A <- {
    CallTo = function(obj, methodName) {
        foreach(original, fake in A.Fake._fakes) {
            if (fake == obj) return obj.spyOn(methodName);
        }

        throw "The first parameter of A.CallTo must be A.Fake";
    }
};

class A.Fake {

    static _fakes = {};

    _originalObject = null;
    _tracking = null;

    constructor(obj) {
        if (obj in _fakes) return _fakes[obj];

        _originalObject = obj;
        _tracking = {};

        _fakes[obj] <- this;
    }

    function spyOn(methodName) {
        // If we're already spying on the method, return the spy
        if (methodName in _tracking) return _tracking[methodName];

        // Create, store and return a new spy otherwise
        _tracking[methodName] <- A.Spy(this, methodName);

        return _tracking[methodName];
    }

    //-------------------- PRIVATE / HELPER METHODS --------------------//
    function _get(idx) {
        // If we have a spy, return it
        if (idx in _tracking) {
            local spy = _tracking[idx];
            return spy.invoke.bindenv(spy);
        }

        // Otherwise return the origin method, but bind it to the Fake parent
        if (idx in _originalObject) {
            if (typeof idx == "function") {
                return _originalObject[idx].bindenv(this);
            }

            return _originalObject[idx];
        }

        throw null;
    }

    function _typeof() {
        return typeof(_originalObject);
    }
}

class A.Spy {
    // The object + method we're spying on
    _object = null;
    _method = null;
    _methodName = null;

    // Stats
    _invocations = null;

    // Timeouts
    _timeout = null;
    _actualTimeout = null;

    // Behaviour
    _callsBaseMethod = null;
    _throws = null;
    _returns = null;
    _invokes = null;

    constructor(fakeObject, methodName) {
        // Don't let developers shoot themselves in the foot by spying on something they can't
        if (!(methodName in fakeObject)) throw format("the index '%s' does not exist", methodName);
        if (typeof fakeObject[methodName] != "function") throw format("the index '%s is not a method", methodName);

        _object = fakeObject;
        _method = _object[methodName];
        _methodName = methodName;

        // Instantate our invocations array
        _invocations = [];

        // Setup out timeout variables
        _timeout = 0;
        _actualTimeout = 0;

        // Don't call base method by default
        _callsBaseMethod = false;

        // Create our list of custom code to run on invocation
        _invokes = [];
    }

    //-------------------- MAIN INVOKE METHOD --------------------//
    // Called when the method is invoked
    function invoke(...) {
        local invocation = {
            "params": vargv,
            "throws": null,
            "returns": null
        };

        // Add the object to the array
        _invocations.push(invocation);

        // Synchronous sleep for now
        imp.sleep(_actualTimeout);

        // Invoke any behaviour added with .invokes(callback)
        foreach(callback in _invokes) {
            callback();
        }

        // If we're not calling the method:
        if(!_callsBaseMethod) {
            invocation.throws = _throws;
            invocation.returns = _returns;

            if (_throws) throw _throws;
            return _returns;
        }

        // If we are calling the method
        local obj = _object._originalObject;
        local args = [obj];
        args.extend(vargv);
        try {
            local result = _method.acall(args);
            invocation.returns = result;
            return result;
        } catch (ex) {
            invocation.throws = ex;
            throw ex;
        }
    }

    //--------------------- Behaviour modifiers --------------------//
    function invokes(callback) {
        _invokes.push(callback);

        return this;
    }

    function doesNothing() {
        return this;
    }

    function throws(err) {
        _throws = err;
        _returns = null;

        return this;
    }

    function returns(obj) {
        _returns = obj;
        _throws = null;

        return this;
    }

    function callsBaseMethod() {
        _callsBaseMethod = true;

        return this;
    }

    function after(timeout) {
        _timeout = timeout;
        _actualTimeout = timeout;

        return this;
    }

    //-------------------- ASSERTIONS --------------------//
    function shouldHaveBeenCalled(num = 1) {
        if (_invocations.len() != num) throw format("Expected %s to have been called %d times (actual %d).", _methodName, num, _invocations.len());

        return true;
    }

    function shouldHaveBeenCalledWith(...) {
        if(_invocations.len() == 0) throw format("Expected %s to have been called.", _methodName);

        foreach(invocation in _invocations) {
            if (invocation.params.len() != vargv.len()) continue;

            local match = true;
            foreach(idx, param in vargv) {
                if(invocation.params[idx] != param) {
                    match = false;
                    continue;
                }
            }
            if (match) return true;
        }


        local expectedParams = http.jsonencode(vargv);
        expectedParams = expectedParams.slice(2, expectedParams.len()-2);

        throw format("Expected %s to have been called with (%s)", _methodName, expectedParams)
    }

    function shouldNotHaveBeenCalled() {
        if(_invocations.len() != 0) throw format("Expected %s to have not been called (called %d times).", _methodName, _invocations.len());

        return true;
    }

    function shouldHaveReturned(val) {
        foreach(invocation in _invocations) {
            if (invocation.returns == val) return true;
        }

        throw format("Expected %s to return %s.", _methodName, val.tostring());
    }

    function shouldHaveThrown(err) {
        foreach(invocation in _invocations) {
            if (invocation.throws == err) return true;
        }

        throw format("Expected %s to throw %s.", _methodName, val.tostring());
    }

    //-------------------- PRIVATE / HELPER METHODS --------------------//
    function _seconds() {
        // NOOP
        return this;
    }

    function _milliseconds() {
        _actualTimeout = _timeout * 0.001;
        return this;
    }

    function _minutes() {
        _actualTimeout = _timeout * 60.0;
        return this;
    }

    function _and() {
        // NOOP
        return this;
    }

    // Overload _get so we can access 'properties' as methods (syntatic sugar)
    function _get(idx) {
        switch(idx) {
            case "and":
                return _and();
            case "seconds":
                return _seconds();
            case "milliseconds":
                return _milliseconds();
            case "minutes":
                return _minutes();
        }

        throw null;
    }

    function _typeof() {
        return typeof _object[method];
    }
}

class A.Test {
    _testName = null;
    _testCallback = null;

    _async = null;
    _skip = null;

    constructor(testName, testCallback) {
        // Set ctor params
        _testName = testName;
        _testCallback = testCallback;

        // Set defaults
        _async = false;
        _skip = false;
    }

    function async() {
        _async = true;
        return this;
    }

    function skip() {
        _skip = true;
        return this;
    }
}

class A.Suite {
    static ASYNC = true;

    // Suite Name
    _name = null;

    // Test setup / teardown
    _beforeEach = null;
    _afterEach = null;

    // The tests
    _tests = null;

    constructor(suiteName, suiteCallback) {
        _name = suiteName;
        _tests = [];

        // Create the _beforeEach object
        _beforeEach = { };
        _beforeEach.callback <- function() {};
        _beforeEach._isAsync <- false;
        _beforeEach.async <- function() {
            _isAsync = true;
        }.bindenv(_beforeEach);

        // Create the _afterEach object
        _afterEach = { };
        _afterEach.callback <- function() {};
        _afterEach._isAsync <- false;
        _afterEach.async <- function() {
            _isAsync = true;
        }.bindenv(_afterEach);

        // Run the suite Callback (setup)
        suiteCallback.bindenv(this)();

        // Process the suite
        _processSuite();
    }

    //---------- HELPER METHODS FOR SUITE CALLBACK ----------//
    function beforeEach(callback) {
        _beforeEach.callback <- callback;
        return _beforeEach;
    }

    function afterEach(callback) {
        _afterEach.callback <- callback;
        return _afterEach;
    }

    function test(testName, testCallback) {
        local newTest = A.Test(testName, testCallback);
        _tests.push(newTest);
        return newTest;
    }

    //-------------------- PRIVATE METHODS --------------------//
    function _processSuite() {
        server.log("Running Suite: " + _name);
        _runTests();
    }

    function _runTests(current = 0, passed = 0, failed = 0, skipped = 0) {
        if (current >= _tests.len()) {
            // We're done - log results
            local total = passed + failed + skipped;
            server.log("Completed Suite: " + _name);
            server.log(format("Passed: %d/%d | Failed: %d/%d | Skipped: %d/%d", passed, total, failed, total, skipped, total));

            return;
        };

        _runSetup(current, passed, failed, skipped);
    }

    function _runSetup(current, passed, failed, skipped) {
        if (!_beforeEach._isAsync) {
            _beforeEach.callback();
            _runTest(current, passed, failed, skipped);
            return;
        }

        _beforeEach.callback(function() {
            _runTest(current, passed, failed, skipped);
        }.bindenv(this));
    }

    function _runTest(current, passed, failed, skipped) {
        local thisTest = _tests[current];

        // If we're skipping the test, move on to teardown
        if (thisTest._skip) {
            skipped++;
            server.log(format("SKIPPED: %s", thisTest._testName));

            _runTeardown(current, passed, failed, skipped);
            return;
        }

        if (!thisTest._async) {
            // Run the test
            try {
                thisTest._testCallback();

                passed++;
                server.log(format("PASSED: %s", thisTest._testName));
            } catch(ex) {
                failed++;
                server.log(format("FAILED: %s (%s)", thisTest._testName, ex.tostring()));
            }
            _runTeardown(current, passed, failed, skipped);
            return;
        }

        // Run the test
        try {
            thisTest._testCallback(function() {
                passed++;
                server.log(format("PASSED: %s", thisTest._testName));

                _runTeardown(current, passed, failed, skipped);
            }.bindenv(this));
        } catch(ex) {
            failed++;
            server.log(format("FAILED: %s (%s)", thisTest._testName, ex.tostring()));
            _runTeardown(current, passed, failed, skipped);
        }
    }

    function _runTeardown(current, passed, failed, skipped) {
        if (!_afterEach._isAsync) {
            _afterEach.callback();
            _runTests(current+1, passed, failed, skipped);
            return;
        }

        _afterEach.callback(function() {
            _runTests(current+1, passed, failed, skipped);
        }.bindenv(this));
    }
}
