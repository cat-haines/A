ass Fake {
    
    static _fakes = {};
    
    _originalObject = null;
    _tracking = null;
    
    constructor(obj) {
        if (obj in _fakes) return _fakes[obj];
        
        _originalObject = obj;
        _tracking = {};
        
        _fakes[obj] <- this;
    }
    
    function CallsTo(obj, methodName) {
        foreach(original, fake in _fakes) {
            if (fake == obj) return obj.spyOn(methodName);
        }
        
        throw "The first parameter of CallsTo must be a Fake";
    }
    
    function spyOn(methodName) {
        // If we're already spying on the method, return the spy
        if (methodName in _tracking) return _tracking[methodName];
        
        // Create, store and return a new spy otherwise
        _tracking[methodName] <- Spy(this, methodName);
        return _tracking[methodName];
    }
    
    function _get(idx) {
        if (idx in _tracking) {
            local spy = _tracking[idx];
            return spy.invoke.bindenv(spy);
        } 
        
        if (idx in _originalObject) {
            return _originalObject[idx].bindenv(_originalObject);
        }
        
        throw null;
    }

    function _typeof() {
        return typeof(_originalObject);
    }
}

class Spy {
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
    _callsThrough = null;
    _throws = null;
    _returns = null;
    
    constructor(fakeObject, methodName) {
        // Store core properties
        if (!(methodName in fakeObject)) throw format("the index '%s' does not exist", methodName);
        _object = fakeObject;
        _method = _object[methodName];
        _methodName = methodName;
        
        // Instantate our invocations array
        _invocations = [];
        
        // Setup out timeout variables
        _timeout = 0;
        _actualTimeout = 0;
        
        // Don't call through by default
        _callsThrough = false;
    }
    
    //-------------------- MAIN INVOKE METHOD --------------------//
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
        
        // If we're not calling the method:
        if(!_callsThrough) {
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
    function callsThrough() {
        _callsThrough = true;
        
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
    
    // Timing functions:
    function after(timeout) {
        _timeout = timeout;
        _actualTimeout = timeout;
        
        return this;
    }
    
    //-------------------- ASSERTIONS --------------------//
    function shouldHaveBeenCalled(num = 1) {
        if (_invocations.len() != num) throw format("%s called %d times (expected %d).", _methodName, _invocations.len(), num);
        
        return true;
    }
    
    function shouldHaveBeenCalledWith(...) {
        if(_invocations.len() == 0) throw format("%s called %d times (expected 1 or more).", _methodName, _invocations.len());
        
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
        
        local expectedParams = "";
        foreach(param in vargv) expectedParams += param + ",";
        expectedParams = expectedParams.slice(0, expectedParams.len()-1);
        
        throw format("%s not called with (%s)", _methodName, expectedParams)
    }
    
    function shouldNotHaveBeenCalled() {
        if(_invocations.len() != 0) throw format("%s called %d times (expected %d).", _methodName, _invocations.len(), 0);
        
        return true;
    }
    
    function shouldHaveReturned(val) {
        foreach(invocation in _invocations) {
            if (invocation.returns == val) return true;
        }
        
        throw "Expected " + _methodName + " to return " + val + ".";
    }
    
    function shouldHaveThrown(err) {
        foreach(invocation in _invocations) {
            if (invocation.throws == err) return true;
        }
        
        throw "Expected " + _methodName + " to throw " + err + ".";
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

    // Overload _get so we can access 'properties' as methods
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


device <- Fake(device);

Fake.CallsTo(device, "send").and.callsThrough();


function test() {
    device.send("test", 123);
    Fake.CallsTo(device, "send").shouldHaveBeenCalledWith("test", 1234);
    server.log("All Tests Passed");
}

test();

