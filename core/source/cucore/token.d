module cucore.token;

/// Token
alias TokenId = ubyte;

/*
    Basic Tokens
*/

/// Unknown token
enum TokenId tkUnknown = 0;

/// Error token
enum TokenId tkError = 1;

/// End-of-file
enum TokenId tkEOF = 2;

/// whitespace
enum TokenId tkWhitespace = 3;

///  //
enum TokenId tkCommentSingle = 4; 

///  /* */
enum TokenId tkCommentMulti = 5; 

///  /+ +/
enum TokenId tkCommentDoc = 6; 

/// inline assembly
enum TokenId tkASM = 9; 

/*
    Literals
*/

/// abc1234_
enum TokenId tkIdentifier = 10;

/// null
enum TokenId tkNullLiteral = 11;

/// 1234
enum TokenId tkIntLiteral = 12;

/// 1.234
enum TokenId tkNumberLiteral = 13;

/// "123"
enum TokenId tkStringLiteral = 14;

/// "blablabla (next line) bla bla bla"
enum TokenId tkMultilineStringLiteral = 15;

/// true/false
enum TokenId tkTrue = 16;
enum TokenId tkFalse = 17;

/// @ (eventual UDA support?)
enum TokenId tkUDA = 27;

// op
/// ++
enum TokenId tkInc = 28; 

/// --
enum TokenId tkDec = 29; 

/// +
enum TokenId tkAdd = 30; 

/// -
enum TokenId tkSub = 31; 

/// /
enum TokenId tkDiv = 32; 

/// *
enum TokenId tkMul = 33; 

/// %
enum TokenId tkMod = 34; 

/// ^
enum TokenId tkPow = 35; 

/// <<
enum TokenId tkShiftLeft = 36; 

/// >>
enum TokenId tkShiftRight = 37; 


/// .
enum TokenId tkDot = 38; 

/// .
enum TokenId tkConcat = 39; 

// assignment
/// =
enum TokenId tkAssign = 50;

/// ++
enum TokenId tkIncAssign = 51;

/// --
enum TokenId tkDecAssign = 52;

/// +=
enum TokenId tkAddAssign = 53;

/// -=
enum TokenId tkSubAssign = 54;

/// /=
enum TokenId tkDivAssign = 55;

/// *=
enum TokenId tkMulAssign = 56;

/// %=
enum TokenId tkModAssign = 57;

/// ^=
enum TokenId tkPowAssign = 58;

/// or=
enum TokenId tkOrAssign = 59;

/// and=
enum TokenId tkAndAssign = 60;

/// xor=
enum TokenId tkXorAssign = 61;

/// !
enum TokenId tkNot = 62;

/*
    Comparison
*/
/// ==
enum TokenId tkEqual = 80;

/// !=
enum TokenId tkNotEqual = 81;

/// <
enum TokenId tkLessThan = 82;

/// >
enum TokenId tkGreaterThan = 83;

/// <=
enum TokenId tkLessThanOrEq = 84;

/// >=
enum TokenId tkGreaterThanOrEq = 85;

/// and
enum TokenId tkAnd = 86;

/// or
enum TokenId tkOr = 87;

/// xor
enum TokenId tkXor = 88;

// statement
/// ;
enum TokenId tkEndStatement = 100;

/// :
enum TokenId tkColon = 101;

/// , 
enum TokenId tkListSep = 102;

/// {
enum TokenId tkStartScope = 103;

/// }
enum TokenId tkEndScope = 104;

/// (
enum TokenId tkOpenParan = 105;

/// )
enum TokenId tkCloseParan = 106;

/// [
enum TokenId tkOpenBracket = 107;

/// ]
enum TokenId tkCloseBracket = 108;

/*
    Types
*/

/// any
enum TokenId tkAny = 110;

/// ubyte
enum TokenId tkUByte = 111;

/// ushort
enum TokenId tkUShort = 112;

/// uint
enum TokenId tkUInt = 113;

/// ulong
enum TokenId tkULong = 114;

/// byte
enum TokenId tkByte = 115;

/// short
enum TokenId tkShort = 116;

/// int
enum TokenId tkInt = 117;

/// long
enum TokenId tkLong = 118;

/// float
enum TokenId tkFloat = 119;

/// double
enum TokenId tkDouble = 120;

/// char
enum TokenId tkChar = 121;

/// string
enum TokenId tkString = 122;

/// Array
enum TokenId tkArray = 123;

/// ptr
enum TokenId tkPtr = 124;

/// meta
enum TokenId tkMeta = 125;

/// function
enum TokenId tkFunction = 126;

/// user defined types (structs)
enum TokenId tkUserDefined = 127;

/// struct
enum TokenId tkStruct = 128;

/// class
enum TokenId tkClass = 129;

/// void
enum TokenId tkVoid = 130;


/*
    Keywords
*/
/// this
enum TokenId tkThis = 200;

/// if
enum TokenId tkIf = 201;

/// else
enum TokenId tkElse = 202;

/// while
enum TokenId tkWhile = 203;

/// for
enum TokenId tkFor = 204;

/// foreach
enum TokenId tkForeach = 205;

/// is
enum TokenId tkIs = 206;

/// !is
enum TokenId tkNotIs = 207;

/// local/private
enum TokenId tkLocal = 208;

/// global/public
enum TokenId tkGlobal = 209;

/// import
enum TokenId tkImport = 210;

/// module
enum TokenId tkModule = 211;

/// fallback
enum TokenId tkFallback = 212;

/// return
enum TokenId tkReturn = 213;

/// break
enum TokenId tkBreak = 214;

/// as
enum TokenId tkAs = 215;

/// unit
enum TokenId tkUnitTest = 216;

/// exdecl
enum TokenId tkExternalDeclaration = 216;

/*
    Debugging
*/
/// Panic operation (print VM register data)
enum TokenId tkPanic = 255;

/// A Token
public struct Token {
package:
    string source;

public:
    this(string* source, TokenId id, size_t start, size_t length, size_t line, size_t pos) {
        this.start = start;
        this.id = id;
        this.length = length;
        this.line = line;
        this.pos = pos;
        this.source = *source;
    }

    /// The Id of the token
    TokenId id;
    
    /// Start of token
    size_t start;
    
    /// Length of token
    size_t length;

    /// The line of the token
    size_t line;

    /// position of token on the line
    size_t pos;

    string toString() {
        import std.conv;
        return "id=" ~ id.text ~ " lexeme='" ~ lexeme ~ "' @ line " ~ line.text ~ " pos " ~ pos.text;
    }

    string lexeme() {
        return source[start..length];
    }
}
