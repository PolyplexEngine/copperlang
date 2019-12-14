module cujit;
import dllvm;
public import cujit.engine;
public import cujit.jithelpers;
import std.traits;

private:
    void*[] forceIncludes;

public:
    /**
        Initialize the JIT framework
    */
    void initJIT() {
        loadLLVM();
        initExecutionEngine();

        // Force all functions to be loaded so that the copper JIT can find them
        static foreach(member; __traits(allMembers, cujit.jithelpers)) {
            static if (__traits(isStaticFunction, __traits(getMember, cujit.jithelpers, member))) {
                forceIncludes ~= &__traits(getMember, cujit.jithelpers, member);
            }
        }
    }
