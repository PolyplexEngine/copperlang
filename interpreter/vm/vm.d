module copper.lang.vm.vm;
import copper.lang.compiler;
import copper.lang.compiler.vm.disasm;
import copper.lang.vm.stack;
import copper.lang.types;
import copper.lang.arch;
import copper.lang.vm.state;
import std.conv;

alias vmResult = ubyte;

enum vmResultOK = 0;
enum vmResultHalt = 1;
enum vmResultCompileError = 128;
enum vmResultRuntimeError = 129;

private {

    bool hasOption(Option option, Option has) {
        import std.format : format;
        //writeln("%08b\n%08b = \n%08b".format(option, has, (option & has)));
        return (option & has) == has;
    }

    /// Consumes an argument
    ValData consume(State* state, size_t sz = 8) {
        ValData retVal = ValData.create(state.registers.ip[0..sz]);
        state.registers.ip += sz;
        return retVal;
    }

    T consume(T)(State* state) {
        T retval = *cast(T*)(cast(void*)state.registers.ip)[0..T.sizeof];
        state.registers.ip += T.sizeof;
        return retval;
    }

    void pushTo(State* state, size_t size, void* data) {
        state.stack.push(size, data);
    }

    void consumeTo(State* state, Register r) {
        immutable(size_t) regSize = r.getDataCountForRegister();
        static if (COMPRESS_CODE) {
            immutable(ValData) val = consume(state, regSize);
        } else {
            immutable(ValData) val = consume(state, );
        }
        switch(regSize) {
            case 1:
                state.registers[r].byte_ = val.ubyte_;
                return;

            case 2:
                state.registers[r].word = val.ushort_;
                return;

            case 4:
                state.registers[r].dword = val.uint_;
                return;

            case 8:
                state.registers[r].qword = val.ulong_;
                return;

            default:
                throw new Exception("Invalid size for register!");
        }
    }

    bool hasEitherState(State* state, Flag expected, bool flipLogic) {
        return (
            (!flipLogic && state.hasFlags(expected)) || 
            (flipLogic && !state.hasFlags(expected)));
    }

    bool hasStateOff(State* state, Flag expected) {
        return !state.hasFlags(expected);
    }

    void doJump(State* state, Flag expectedFlags, bool flipLogic, Flag expectedFlagsOff = 0) {
        size_t to = consume(state).ptr_;//registers.gp[.register].ptrword;
        if (expectedFlags == 0) state.jumpTo(to);

        if (hasEitherState(state, expectedFlags, flipLogic)) state.jumpTo(to);
    }
}

struct VM {
public:

    /// Executes a single instruction in the specified state.
    static OPCode execute(State* state) {
        // Fetch and execute next instruction.
        Instr instruction;
        switch((instruction = state.next()).opcode) {
            case (opCALL):
                // Add 8 since CALL instruction params are 8 bytes wide.
                size_t returnPoint = state.offset+8;
                state.stack.push(returnPoint);
                state.doJump(0, false);
                break;

            case (opRET):
                // Fetch return values
                size_t bytesToPreserve = state.consume().ptr_;

                // Get return point pointer.
                size_t retPoint = state.stack.peek!size_t(-(bytesToPreserve+size_t.sizeof));
                state.jumpTo(retPoint);
                state.stack.shift(bytesToPreserve, size_t.sizeof);
                break;

            case (opJMP):
                state.doJump(0, false);
                break;

            case (opJZ):
                state.doJump(flagZero, false);
                break;

            case (opJNZ):
                state.doJump(flagZero, true);
                break;

            case (opJS):
                state.doJump(flagSign, false);
                break;

            case (opJNS):
                state.doJump(flagSign, true);
                break;

            case (opJE):
                state.doJump(flagEqual, false);
                break;

            case (opJNE):
                state.doJump(flagEqual, true);
                break;

            case (opJA):
                state.doJump(flagLargerThan, false);
                break;

            case (opJAE):
                state.doJump(flagLargerThan | flagEqual, false);
                break;

            case (opJB):
                state.doJump(flagLargerThan, true);
                break;

            case (opJBE):
                state.doJump(flagEqual, true, flagLargerThan);
                break;

            case (opMOVC):
                state.consumeTo(state.consume().register);
                break;

            case (opCMP):
                size_t valueA;
                size_t valueB;
            
                if (instruction.options.hasOption(optRegister1)) {
                    valueA = state.registers[state.consume().register].ptrword;
                } else {
                    valueA = state.consume().ptr_;
                }

                if (instruction.options.hasOption(optRegister2)) {
                    valueB = state.registers[state.consume().register].ptrword;
                } else {
                    valueB = state.consume().ptr_;
                }


                // Clear flags.
                state.registers.flg = 0;

                if (valueA == valueB) state.registers.flg |= flagEqual;
                if (valueA > valueB) state.registers.flg  |= flagLargerThan;
                break;

            case (opALLOC):
                import core.memory : GC;
                Register store = state.consume().register;
                size_t length;

                if (instruction.options.hasOption(optRegister2)) {
                    length = state.registers[state.consume().register].ptrword;
                } else {
                    length = state.consume().ptr_;
                }

                void* allocMem = GC.malloc(length);

                // TODO: put allocated memory on to an allocation list of some sort.

                state.registers[store].ptrword = cast(size_t)allocMem;
                break;


            case (opADD):
                Register x = state.consume().register;
                Register y = state.consume().register;
                immutable(size_t) valueA = state.registers[x].qword;
                immutable(size_t) valueB = state.registers[y].qword;
                immutable(size_t) outcome = valueA + valueB;

                state.registers[x].qword = outcome;

                // TODO: Make this work properly.
                if (outcome <= valueA && outcome <= valueB) 
                    state.registers.flg &= flagCarry;
                break;

            case (opSUB):
                Register x = state.consume().register;
                Register y = state.consume().register;
                size_t valueA = state.registers[x].qword;
                size_t valueB = state.registers[y].qword;
                size_t outcome = valueA - valueB;

                state.registers[x].qword = outcome;

                // TODO: Make this work properly.
                if (outcome >= valueA && outcome >= valueB) 
                    state.registers.flg &= flagCarry;

                break;

            case (opMUL):
                Register x = state.consume().register;
                Register y = state.consume().register;
                state.registers[x].qword *= state.registers[y].qword;
                break;

            case (opDIV):
                Register x = state.consume().register;
                Register y = state.consume().register;
                state.registers[x].qword /= state.registers[y].qword;
                break;
            
            case (opPSH):
                if (instruction.options.hasOption(optRegister)) {
                    Register x = state.consume().register;
                    size_t dataSize = x.getDataCountForRegister();
                    state.pushTo(dataSize, &(state.registers[x].qword));
                    break;
                }
                if (instruction.options.hasOption(optValue)) {
                    size_t x = state.consume().ptr_;
                    size_t dataSize = getDataSizeForOption(instruction.options);
                    state.pushTo(dataSize, &x);
                    break;
                }
                throw new Exception("Invalid push parameters!");

            case (opPOP):
                size_t amount = state.consume().ptr_;
                state.stack.pop(amount);
                break;

            case (opPEEK):
                Register x = state.consume().register;
                ptrdiff_t offset = state.consume!ptrdiff_t;
                size_t val = state.stack.peek!size_t(-offset);
                state.registers[x].ptrword = val;
                break;

            case (opFRME):
                state.printDebugFrame();
                break;

            case (opHALT):
                break;

            default:
                throw new Exception("Invalid instruction! "~instruction.opcode.text ~ " @ " ~ state.offset.text);
                
                // writeln("FAIL ", cast(size_t)(state.registers.ip-chunk.instr.ptr), ": ", instruction.opcode);
                // break;
        }
        return instruction.opcode;
    }

    /// Run
    static vmResult run(State* state) {
        try {
            while(true) {

                // Show dissassembly in DEBUG mode.
                version(DEBUG) {
                    import std.stdio : writeln;
                    writeln(disasmInstr(state.chunk, cast(size_t)(state.registers.ip - state.chunk.instr.ptr)).toString);
                }

                if (cast(size_t)(state.registers.ip - state.chunk.instr.ptr) > state.chunk.labelOffset) {
                    // The VM is done.
                    return vmResultOK;
                }

                if (execute(state) == opHALT) return vmResultHalt;
                
            }
        } catch(Exception ex) {
            return vmResultRuntimeError;
        }
    }
}