module copper.lang.vm.vm;
import copper.lang.compiler;
import copper.lang.vm.stack;
import copper.lang.types;
import copper.lang.arch;

alias vmResult = ubyte;

enum vmResultOK = 0;
enum vmResultCompileError = 1;
enum vmResultRuntimeError = 2;

struct VM {
private:
    /// Instruction pointer
    ubyte* instrPtr;

    /// The stack
    VMStack!(MaxStackSize) stack;

    /// Code chunk being run
    Chunk* chunk;
    
    /// Consumes an argument
    ValData consume() {
        ValData retVal = ValData.create(instrPtr[0..size_t.sizeof]);
        instrPtr += size_t.sizeof;
        return retVal;
    }

public:
    /// Change the chunk being interpreted.
    vmResult interpret(Chunk* chunk) {
        this.chunk = chunk;
        instrPtr = this.chunk.instr.ptr;
        return run();
    }

    /// Run
    vmResult run() {
        ubyte* sPtr = chunk.instr.ptr;
        version(DEBUG) {
            scope(exit) {
                import std.stdio : writeln;
                writeln("===================== STACK =====================\n"~stack.toString);    
            }
        }
        stack.setup();
        while(true) {
            version(DEBUG) {
                import std.stdio : writeln;
                writeln(disasmInstr(chunk, cast(size_t)(instrPtr - chunk.instr.ptr)).toString);
            }
            ubyte instruction;
            switch(instruction = *(instrPtr++)) {
                case (opPSHC):
                    stack.push(consume());
                    continue;
                case (opRET):
                    return vmResultOK;
                default:
                    writeln("FAIL");
                    return vmResultRuntimeError;
            }
        }
    }

    /// Returns a new VM with a seperate instruction pointer.
    VM newThread() {
        VMStack!(MaxStackSize) stck;
        return VM(chunk.instr.ptr, stck, chunk);
    }
}