module cuvm.pool;
public import cuvm.value;

/**
    A pool of values
*/
struct CuValuePool {
    /// The list of values
    CuValue[] values;

    /// allows indexing values
    ref CuValue opIndex(size_t i) {
        return values[i];
    }

    /**
        Adds a new value to the pool
    */
    size_t add(CuValue value) {
        values ~= value;
        return values.length-1;
    }
}
