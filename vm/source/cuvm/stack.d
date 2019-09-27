module cuvm.stack;

/**
    A stack of items
*/
struct Stack(T, int size = ushort.max) {
private:
    T[size] stack;
    T* stackPtr;
    size_t count = 0;

public:
    void reset() {
        stackPtr = stack.ptr;
    }

    /**
        push item to stack
    */
    void push(T item) {
        *stackPtr++ = item;
        count++;
    }

    /**
        pop item from stack
    */
    T pop() {
        count--;
        return *--stackPtr;
    }

    string toString() {
        import std.conv : text;
        return stack[0..count].text;
    }
}