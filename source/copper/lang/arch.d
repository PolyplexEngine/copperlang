module copper.lang.arch;
public:
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

/// Stack pointer (qword)
enum Register regSTCK = 8;

/// instruction counter (qword)
enum Register regIC = 9;

/// Flag register
enum Register regFLAGS = 10;

/// A byte
enum Register regBYTE =  0b10000000;

/// A word (2 bytes)
enum Register regWORD =  0b01000000;

/// A dword (4 bytes)
enum Register regDWORD = regBYTE | regWORD;

/// A qword (8 bytes)
enum Register regQWORD = 0b00100000;

// Set PTR word accordingly to bitdepth of CPU
version(D_X32)          enum Register regPTRWORD = regDWORD;
else version(D_LP64)    enum Register regPTRWORD = regQWORD;



//              OP Codes                \\
alias OPCode = ubyte;

/*
        Stack Manipulation
*/

/// Pop values off stack
enum OPCode opPOP = 0;

/// Push D pointer value on to stack 
enum OPCode opPSH = 1;

/// Push constant value to stack
enum OPCode opPSHC = 2;

/// Push value on to stack
enum OPCode opPSHV = 3;

/// Call subroutine
enum OPCode opCALL = 5;

/// Call D subroutine
enum OPCode opCALLDPTR = 6;

/// Return from subroutine
enum OPCode opRET = 7;

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

/// Compare words
enum OPCode opCMPW = 26;

/// Compare dwords
enum OPCode opCMPD = 27;

/// Compare qwords
enum OPCode opCMPQ = 28;

/// Compare floats
enum OPCode opCMPF = 29;

/// Compare doubles
enum OPCode opCMPDF = 30;

/*
        Data modification
*/

/// move byte ( 1 byte )
enum OPCode opMOV = 40;

/// move word ( 2 bytes )
enum OPCode opMOVW = 41;

/// move dword ( 4 bytes )
enum OPCode opMOVD = 42;

/// move qword ( 8 bytes )
enum OPCode opMOVQ = 42;


/// Add byte ( 1 byte )
enum OPCode opADD = 45;

/// Add word ( 2 bytes )
enum OPCode opADDW = 46;

/// Add dword ( 4 bytes)
enum OPCode opADDD = 47;

/// Add qword ( 8 bytes )
enum OPCode opADDQ = 48;

/// Add float ( 4 bytes )
enum OPCode opADDF = 49;

/// Add double ( 8 bytes )
enum OPCode opADDDF = 50;



/// Subtract byte ( 1 byte )
enum OPCode opSUB = 51;

/// Subtract word ( 2 bytes )
enum OPCode opSUBW = 52;

/// Subtract dword ( 4 bytes)
enum OPCode opSUBD = 53;

/// Subtract qword ( 8 bytes )
enum OPCode opSUBQ = 54;

/// Subtract float ( 4 bytes )
enum OPCode opSUBF = 55;

/// Subtract double ( 8 bytes )
enum OPCode opSUBDF = 56;



/// Multiply byte ( 1 byte )
enum OPCode opMUL = 57;

/// Multiply word ( 2 bytes )
enum OPCode opMULW = 58;

/// Multiply dword ( 4 bytes)
enum OPCode opMULD = 59;

/// Multiply qword ( 8 bytes )
enum OPCode opMULQ = 60;

/// Multiply float ( 4 bytes )
enum OPCode opMULF = 61;

/// Multiply double ( 8 bytes )
enum OPCode opMULDF = 62;


/// Divide byte ( 1 byte )
enum OPCode opDIV = 57;

/// Divide word ( 2 bytes )
enum OPCode opDIVW = 58;

/// Divide dword ( 4 bytes)
enum OPCode opDIVD = 59;

/// Divide qword ( 8 bytes )
enum OPCode opDIVQ = 60;

/// Divide float ( 4 bytes )
enum OPCode opDIVF = 61;

/// Divide double ( 8 bytes )
enum OPCode opDIVDF = 62;




size_t getArgCount(OPCode code) {
    switch(code) {
        case (opPSH):               return 1;
        case (opPSHC):              return 1;
        case (opPOP):               return 1;
        case (opCALL):              return 1;
        case (opRET):               return 0;
        case (opJMP):               return 0;
        case (opJZ):                return 0;
        case (opJNZ):               return 0;
        case (opJS):                return 0;
        case (opJNS):               return 0;
        default:                    return 0;
    }
}



string getString(OPCode opcode) {
    switch(opcode) {
        case (opPSH):
            return "PSH";
        case (opPSHC):
            return "PSHC";
        case (opPOP):
            return "POP";
        case (opCALL):
            return "CALL";
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
        case (opJA):
            return "JA";
        case (opJAE):
            return "JAE";

        default:
            return "<INVALID OPCODE>";
    }
}