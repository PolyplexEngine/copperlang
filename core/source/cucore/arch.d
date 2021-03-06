module cucore.arch;
public:

enum COMPRESS_CODE = false;

/// A single instruction
struct Instr {
    /// The OP Code
    OPCode opcode;

    /// Options about what kinds of arguments are passed.
    Option options;
}

alias Option = ushort;
    /// Contains a single value
    enum Option optValue                    = 0b00000000_00011000;
    
    /// First parameter is a value
    enum Option optValue1                   = 0b00000000_00010000;
    
    /// Second parameter is a value
    enum Option optValue2                   = 0b00000000_10001000;


    /// Contains a single register
    enum Option optRegister                 = 0b00000000_00100100;
    
    /// First parameter is a register
    enum Option optRegister1                = 0b00000000_00100000;
    
    /// Second parameter is a register
    enum Option optRegister2                = 0b00000000_00000100;


    /// Contains a single address
    enum Option optAddress                  = 0b00000000_01000010;
    
    /// First parameter is a address
    enum Option optAddress1                 = 0b00000000_01000000;
    
    /// Second parameter is a address
    enum Option optAddress2                 = 0b00000000_00000010;

    
    /// First parameter has an offset
    enum Option optOffset1                  = 0b00000000_10000000;
    
    /// Second parameter has an offset
    enum Option optOffset2                  = 0b00000000_00000001;
    

    /// First parameter has an negative offset
    enum Option optOffset1Negative          = 0b00000001_00000000;
    
    /// Second parameter has an negative offset
    enum Option optOffset2Negative          = 0b00000010_00000000;



    /// Instruction operates on bytes
    enum Option optSizeBYTE                 = 0b10000000_00000000;
    
    /// Instruction operates on words
    enum Option optSizeWORD                 = 0b01000000_00000000;
    
    /// Instruction operates on dwords
    enum Option optSizeDWORD                = 0b11000000_00000000;

size_t getDataSizeForOption(Option option) {
    switch(option & 0b11000000_00000000) {
        case(optSizeBYTE):
            return 1;
        case(optSizeWORD):
            return 2;
        case(optSizeDWORD):
            return 4;
        default:
            return 8;
    }
}

//              CPU Flags               \\
/// Flags, NC* flags are placeholders and might have use later.
alias Flag = ushort;

    /// Value is larger than other
    enum Flag flagLargerThan        = 0b00000000_00000001;

    /// Value is equal to other
    enum Flag flagEqual             = 0b00000000_00000010;

    /// Value is negative?
    enum Flag flagSign              = 0b00000000_00000100;

    /// Value A was zero
    enum Flag flagZero              = 0b00000000_00001000;

    /// Overflow (signed overflow)
    enum Flag flagOverflow          = 0b00000000_00010000;

    /// Carry (unsigned overflow)
    enum Flag flagCarry             = 0b00000000_00100000;

    /// Value is negative
    enum Flag flagNegative          = 0b00000000_01000000;

    /// Value X is address. X may vary between instructions!
    enum Flag flagIsAddr            = 0b00000000_10000000;

    /// Value X is compatible with value Y.
    enum Flag flagIsCompatible            = 0b00000001_00000000;


//              Size Tags               \\
alias SizeTag = ubyte;

    /// A byte
    enum SizeTag stBYTE = 0;

    /// A word (2 bytes)
    enum SizeTag stWORD = 1;

    /// A double word (4 bytes)
    enum SizeTag stDWORD = 2;

    /// A quad word (8 bytes)
    enum SizeTag stQWORD = 3;

    /// An FP value (4 bytes)
    enum SizeTag stFP = 4;

    /// An DP-FP value (8 bytes)
    enum SizeTag stDOUBLE = 5;


//              Registers               \\
/// There's 20 general purpose registers (of differing sizes) available.
/// STKP is the stackpointer, can be manipulated to get values from the stack.
/// IC is the instruction counter, cannot be modified directly, other than by using JUMP instructions
/// FLAGS is set via CMP instructions, can be queried via various commands.
alias Register = ubyte;

    /// Register 0
    enum Register regGP0 = 0;

    /// Register 1
    enum Register regGP1 = 1;

    /// Register 2
    enum Register regGP2 = 2;

    /// Register 3
    enum Register regGP3 = 3;

    /// Register 4
    enum Register regGP4 = 4;

    /// Register 5
    enum Register regGP5 = 5;

    /// Register 6
    enum Register regGP6 = 6;

    /// Register 7
    enum Register regGP7 = 7;

    /// FP Register 0
    enum Register regFP0 = 16;

    /// FP Register 1
    enum Register regFP1 = 17;

    /// FP Register 2
    enum Register regFP2 = 18;

    /// FP Register 3
    enum Register regFP3 = 19;

    /// Stack pointer (ptrword)
    enum Register regSTCK = 32;

    /// instruction pointer (ptrword)
    enum Register regIP = 33;

    /// Flag register
    enum Register regFLAGS = 34;

    /// A byte
    enum Register regBYTE =  0b10000000;

    /// A word (2 bytes)
    enum Register regWORD =  0b01000000;

    /// A dword (4 bytes)
    enum Register regDWORD = regBYTE | regWORD;

    /// A qword (8 bytes)
    enum Register regQWORD = 0b00100000;

    /// Set PTR word accordingly to bitdepth of CPU
    version(D_X32)          enum Register regPTRWORD = regDWORD; 
    else version(D_LP64)    enum Register regPTRWORD = regQWORD; /// Set PTR word accordingly to bitdepth of CPU

    size_t getDataCountForRegister(Register reg) {
        if ((regQWORD & reg) == regQWORD) return 8;
        else if ((regDWORD & reg) == regDWORD) return 4;
        else if ((regWORD & reg) == regWORD) return 2;
        else if ((regBYTE & reg) == regBYTE) return 1;

        return size_t.sizeof;
    }

    Register getWidthBits(Register reg) {
        return 0b11100000 & reg;
    }


//              OP Codes                \\
alias OPCode = ubyte;

    /*
            Stack Manipulation
    */

    /// Pop values off stack
    enum OPCode opPOP = 0;

    /// Push value on to stack 
    enum OPCode opPSH = 1;

    /// Peek value offset from stack
    enum OPCode opPEEK = 2;

    /// Call subroutine
    enum OPCode opCALL = 8;

    /// Call D subroutine
    enum OPCode opCALLDPTR = 9;

    /// Return from subroutine
    enum OPCode opRET = 10;

    /*
            Branching/Jumping
    */

    /// Jump to address
    enum OPCode opJMP = 12;

    /// Jump to address if zero
    enum OPCode opJZ = 13;

    /// Jump to address if NOT zero
    enum OPCode opJNZ = 14;

    /// Jump to address if signed
    enum OPCode opJS = 15;

    /// Jump to address if NOT signed
    enum OPCode opJNS = 16;

    /// Jump to address if carry
    enum OPCode opJC = 17;

    /// Jump to address if NOT carry
    enum OPCode opJNC = 18;

    /// Jump to address if equal
    enum OPCode opJE = 19;

    /// Jump to address if NOT equal
    enum OPCode opJNE = 20;

    /// Jump to address if above
    enum OPCode opJA = 21;

    /// Jump to address if above or equal
    enum OPCode opJAE = 22;

    /// Jump to address if below
    enum OPCode opJB = 23;

    /// Jump to address if below or equal
    enum OPCode opJBE = 24;

    /// Compare bytes
    enum OPCode opCMP = 25;

    /*
            Data modification
    */

    /// load
    enum OPCode opLDR = 32;

    /// store
    enum OPCode opSTR = 33;

    /// allocate
    enum OPCode opALLOC = 34;


    /// move 
    enum OPCode opMOV = 44;

    /// move constant
    enum OPCode opMOVC = 45;

    /// Add
    enum OPCode opADD = 64;

    /// Subtract
    enum OPCode opSUB = 65;

    /// Multiply
    enum OPCode opMUL = 66;

    /// Divide
    enum OPCode opDIV = 67;

    /// FRAME
    enum OPCode opFRME = 254;

    /// HALT
    enum OPCode opHALT = 255;


ptrdiff_t getArgCount(OPCode code) {
    switch(code) {
        case (opPSH):               return 1;
        case (opPOP):               return 1;
        case (opPEEK):              return 2;
        case (opCALL):              return 1;
        case (opRET):               return 1;
        case (opJMP):               return 1;
        case (opJZ):                return 1;
        case (opJNZ):               return 1;
        case (opJS):                return 1;
        case (opJNS):               return 1;
        case (opJC):                return 1;
        case (opJNC):               return 1;
        case (opJE):                return 1;
        case (opJNE):               return 1;
        case (opJA):                return 1;
        case (opJAE):               return 1;
        case (opJB):                return 1;
        case (opJBE):               return 1;
        case (opMOVC):              return 2;
        case (opADD):               return 2;
        case (opSUB):               return 2;
        case (opDIV):               return 2;
        case (opMUL):               return 2;
        case (opCMP):               return 2;
        case (opLDR):               return 2;
        case (opSTR):               return 2;
        case (opALLOC):             return 2;
        case (opHALT):              return 0;
        case (opFRME):              return 0;
        default:                    return 0;
    }
}



string getString(OPCode opcode) {
    switch(opcode) {
        case (opPOP):
            return "POP";
        case (opPSH):
            return "PSH";
        case (opPEEK):
            return "PEEK";
        case (opCALL):
            return "CALL";
        case (opCALLDPTR):
            return "CALLDPTR";
        case (opRET):
            return "RET";
        case (opJMP):
            return "JMP";
        case (opJZ):
            return "JZ";
        case (opJNZ):
            return "JNZ";
        case (opJS):
            return "JS";
        case (opJNS):
            return "JNS";
        case (opJC):
            return "JC";
        case (opJNC):
            return "JNC";
        case (opJE):
            return "JE";
        case (opJNE):
            return "JNE";
        case (opJA):
            return "JA";
        case (opJAE):
            return "JAE";
        case (opJB):
            return "JB";
        case (opJBE):
            return "JBE";
        case (opCMP):
            return "CMP";
        case (opLDR):
            return "LDR";
        case (opSTR):
            return "STR";
        case (opALLOC):
            return "ALLOC";
        case (opMOV):
            return "MOV";
        case (opMOVC):
            return "MOVC";
        case (opADD):
            return "ADD";
        case (opSUB):
            return "SUB";
        case (opMUL):
            return "MUL";
        case (opDIV):
            return "DIV";
        case (opFRME):
            return "FRME";
        case (opHALT):
            return "HALT";

        default:
            return "<INVALID OPCODE>";
    }
}