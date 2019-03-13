module copper.lang.vm.stack;
import copper.lang.types;
import std.format;

enum MaxStackSize = 10_000;

struct VMStack(size_t stackSize = MaxStackSize) {
private:
    // The actual stack, aligned with pointer length * stacksize bytes
    ubyte[MaxStackSize*8] stack;

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
        stackptr[0..8] = val.ubyteArr;
        stackptr += ValData.sizeof;
    }

    size_t peek(size_t offset) {
        return cast(size_t)*(stackptr-(offset*8));
    }

    size_t popRaw() {
        // point at next element
        stackptr -= 8;
        return cast(size_t)*stackptr;
    }

    void pop(size_t count) {
        stackptr -= count*8;
    }

    size_t stackOffset() {
        return cast(size_t)stackptr-cast(size_t)stack.ptr;
    }

    string toString() {
        string oStr;
        foreach(i; 0..(stackOffset()/8)) {
            size_t offs = i*8;
            size_t offsLen = offs+8;

            size_t val = (ValData.create(stack[offs..offsLen])).ptr_;

            oStr ~= "%04x: %08x".format(offs, val) ~ "\n";
        }
        return oStr;
    }
    
}