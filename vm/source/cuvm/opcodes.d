module cuvm.opcodes;

alias OpCode = ubyte;

/// OpCode to return
enum OpCode opRETURN = 0;

enum OpCode opCONST = 1;

enum OpCode opNEGATE = 2;

enum OpCode opADD = 3;
enum OpCode opSUB = 4;
enum OpCode opMUL = 5;
enum OpCode opDIV = 6;
enum OpCode opMOD = 7;

enum OpCode opCAST = 8;

/// Appends strings and strings
enum OpCode opAPPEND = 8;

/*
    Utility stuff
*/
enum OpCode opSTK = 254;
enum OpCode opPRINT = 255;














/*
            EXTRA STUFF
*/

/**
    Information about an opcode
*/
struct OpCodeInfo {
    /// Name of opcode
    string name;

    /// Size (in bytes) of the data for the opcode
    size_t dataSize;
}

/// A map from opcode to human readable instructions
OpCodeInfo[OpCode] OpCodeMap;
static this() {
    OpCodeMap = [
        opRETURN: OpCodeInfo("RET", 1),
        opCONST: OpCodeInfo("CONST", 9),
        opNEGATE: OpCodeInfo("NEGATE", 1),
        opPRINT: OpCodeInfo("PRINT", 1),
        opADD: OpCodeInfo("ADD", 1),
        opSUB: OpCodeInfo("SUB", 1),
        opMUL: OpCodeInfo("MUL", 1),
        opDIV: OpCodeInfo("DIV", 1),
        opMOD: OpCodeInfo("MOD", 1),
        opSTK: OpCodeInfo("DEBUG STACK", 1)
    ];
}