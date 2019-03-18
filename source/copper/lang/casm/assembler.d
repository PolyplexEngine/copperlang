/*
    Miniature assembler for the copperlang vm bytecode
    P much forcefully ripped most of the code from the copperlang lexer to make this.
*/
module copper.lang.casm.assembler;
import copper.lang.compiler.chunk;
import copper.lang.arch;
import std.stdio;
import std.conv;
import std.uni;
import copper.share.utils.strutils;

alias asmTokenId = ushort;

enum asmTokenId tkUnknown = 0;
enum asmTokenId tkError = 0;
enum asmTokenId tkEOF = 0;

/// Pop values off stack
enum asmTokenId tkPOP = 1;

/// Push value on to stack 
enum asmTokenId tkPSH = 2;

/// Peek value offset from stack
enum asmTokenId tkPEEK = 3;

/// Call subroutine
enum asmTokenId tkCALL = 8;

/// Call D subroutine
enum asmTokenId tkCALLDPTR = 9;

/// Return from subroutine
enum asmTokenId tkRET = 10;

/*
        Branching/Jumping
*/

/// Jump to address
enum asmTokenId tkJMP = 12;

/// Jump to address if zero
enum asmTokenId tkJZ = 13;

/// Jump to address if NOT zero
enum asmTokenId tkJNZ = 14;

/// Jump to address if signed
enum asmTokenId tkJS = 15;

/// Jump to address if NOT signed
enum asmTokenId tkJNS = 16;

/// Jump to address if carry
enum asmTokenId tkJC = 17;

/// Jump to address if NOT carry
enum asmTokenId tkJNC = 18;

/// Jump to address if equal
enum asmTokenId tkJE = 19;

/// Jump to address if NOT equal
enum asmTokenId tkJNE = 20;

/// Jump to address if above
enum asmTokenId tkJA = 21;

/// Jump to address if above or equal
enum asmTokenId tkJAE = 22;

/// Jump to address if below
enum asmTokenId tkJB = 23;

/// Jump to address if below or equal
enum asmTokenId tkJBE = 24;

/// Compare bytes
enum asmTokenId tkCMP = 25;

/*
        Data modification
*/

/// load
enum asmTokenId tkLDR = 32;

/// store
enum asmTokenId tkSTR = 33;

/// move 
enum asmTokenId tkMOV = 44;

/// move constant
enum asmTokenId tkMOVC = 45;

/// Add
enum asmTokenId tkADD = 64;

/// Subtract
enum asmTokenId tkSUB = 65;

/// Multiply
enum asmTokenId tkMUL = 66;

/// Divide
enum asmTokenId tkDIV = 67;

/// FRAME
enum asmTokenId tkFRME = 254;

/// HALT
enum asmTokenId tkHALT = 255;

/// Value splitter (,)
enum asmTokenId tkSplit = 1000;

/// Label (identifier):
enum asmTokenId tkLabel = 1001;

enum asmTokenId tkMemAddr = 1002;

enum asmTokenId tkOffsetMark = 1003;

enum asmTokenId tkInteger = 100;
enum asmTokenId tkDecimal = 101;
enum asmTokenId tkChar = 102;
enum asmTokenId tkString = 103;

enum asmTokenId tkGP0 = 120;
enum asmTokenId tkGP1 = 121;
enum asmTokenId tkGP2 = 122;
enum asmTokenId tkGP3 = 123;
enum asmTokenId tkGP4 = 124;
enum asmTokenId tkGP5 = 125;
enum asmTokenId tkGP6 = 126;
enum asmTokenId tkGP7 = 127;

enum asmTokenId tkFP0 = 128;
enum asmTokenId tkFP1 = 129;
enum asmTokenId tkFP2 = 130;
enum asmTokenId tkFP3 = 131;
enum asmTokenId tkESP = 132;
enum asmTokenId tkIP = 133;

private string tokenOp(string op)
{
    import std.format : format;
    return q{case tk%s:
    return op%s;}.format(op, op);
}

private string tokenReg(string op)
{
    import std.format : format;
    return q{case tk%s:
    return reg%s;}.format(op, op);
}

asmTokenId tokenToReg(asmTokenId tkid) {
    switch (tkid)
    {
        mixin(tokenReg("GP0"));
        mixin(tokenReg("GP1"));
        mixin(tokenReg("GP2"));
        mixin(tokenReg("GP3"));
        mixin(tokenReg("GP4"));
        mixin(tokenReg("GP5"));
        mixin(tokenReg("GP6"));
        mixin(tokenReg("GP7"));
        mixin(tokenReg("FP0"));
        mixin(tokenReg("FP1"));
        mixin(tokenReg("FP2"));
        mixin(tokenReg("FP3"));
        default:
            throw new Exception("Invalid token id!");
    }
}

OPCode tokenToOp(asmTokenId tkid)
{
    switch (tkid)
    {
        mixin(tokenOp("PSH"));
        mixin(tokenOp("POP"));
        mixin(tokenOp("PEEK"));
        mixin(tokenOp("CALL"));
        mixin(tokenOp("RET"));
        mixin(tokenOp("JMP"));
        mixin(tokenOp("JZ"));
        mixin(tokenOp("JNZ"));
        mixin(tokenOp("JS"));
        mixin(tokenOp("JNS"));
        mixin(tokenOp("JC"));
        mixin(tokenOp("JNC"));
        mixin(tokenOp("JE"));
        mixin(tokenOp("JNE"));
        mixin(tokenOp("JA"));
        mixin(tokenOp("JAE"));
        mixin(tokenOp("JB"));
        mixin(tokenOp("JBE"));
        mixin(tokenOp("MOVC"));
        mixin(tokenOp("ADD"));
        mixin(tokenOp("SUB"));
        mixin(tokenOp("DIV"));
        mixin(tokenOp("MUL"));
        mixin(tokenOp("CMP"));
        mixin(tokenOp("LDR"));
        mixin(tokenOp("STR"));
        mixin(tokenOp("HALT"));
        mixin(tokenOp("FRME"));
    default:
        throw new Exception("Invalid token id!");
    }
}

/// A value
enum asmTokenId tkIdentifier = 253;

alias TokenizerErrorHandler = void delegate(string, ASMToken, string);
private static asmTokenId[string] keywords;

shared static this()
{
    // Stack
    keywords["pop"] = tkPOP;
    keywords["push"] = tkPSH;
    keywords["psh"] = tkPSH;
    keywords["peek"] = tkPEEK;

    // Calling
    keywords["call"] = tkCALL;
    keywords["calldptr"] = tkCALLDPTR;
    keywords["ret"] = tkRET;

    // branching
    keywords["jmp"] = tkJMP;
    keywords["jz"] = tkJZ;
    keywords["jnz"] = tkJNZ;
    keywords["js"] = tkJZ;
    keywords["jns"] = tkJNS;
    keywords["jc"] = tkJC;
    keywords["jnc"] = tkJNC;
    keywords["je"] = tkJE;
    keywords["jne"] = tkJNE;
    keywords["ja"] = tkJA;
    keywords["jae"] = tkJAE;
    keywords["jb"] = tkJB;
    keywords["jbe"] = tkJBE;

    // Data mod
    keywords["ldr"] = tkLDR;
    keywords["str"] = tkSTR;
    keywords["mov"] = tkMOV;
    keywords["movc"] = tkMOVC;

    // binary op
    keywords["cmp"] = tkCMP;
    keywords["add"] = tkADD;
    keywords["sub"] = tkSUB;
    keywords["mul"] = tkMUL;
    keywords["div"] = tkDIV;

    // debugging
    keywords["frme"] = tkFRME;
    keywords["halt"] = tkHALT;

    // registers
    keywords["gp0"] = tkGP0;
    keywords["gp1"] = tkGP1;
    keywords["gp2"] = tkGP2;
    keywords["gp3"] = tkGP3;
    keywords["gp4"] = tkGP4;
    keywords["gp5"] = tkGP5;
    keywords["gp6"] = tkGP6;
    keywords["gp7"] = tkGP7;
    keywords["fp0"] = tkFP0;
    keywords["fp1"] = tkFP1;
    keywords["fp2"] = tkFP2;
    keywords["fp3"] = tkFP3;
    keywords["esp"] = tkESP;
    keywords["ip"] = tkIP;

}

/// asm token
public struct ASMToken
{
private:
    string source;

public:
    this(string* source, asmTokenId id, size_t start, size_t length, size_t line, size_t pos)
    {
        this.start = start;
        this.id = id;
        this.length = length;
        this.line = line;
        this.pos = pos;
        this.source = *source;
    }

    /// The Id of the token
    asmTokenId id;

    /// Start of token
    size_t start;

    /// Length of token
    size_t length;

    /// The line of the token
    size_t line;

    /// position of token on the line
    size_t pos;

    string toString()
    {
        import std.conv;

        return "id=" ~ id.text ~ " lexeme='" ~ lexeme ~ "' @ line " ~ line.text ~ " pos " ~ pos
            .text;
    }

    string lexeme()
    {
        return source[start .. length];
    }
}

/// The lexer
struct ASMLexer
{
private:
    string source;
    size_t start;
    size_t current;

    // TODO: tktimize this via caching?
    size_t pos()
    {
        size_t pos = 0;
        foreach (i; 0 .. start)
        {
            pos++;
            if (source[i] == '\n')
                pos = 0;
        }
        return pos + 1;
    }

    size_t line()
    {
        size_t line = 0;
        foreach (i; 0 .. start)
        {
            line += source[i] == '\n' ? 1 : 0;
        }
        return line;
    }

    void internalErrFunc(string source, ASMToken tk, string error)
    {
        writeln(error);
    }

    // Lexing utils
    bool isValidIdenChar(char c)
    {
        return isAlphaNum(c) || c == '_' || c == '.';
    }

    char advance()
    {
        current++;
        return source[current - 1];
    }

    char peek()
    {
        return eof ? '\0' : source[current];
    }

    bool match(char exp)
    {
        if (eof)
            return false;
        if (source[current] != exp)
            return false;

        current++;
        return true;
    }

    char peekAt(size_t relpos)
    {
        return current + relpos >= source.length ? '\n' : source[current + relpos];
    }

    /// One index of lookahead
    void peekNext(ASMToken* token)
    {
        scanToken(token);
        rewindTo(token);
    }

    // dead simple lol
    ASMToken lexChar()
    {
        advance();
        if (advance() != '\'')
        {
            ASMToken error = mkError();
            errorHandler(source, error, "Character literals can only contain a single character!");
            return error;
        }
        return mkToken(tkChar, start, current);
    }

    ASMToken lexString()
    {
        while (peek != '"' && !eof)
        {
            advance();
        }

        if (eof)
        {
            ASMToken error = mkError();
            errorHandler(source, error, "string unterminated!");
            return error;
        }

        // Read closing "
        advance();
        return mkToken(tkString, start, current);
    }

    ASMToken lexNumeric()
    {
        bool isDecimal = false;
        while (isNumber(peek))
            advance();
        if (peek == '.' && isNumber(peekAt(1)))
        {
            advance();

            isDecimal = true;
            while (isNumber(peek))
                advance();

            // Return number
            return mkToken(tkDecimal);
        }
        // return integer (non-decimal)
        return mkToken(tkInteger);
    }

    ASMToken lexIdentifier()
    {
        import std.uni : toLower;

        while (isValidIdenChar(peek))
            advance();

        string idxText = source[start .. current].toLower;
        if (peek == ':')
        {
            advance();
            return mkToken(tkLabel);
        }

        asmTokenId token = idxText in keywords ? keywords[idxText] : tkUnknown;
        return mkToken(token == tkUnknown ? tkIdentifier : token);
    }

public:
    /// Error handler
    TokenizerErrorHandler errorHandler;

    /// Make "unknown" token
    ASMToken mkToken()
    {
        return mkToken(tkUnknown);
    }

    /// Make empty token
    ASMToken mkEmpty()
    {
        return ASMToken(&source, tkUnknown, start, current, line, pos);
    }

    /// Make error marker token
    ASMToken mkError()
    {
        return ASMToken(&source, tkError, start, current, line, pos);
    }

    /// Make token with id
    ASMToken mkToken(asmTokenId id)
    {
        return ASMToken(&source, id, start, current, line, pos);
    }

    /// Make token with custom parameters.
    ASMToken mkToken(asmTokenId id, size_t start, size_t len)
    {
        return ASMToken(&source, id, start, len, line, pos);
    }

    /// Get the source code this lexer is attached to.
    string getSource()
    {
        return source;
    }

    /// Constructs a new lexer.
    this(string source)
    {
        this.source = source;
        this.start = 0;
        this.current = 0;
        this.errorHandler = &internalErrFunc;
    }

    /// Gets wether END OF FILE was reached.
    bool eof()
    {
        return current >= source.length;
    }

    /// Rewind lexer to token.
    void rewindTo(ASMToken* tk)
    {
        this.start = tk.start;
        this.current = tk.start;
    }

    void skipUnwanted()
    {
        while (true)
        {
            char c = peek();
            switch (c)
            {
            case ' ':
            case '\r':
            case '\n':
            case '\t':
                advance();
                break;
            case ';':
                // single line comment
                while (peek() != '\n' && !eof)
                    advance();
                advance();
                break;
            default:
                start = current;
                return;
            }
        }
    }

    void scanToken(ASMToken* token)
    {
        // skip whitespace, comments, etc.
        skipUnwanted();
        ASMToken strASMToken = mkEmpty();

        if (eof)
        {
            *token = mkToken(tkEOF);
            return;
        }

        char c = advance();
        switch (c)
        {
        case ',':
            strASMToken = mkToken(tkSplit);
            break;
        case '\'':
            strASMToken = lexChar();
            break;
        case '"':
            strASMToken = lexString();
            break;
        default:
            if (isNumber(c))
            {
                strASMToken = lexNumeric();
                break;
            }
            else if (isValidIdenChar(c))
            {
                strASMToken = lexIdentifier();
                break;
            }
            import std.conv : text;

            errorHandler(source, strASMToken, "Unexpected '" ~ c.escape ~ "'");
            *token = mkError();

            token.start = 0;
            token.length = 0;
            return;
        }

        // Set data.
        (*token) = strASMToken;
        start = current;
    }

}

class Assembler
{
private:
    ChunkBuilder chunkBuilder;
    ASMToken prevToken;
    ASMToken curToken;
    ASMLexer lexer;
    bool doSkipComments;

    void getToken(ASMToken* token, string func = __PRETTY_FUNCTION__)
    {
        prevToken = curToken;
        if (token is null)
        {
            lexer.scanToken(&curToken);
            return;
        }
        lexer.scanToken(token);
        string tk = token.lexeme ~ " @" ~ token.line.text ~ " " ~ token.pos.text;
        //writeln(tk, "\n", func.offsetBy(tk.length), "\n");
        curToken = *token;
    }

    void rewindTo(ASMToken* token)
    {
        lexer.rewindTo(token);
    }

    void advance()
    {
        getToken(null);
    }

    void peekNext(ASMToken* token, string func = __PRETTY_FUNCTION__)
    {
        lexer.peekNext(token);
        string tk = token.lexeme ~ " @" ~ token.line.text ~ " " ~ token.pos.text;
        //writeln(tk, "\n", func.offsetBy(tk.length), "\n");
    }

    ASMToken previous()
    {
        return prevToken;
    }

    ASMToken peek()
    {
        ASMToken tk;
        lexer.peekNext(&tk);
        return tk;
    }

    bool check(ASMToken tk, asmTokenId tkId)
    {
        if (eof)
            return false;
        return tk.id == tkId;
    }

    bool eof()
    {
        return lexer.eof;
    }

    bool match(ASMToken tk, asmTokenId[] vars)
    {
        foreach (tkx; vars)
        {
            if (check(tk, tkx))
            {
                return true;
            }
        }
        return false;
    }

    void error(string errMsg, ASMToken* tkRef = null)
    {
        writeln(errMsg);
        /* if (tkRef is null)
        {
            ASMToken tk;
            peekNext(&tk);
            throw new Exception(getErrorText(lexer.getSource, tk, errMsg));
        }
        throw new Exception(getErrorText(lexer.getSource, *tkRef, errMsg));*/
    }

    // impl
    ASMToken consume(asmTokenId type, string errMsg, ASMToken* tkRef = null,
            string funcCaller = __PRETTY_FUNCTION__)
    {
        ASMToken tk;
        peekNext(&tk, funcCaller ~ " <consuming>");

        if (check(tk, type))
        {
            getToken(&tk, funcCaller ~ " <consumed>");
            // Consume token
            return tk;
        }
        error(errMsg, tkRef !is null ? tkRef : &tk);
        return tk;
    }

    bool matchRegisters(ASMToken tk)
    {
        return match(tk, [tkGP0, tkGP1, tkGP2, tkGP3, tkGP4, tkGP5, tkGP6,
                tkGP7, tkFP0, tkFP1, tkFP2, tkFP3, tkESP, tkIP]);
    }

    bool hasParams() {
        ASMToken tk;
        peekNext(&tk);
        return (match(tk, [tkInteger, tkIdentifier]) || matchRegisters(tk));
    }

    bool hasIdentifierParam() {
        ASMToken tk;
        peekNext(&tk);
        return (match(tk, [tkIdentifier]));
    }

    string parseIdentifier() {
        ASMToken tk;
        getToken(&tk);
        return tk.lexeme;
    }

    size_t[] parseNumericParams(bool expectRegister = true, bool expectAddress = true, string funcName = __FUNCTION__) {
        ASMToken tk;
        ASMToken tk2;
        size_t[] output;
        do {
            if (match(tk2, [tkSplit])) consume(tkSplit, "Expected ','! in "~funcName);
            getToken(&tk);
            peekNext(&tk2);

            if (expectRegister && matchRegisters(tk))
            {
                output ~= tokenToReg(tk.id);
                continue;
            }
            
            if (expectAddress && tk.id == tkInteger) {
                output ~= to!size_t(tk.lexeme);
                continue;
            }
            error("Expected intergral or register, got "~tk.lexeme ~" ("~ tk.id.text ~ ")! in "~funcName);
        } while(match(tk2, [tkSplit]) && !eof);
        return output;
    }

public:

    this()
    {
        chunkBuilder = new ChunkBuilder();
    }

    ChunkBuilder getBuilder()
    {
        return chunkBuilder;
    }

    void assemblePSH()
    {
        size_t[] params = parseNumericParams(true, false);
        chunkBuilder.writePSH(cast(Register)params[0]);
    }

    void assemblePOP()
    {
        if (hasParams) {
            size_t[] params = parseNumericParams(false, true);
            chunkBuilder.writePOP(params[0]);
        } else {
            chunkBuilder.writePOP();
        }
    }

    void assemblePEEK()
    {
        size_t[] params = parseNumericParams(true, true);
        chunkBuilder.writePEEK(cast(Register)params[1], params[0]);
    }

    void assembleMOVC() {
        size_t[] params = parseNumericParams(true, true);
        chunkBuilder.writeMOVC(params[0], cast(Register)params[1]);
    }

    CObject* assemble(string code)
    {
        lexer = ASMLexer(code);

        ASMToken tk;
        ASMToken tk2;

        do
        {
            peekNext(&tk);
            switch (tk.id)
            {
            case tkLabel:
                advance();
                // Set label
                chunkBuilder.setLabel(tk.lexeme[0 .. $ - 1]);
                continue;

            case tkMOVC:
                advance();
                assembleMOVC();
                continue;

            case tkPOP:
                advance();
                assemblePOP();
                continue;

            case tkPEEK:
                advance();
                assemblePEEK();
                continue;

            case tkPSH:
                advance();
                assemblePSH();
                continue;

            // Call is technically a jump and uses the same syntax.
            case tkCALL:
            case tkJMP:
            case tkJZ:
            case tkJNZ:
            case tkJS:
            case tkJNS:
            case tkJC:
            case tkJNC:
            case tkJA:
            case tkJAE:
            case tkJB:
            case tkJBE:
                advance();
                if (hasIdentifierParam()) {
                    string jto = parseIdentifier();
                    writeln("JUMPTO=", jto);
                    chunkBuilder.writeJMPG(tokenToOp(tk.id), jto);
                    continue;
                }
                size_t[] params = parseNumericParams(false, true);
                chunkBuilder.writeJMPG(tokenToOp(tk.id), params[0]);
                continue;

            case tkCMP:
                advance();
                size_t[] params = parseNumericParams(true, false);
                chunkBuilder.writeCMP(cast(Register)params[0], cast(Register)params[1]);
                continue;
            
            case tkADD:
                advance();
                size_t[] params = parseNumericParams(true, false);
                chunkBuilder.writeADD(cast(Register)params[0], cast(Register)params[1]);
                continue;

            case tkSUB:
                advance();
                size_t[] params = parseNumericParams(true, false);
                chunkBuilder.writeSUB(cast(Register)params[0], cast(Register)params[1]);
                continue;

            case tkMUL:
                advance();
                size_t[] params = parseNumericParams(true, false);
                chunkBuilder.writeMUL(cast(Register)params[0], cast(Register)params[1]);
                continue;

            case tkDIV:
                advance();
                size_t[] params = parseNumericParams(true, false);
                chunkBuilder.writeDIV(cast(Register)params[0], cast(Register)params[1]);
                continue;


            case tkRET:
                advance(); 
                if (hasParams) {
                    size_t[] params = parseNumericParams(false, true);
                    chunkBuilder.writeRET(params[0]);
                } else {
                    chunkBuilder.writeRET();
                }
                continue;


            case tkFRME:
                advance();
                chunkBuilder.writeFRME();
                continue;

            case tkHALT:
                advance();
                chunkBuilder.writeHALT();
                continue;

            default:
                break;
            }
            if (tk.id == tkEOF) break;
            error("Invalid token at position... <"~tk.lexeme~">");
            break;

        }
        while (tk.id != tkEOF);

        return chunkBuilder.build();
    }

}
