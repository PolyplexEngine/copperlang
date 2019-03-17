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
    ValData consume(size_t sz = 8) {
        ValData retVal = ValData.create(registers.ip[0..sz]);
        registers.ip += sz;
        return retVal;
    }

    void consumeTo(Register r) {
        immutable(size_t) regSize = r.getDataCountForRegister();
        static if (COMPRESS_CODE) {
            immutable(ValData) val = consume(regSize);
        } else {
            immutable(ValData) val = consume();
        }
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

    bool flagHasFlags(Flag flags) {
        return (registers.flg & flags) > 0;
    }

    bool hasEitherState(Flag expected, bool flipLogic) {
        return (
            (!flipLogic && flagHasFlags(expected)) || 
            (flipLogic && !flagHasFlags(expected)));
    }

    bool hasStateOff(Flag expected) {
        return !flagHasFlags(expected);
    }

    void doJump(Flag expectedFlags, bool flipLogic, Flag expectedFlagsOff = 0) {
        size_t to = consume().ptr_;//registers.gp[.register].ptrword;
        if (expectedFlags == 0) jumpInstrPointer(to);

        if (hasEitherState(expectedFlags, flipLogic))
            jumpInstrPointer(to);
    }

public:
    /// Change the chunk being interpreted.
    vmResult interpret(Chunk* chunk) {
        this.chunk = chunk;
        registers.initialize();
        registers.ip = this.chunk.instr.ptr;
        return run();
    }

    Instr nextInstruction() {
        Instr instr = *cast(Instr*)(registers.ip);
        registers.ip += 2;
        return instr;
    }
    
    void jumpInstrPointer(size_t offset) {
        registers.ip = chunk.instr.ptr+offset;
    }
    
    size_t currentInstructionOffset() {
        return cast(size_t)(registers.ip-chunk.instr.ptr);
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

            // Show dissassembly in DEBUG mode.
            version(DEBUG) {
                import std.stdio : writeln;
                writeln(disasmInstr(chunk, cast(size_t)(registers.ip - chunk.instr.ptr)).toString);
            }

            if (cast(size_t)(registers.ip - chunk.instr.ptr) > chunk.labelOffset) {
                // The VM is done.
                return vmResultOK;
            }

            // Fetch and execute next instruction.
            Instr instruction;
            switch((instruction = nextInstruction()).opcode) {

                case (opCALL):
                    // Add 8 since CALL instruction params are 8 bytes wide.
                    size_t returnPoint = currentInstructionOffset+8;
                    stack.push(returnPoint);
                    doJump(0, false);
                    continue;

                case (opRET):

                    // Fetch return values
                    size_t retValCount = consume().ptr_;
                    size_t[] returnValues;
                    foreach(i; 0..retValCount)
                        returnValues ~= stack.popRaw();

                    // Get return point pointer.
                    size_t retPoint = stack.popRaw();
                    jumpInstrPointer(retPoint);

                    // Push return values back to stack.
                    foreach(retVal; returnValues) 
                        stack.push(retVal);

                    continue;

                case (opJMP):
                    doJump(0, false);
                    continue;

                case (opJZ):
                    doJump(flagZero, false);
                    continue;

                case (opJNZ):
                    doJump(flagZero, true);
                    continue;

                case (opJS):
                    doJump(flagSign, false);
                    continue;

                case (opJNS):
                    doJump(flagSign, true);
                    continue;

                case (opJE):
                    doJump(flagEqual, false);
                    continue;

                case (opJNE):
                    doJump(flagEqual, true);
                    continue;

                case (opJA):
                    doJump(flagLargerThan, false);
                    continue;

                case (opJAE):
                    doJump(flagLargerThan | flagEqual, false);
                    continue;

                case (opJB):
                    doJump(flagLargerThan, true);
                    continue;

                case (opJBE):
                    doJump(flagEqual, true, flagLargerThan);
                    continue;

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

                    registers[x].qword = outcome;

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

                    registers[x].qword = outcome;

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

                case (opPOP):
                    size_t amount = consume().ptr_;
                    stack.pop(amount);
                    continue;

                case (opPEEK):
                    Register x = consume().register;
                    size_t offset = consume().ptr_;
                    registers[x].ptrword = stack.peek(offset);
                    continue;

                case (opFRME):
                    import std.stdio : writeln;
                    writeln("===================== REGISTERS =====================\n"~registers.toString);  
                    writeln("===================== STACK =====================\n"~stack.toString);   
                    continue;

                case (opHALT):
                    writeln("HALTED.");
                    return vmResultOK;


                default:
                    writeln("FAIL ", cast(size_t)(registers.ip-chunk.instr.ptr), ": ", instruction.opcode);
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