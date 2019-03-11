module copper.lang.vm.vm;
import copper.lang.compiler;
import copper.lang.vm.stack;
import copper.lang.types;
import copper.lang.arch;

alias vmResult = ubyte;

enum vmResultOK = 0;
enum vmResultCompileError = 1;
enum vmResultRuntimeError = 2;

/// Register data.
union GPRegData {

    /// A byte
    ubyte  byte_;

    /// A word
    ushort word;
    
    /// A double word
    uint   dword;

    /// A quad word
    ulong  qword;

    /// A ptr word
    size_t ptrword;

}

/// All the registers in the VM.
struct VMRegisters {

    /// Initialize registers.
    void initialize() {

        // Initialize general-purpose registers.
        GPRegData init_;
        init_.qword = 0;
        gp = [init_, init_, init_, init_, init_, init_, init_, init_];
    }

    /// General Purpose Registers
    GPRegData[8] gp;

    ref GPRegData opIndex(Register reg) {
        Register regws = 0b00011111 & reg;
        if (regws >= regGP0 && regws <= regGP7) return gp[regws];
        throw new Exception("Invalid general-purpose register!");
    }

    /// Floating Point Register 0
    float fp0;

    /// Floating Point Register 1
    float fp1;

    /// Floating Point Register 2
    double fp2;

    /// Floating Point Register 3
    double fp3;

    /// Stack Pointer
    size_t esp;

    /// Flag Register
    Flag flg;

    /// Instruction pointer
    ubyte* ip;

    string toString() {
        import std.format : format;

        string outString = "";
        foreach(id, value; gp) {
            outString ~= format("GP%s: %08x\n", id, value.qword);
        }
        outString ~= format("FLG: %016b\n", flg);
        
        return outString;
    }
}

struct VM {
private:
    import std.stdio : writeln;
    VMRegisters registers;

    /// The stack
    VMStack!(MaxStackSize) stack;

    /// Code chunk being run
    Chunk* chunk;
    
    /// Consumes an argument
    ValData consume(size_t sz = size_t.sizeof) {
        ValData retVal = ValData.create(registers.ip[0..sz]);
        registers.ip += sz;
        return retVal;
    }

    void consumeTo(Register r) {
        immutable(size_t) regSize = r.getDataCountForRegister();
        immutable(ValData) val = consume();
        switch(regSize) {
            case 1:
                registers[r].byte_ = val.ubyte_;
                return;

            case 2:
                registers[r].word = val.ushort_;
                return;

            case 4:
                registers[r].dword = val.uint_;
                return;

            case 8:
                registers[r].qword = val.ulong_;
                return;

            default:
                throw new Exception("Invalid size for register!");
        }
    }

public:
    /// Change the chunk being interpreted.
    vmResult interpret(Chunk* chunk) {
        this.chunk = chunk;
        registers.initialize();
        registers.ip = this.chunk.instr.ptr;
        return run();
    }

    /// Run
    vmResult run() {
        ubyte* sPtr = chunk.instr.ptr;
        version(DEBUG) {
            scope(exit) {
                import std.stdio : writeln;
                writeln("===================== REGISTERS =====================\n"~registers.toString);  
                writeln("===================== STACK =====================\n"~stack.toString);   
            }
        }
        stack.setup();
        while(true) {
            version(DEBUG) {
                import std.stdio : writeln;
                writeln(disasmInstr(chunk, cast(size_t)(registers.ip - chunk.instr.ptr)).toString);
            }
            ubyte instruction;
            switch(instruction = *(registers.ip++)) {
                case (opMOVC):
                    consumeTo(consume().register);
                    continue;

                case (opCMP):
                    Register x = consume().register;
                    Register y = consume().register;

                    immutable(size_t) valueA = registers[x].qword;
                    immutable(size_t) valueB = registers[y].qword;

                    // Clear flags.
                    registers.flg = 0;

                    if (valueA == valueB) registers.flg |= flagEqual;
                    if (valueA > valueB) registers.flg  |= flagLargerThan;
                    continue;

                case (opADD):
                    Register x = consume().register;
                    Register y = consume().register;
                    immutable(size_t) valueA = registers[x].qword;
                    immutable(size_t) valueB = registers[y].qword;
                    immutable(size_t) outcome = valueA + valueB;

                    // TODO: Make this work properly.
                    if (outcome <= valueA && outcome <= valueB) 
                        registers.flg &= flagCarry;
                    continue;

                case (opSUB):
                    Register x = consume().register;
                    Register y = consume().register;
                    size_t valueA = registers[x].qword;
                    size_t valueB = registers[y].qword;
                    size_t outcome = valueA - valueB;

                    // TODO: Make this work properly.
                    if (outcome >= valueA && outcome >= valueB) 
                        registers.flg &= flagCarry;

                    continue;

                case (opMUL):
                    Register x = consume().register;
                    Register y = consume().register;
                    registers[x].qword *= registers[y].qword;
                    continue;

                case (opDIV):
                    Register x = consume().register;
                    Register y = consume().register;
                    registers[x].qword /= registers[y].qword;
                    continue;
                
                case (opPSH):
                    Register x = consume().register;
                    stack.push(registers[x].qword);
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
        VMRegisters reg;
        reg.initialize();
        reg.ip = chunk.instr.ptr;
        VMStack!(MaxStackSize) stck;
        return VM(reg, stck, chunk);
    }
}