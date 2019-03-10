module copper.lang.compiler.chunk;
import copper.lang.arch;
import copper.lang.types;

public struct Chunk
{
private:

    void grow(size_t amount = 1)
    {
        if (capacity < count + amount)
        {
            // grow the array by a factor of 2.
            instr.length = capacity < 8 ? 8 : (capacity) * 2;
        }
    }

public:
    /// count of chunks
    size_t count;

    /// Instructions
    ubyte[] instr;

    ~this()
    {
        destroy(instr);
    }

    /// capacity
    size_t capacity()
    {
        return instr.length;
    }

    void write(ubyte byt)
    {
        grow();
        instr[count] = byt;
        count++;
    }

    void writeData(T)(T data)
    {
        grow(size_t.sizeof);

        ChunkVal val = ChunkVal.constr(data);

        // Apply the value.
        instr[count .. count + val.as.ubyteArr.length] = val.as.ubyteArr;
        count += 8;
    }

    void writePushConst(T)(T cnst)
    {
        // Push constant
        write(opPSHC);
        writeData(cnst);
    }

    void free()
    {
        destroy(instr);
    }
}
