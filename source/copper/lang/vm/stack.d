module copper.lang.vm.stack;
import copper.lang.types;
import std.format;

enum MaxStackSize = 1_000_000;

struct VMStack(size_t stackSize = MaxStackSize) {
private:
    // The actual stack, aligned with pointer length * stacksize bytes
    ubyte[MaxStackSize] stack;

    // the stack pointer
    ubyte* stackptr;

public:
    void clear() {
        stackptr = stack.ptr;
    }

    void push(size_t size, void* value) {
        stackptr[0..size] = (cast(ubyte*)value)[0..size];
        stackptr += size;
    }

    void push(T)(T* value) {
        stackptr[0..T.sizeof] = (cast(ubyte*)(cast(void*)value))[0..T.sizeof];
        stackptr += T.sizeof;
    }

    void push(T)(T value) {
        push!T(&value);
    }

    void push(T)(T[] value) {
        push!T(value.ptr);
    }

    T peek(T)(ptrdiff_t offset) {
        void* offs = cast(void*)(stackptr+offset);
        return *(cast(T*)offs);
    }

    T popRaw(T)() {
        // point at next element
        stackptr -= T.sizeof;
        return cast(T)*stackptr;
    }

    void shift(size_t bytes, size_t over) {
        size_t sOffset = stackOffset;
        stack[sOffset-bytes-over..sOffset-over] = stack[sOffset-bytes..sOffset];
    }

    void pop(size_t count) {
        stackptr -= count;
    }

    size_t stackOffset() {
        return cast(size_t)stackptr-cast(size_t)stack.ptr;
    }

    string toString() {
        string oStr;
        foreach(i; 0..stackOffset()) {
            oStr ~= "%02x ".format(stack[i]);
        }
        return oStr;
    }
    
}