module copper.lang.compiler.disasm;
import copper.lang.compiler.chunk;
import copper.lang.arch;
import std.format;

struct DisAsmChunk {
    size_t offset;
    string name;
    size_t[] data;

    this(size_t offset, string name) {
        this(offset, name, []);
    }

    this(size_t offset, string name, size_t[] data) {
        this.offset = offset;
        this.name = name;
        this.data = data;
    }

    string toString() {
        string dat = "";
        foreach(i, dt; data) {
            dat ~= "%08x%s ".format(dt, i < data.length-1 ? "," : "");
        }
        return "#%08x:\t".format(offset) ~ name ~ " " ~ dat;
    }
}

DisAsmChunk[] disassemble(Chunk* chunk) {
    DisAsmChunk[] chunks;
    for (size_t offset = 0; offset < chunk.count;) {
        chunks ~= disasmInstr(chunk, offset);
    }
    return chunks;
}

/*DisAsmChunk disasmInstr(Chunk* chunk, size_t* offset) {
    import std.stdio : writeln;
    ubyte instr = chunk.instr[*(offset++)];
    ubyte opt = chunk.instr[*(offset++)];
    writeln(instr, ", ", opt);
    DisAsmChunk oChunk = DisAsmChunk(*offset, (cast(OPCode)instr).getString());
    //(*offset) += 2;
    return oChunk;
}*/

DisAsmChunk disasmInstr(Chunk* chunk, size_t offset) {
    ubyte instr = chunk.instr[offset++];
    Option opt = chunk.instr[offset++];
    void* argPtr = chunk.instr.ptr+offset; //cast(void*)(chunk.instr[offset..offset+(size_t.sizeof*instr.getArgCount)]);
    size_t[] args = (cast(size_t*)argPtr)[0..instr.getArgCount()];
    DisAsmChunk oChunk = DisAsmChunk(offset, (cast(OPCode)instr).getString(), args);
    return oChunk;
}