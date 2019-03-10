/*
    Miniature assembler for the copperlang vm bytecode
    P much forcefully ripped most of the code from the copperlang lexer to make this.
*/
module copper.lang.casm.assembler;
import std.stdio;
import std.conv;
import std.uni;
import copper.share.utils.strutils;
/*
alias asmTokenId = ubyte;

enum asmTokenId tkUnknown = 0;
enum asmTokenId tkError = 0;
enum asmTokenId tkEOF = 0;

/// call D procedure
enum asmTokenId tkPCALL = 50;

/// call function
enum asmTokenId tkCALL = 51;

/// return from function
enum asmTokenId tkRET = 52;

/// Inject following values in to code directly
enum asmTokenId tkDB = 255;

/// Value splitter (,)
enum asmTokenId tkSplit = 254;
/// Label (identifier):
enum asmTokenId tkLabel = 253;

enum asmTokenId tkIntergral = 100;
enum asmTokenId tkDecimal = 101;
enum asmTokenId tkChar = 102;
enum asmTokenId tkString = 103;

/// A value
enum asmTokenId tkIdentifier = 253;

alias TokenizerErrorHandler = void delegate(string, ASMToken, string);
private static asmTokenId[string] keywords;

shared static this()
{
    keywords["psh"] = tkPSH;
    keywords["pshx"] = tkPSHX;

    keywords["pop"] = tkPOP;
    keywords["popx"] = tkPOPX;

    keywords["mov"] = tkMOV;
    keywords["cmp"] = tkCMP;
    keywords["cmpt"] = tkCMPT;

    keywords["jmpeq"] = tkJEQ;
    keywords["jmpne"] = tkJNE;
    keywords["jmpse"] = tkJSE;
    keywords["jmple"] = tkJLE;
    keywords["jmps"] = tkJS;
    keywords["jmpl"] = tkJL;
    keywords["pcall"] = tkPCALL;
    keywords["call"] = tkCALL;
    keywords["ret"] = tkRET;
    keywords["db"] = tkDB;

}

/// asm token
public struct ASMToken {
private:
    string source;

public:
    this(string* source, asmTokenId id, size_t start, size_t length, size_t line, size_t pos) {
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

    string toString() {
        import std.conv;
        return "id=" ~ id.text ~ " lexeme='" ~ lexeme ~ "' @ line " ~ line.text ~ " pos " ~ pos.text;
    }

    string lexeme() {
        return source[start..length];
    }
}

/// The lexer
struct ASMLexer {
private:
    string source;
    size_t start;
    size_t current;

    // TODO: Optimize this via caching?
    size_t pos() {
        size_t pos = 0;
        foreach (i; 0 .. start)
        {
            pos++;
            if (source[i] == '\n')
                pos = 0;
        }
        return pos + 1;
    }

    size_t line() {
        size_t line = 0;
        foreach (i; 0 .. start)
        {
            line += source[i] == '\n' ? 1 : 0;
        }
        return line;
    }

    void internalErrFunc(string source, ASMToken tk, string error) {
        writeln(error);
    }

    // Lexing utils
    bool isValidIdenChar(char c) {
        return isAlphaNum(c) || c == '_';
    }

    char advance() {
        current++;
        return source[current - 1];
    }

    char peek() {
        return eof ? '\0' : source[current];
    }

    bool match(char exp) {
        if (eof)
            return false;
        if (source[current] != exp)
            return false;

        current++;
        return true;
    }

    char peekAt(size_t relpos) {
        return current + relpos >= source.length ? '\n' : source[current + relpos];
    }

    // dead simple lol
    ASMToken lexChar() {
        advance();
        if (advance() != '\'') {
            ASMToken error = mkError();
            errorHandler(source, error, "Character literals can only contain a single character!");
            return error;
        }
        return mkToken(tkChar, start, current);
    }

    ASMToken lexString() {
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

    ASMToken lexNumeric() {
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
        return mkToken(tkIntergral);
    }

    ASMToken lexIdentifier() {
        while (isValidIdenChar(peek))
            advance();

        if (peek == ':') {
            string idxText = source[start .. current];
            advance();
            return mkToken(tkLabel);
        }

        string idxText = source[start .. current];
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
        ASMToken strToken = mkEmpty();

        if (eof)
        {
            *token = mkToken(tkEOF);
            return;
        }

        char c = advance();
        switch (c)
        {
        case ',':
            strToken = mkToken(tkSplit);
            break;
        case '\'':
            strToken = lexChar();
            break;
        case '"':
            strToken = lexString();
            break;
        default:
            if (isNumber(c))
            {
                strToken = lexNumeric();
                break;
            }
            else if (isValidIdenChar(c))
            {
                strToken = lexIdentifier();
                break;
            }
            import std.conv : text;

            errorHandler(source, strToken, "Unexpected '" ~ c.escape ~ "'");
            *token = mkError();

            token.start = 0;
            token.length = 0;
            return;
        }

        // Set data.
        (*token) = strToken;
        start = current;
    }

}

struct Assembler {
    
}*/