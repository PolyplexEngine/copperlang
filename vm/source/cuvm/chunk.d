module cuvm.chunk;
import cuvm.opcodes;
import cuvm.pool;
import std.traits;

/**
    A chunk of code
*/
struct Chunk {
public:
    /**
        Pool of constant values
    */
    CuValuePool pool;

    /**
        The name of the chunk
    */
    string name = "unnamed_chunk";

    /// The count of actual data in the bytecode
    size_t count;

    /// The bytecode
    ubyte[] code;

    /**
        Write a byte to the bytecode chunk
    */
    void write(ubyte bc) {
        if (code.length < count+1) {
            if (code.length == 0) code.length = 8;
            else code.length *= 2;
        }

        code[count++] = bc;
    }

    /**
        Write an intergral type to the bytecode chunk
    */
    void write(T)(T bc) if (isNumeric!T && !is(T : ubyte)) {
        import std.bitmanip : nativeToBigEndian;
        foreach(b; nativeToBigEndian!T(bc)) {
            write(b);
        }
    }

    /**
        Dissasemble instructions
    */
    void dissasemble() {
        import std.stdio : writefln;
        import std.format : format;
        import std.conv : text;
        writefln("==== %s ====", name);

        // Dirty inline function to format a byte array of data in to a more debugger friendly format
        string fmtByteArr(ubyte[] data) {
            string output = "";
            foreach(b; data) {
                output ~= "%02x ".format(b);
            }
            return output;
        }

        size_t i = 0;
        while(i < count) {

            OpCodeInfo opCode = code[i] !in OpCodeMap ? OpCodeInfo("UNKNOWN", 1) : OpCodeMap[code[i]];

            string data = 
                opCode.dataSize > 1 ?

                // Fetch the params 1 byte away from the OPCode and the succeeding bytes based on the data size.
                fmtByteArr(code[i+1..(i+1)+(opCode.dataSize-1)]) : 

                // If there's no data just set the data empty.
                "";
            writefln("%04x: %s %s", i, opCode.name, data);

            i += opCode.dataSize;
        }
    }
}