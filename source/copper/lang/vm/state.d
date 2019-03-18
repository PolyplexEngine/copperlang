module copper.lang.vm.state;
import copper.lang.compiler;
import copper.lang.vm;

struct State {
package:

    /// Jump the Instruction Pointer to an address
    void jumpTo(size_t address) {
        registers.ip = chunk.instr.ptr+address;
    }

    /// Returns true if any of the flags are present.
    bool hasFlags(Flag flags) {
        return (registers.flg & flags) > 0;
    }

    /// Fetches the next instruction.
    Instr next() {
        Instr instr = *cast(Instr*)(registers.ip);
        registers.ip += 2;
        return instr;
    }

public:
    /// The registers associated with the state.
    Registers registers;

    /// The stack
    VMStack!(MaxStackSize) stack;

    /// Code chunk being run
    Chunk* chunk;

    SymbolTable symbolTable;

    this(ChunkBuilder chunkBuilder) {
        this(chunkBuilder.build());
    }

    this(CObject* object) {
        this.chunk = object.chunk;
        this.symbolTable = object.symbols;
    }

    void init() {
        registers.initialize();
        registers.ip = this.chunk.instr.ptr;
        stack.clear();
    }

    size_t offset() {
        return cast(size_t)(registers.ip-chunk.instr.ptr);
    }

    /// Prints stackframe and register debug info via writeln.
    void printDebugFrame() {
        import std.stdio : writeln;
        writeln("===================== REGISTERS =====================\n"~registers.toString);  
        writeln("===================== STACK =====================\n"~stack.toString);   
    }

    size_t call(string name, size_t[] parameters = [], size_t returnCount = 1) {
        stack.clear();
        jumpTo(symbolTable.get(name));
        foreach(param; parameters) stack.push(param);
        
        // Return address is "null" pointer
        stack.push(0);
        do {
            if (VM.execute(&this) == opRET) {
                if ((stack.stackOffset/size_t.sizeof) <= parameters.length+returnCount) break;
            }
        } while (true);
        return stack.popRaw();
    }
}