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
