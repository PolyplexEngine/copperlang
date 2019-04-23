module copper.lang.vm.state;
import copper.lang.compiler.vm.chunk;
import copper.lang.compiler.vm.compiler;
import copper.lang.compiler.vm.disasm;
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
        registers.ip += Instr.sizeof;
        return instr;
    }

    bool eof() {
        return offset >= chunk.count;
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

    size_t call(size_t returnCount = 1, T...)(string name, T args) {
        stack.clear();
        jumpTo(symbolTable.get(name));
        size_t argSize;
        foreach(arg; args) {
            stack.push!(typeof(arg))(arg);
            argSize += arg.sizeof;
            writeln("Pushing ", typeid(arg), " with value ", arg, " of size ", arg.sizeof);
        }
        // Return address is "null" pointer
        stack.push!size_t(0);
        do {
            OPCode ran = VM.execute(&this);
            if (ran == opHALT) return 0;
            if (ran == opRET) {
                if ((stack.stackOffset/size_t.sizeof) <= argSize) break;
            }
            
        } while (true);
        return stack.popRaw!size_t;
    }
}