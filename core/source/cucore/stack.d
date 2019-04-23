module cucore.stack;

/// A small dynamic stack that uses an array internally.
struct DynamicStack(T) {
private:
    T[] stack;

public:

    /// Push an item to the stack
    void push(T item) {
        stack ~= item;
    }

    /// Push multiple items to the stack
    void push(T[] items) {
        stack ~= items;
    }

    /// Amount of items in the stack.
    size_t count() {
        return stack.length;
    }

    /// Peek at an element in the stack.
    T peek(size_t position = 0) {
        return stack[$-1-position];
    }

    /// Pop an item from the stack
    T pop() {
        T item = stack[$-1];
        stack.length--;
        return item;
    }
}