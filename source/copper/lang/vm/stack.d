module copper.lang.vm.stack;
import copper.lang.types;
import std.format;

enum MaxStackSize = 10_000;

struct VMStack(size_t stackSize = MaxStackSize) {
private:
    // The actual stack, aligned with pointer length * stacksize bytes
    ubyte[MaxStackSize*size_t.sizeof] stack;

    // the stack pointer
    ubyte* stackptr;

public:
    void setup() {
        stackptr = stack.ptr;
    }

    void push(T)(T value) {
        push(ValData.create!T(value));
    }

    void push(ValData val) {
        stackptr[0..size_t.sizeof] = val.ubyteArr;
        stackptr += ValData.sizeof;
    }

    size_t popRaw() {
        // point at next element
        stackptr -= size_t.sizeof;
        return cast(size_t)*stackptr;
    }

    size_t stackOffset() {
        return cast(size_t)stackptr-cast(size_t)stack.ptr;
    }

    string toString() {
        string oStr;
        foreach(i; 0..(stackOffset()/size_t.sizeof)) {
            size_t offs = i*size_t.sizeof;
            size_t offsLen = offs+size_t.sizeof;

            size_t val = (ValData.create(stack[offs..offsLen])).ptr_;

            oStr ~= "%04x: %08x".format(offs, val) ~ "\n";
        }
        return oStr;
    }
    
}