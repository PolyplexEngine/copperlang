module copper.lang.lexer.lexer;
import copper.share.utils.list;
import copper.lang.token;
import std.uni;
import std.stdio;
import copper.share.utils.strutils;

private static TokenId[string] keywords;

shared static this()
{
    keywords["asm"] = tkASM;

    keywords["or"] = tkOr;
    keywords["or="] = tkOrAssign;
    keywords["and"] = tkAnd;
    keywords["and="] = tkAndAssign;
    keywords["xor"] = tkXor;
    keywords["xor="] = tkXorAssign;

    keywords["any"] = tkAny;
    keywords["ubyte"] = tkUByte;
    keywords["ushort"] = tkUShort;
    keywords["uint"] = tkUInt;
    keywords["ulong"] = tkULong;
    keywords["byte"] = tkByte;
    keywords["short"] = tkShort;
    keywords["int"] = tkInt;
    keywords["long"] = tkLong;
    keywords["float"] = tkFloat;
    keywords["double"] = tkDouble;

 
    keywords["ptr"] = tkPtr;
    keywords["string"] = tkString;
    keywords["char"] = tkChar;
    keywords["struct"] = tkStruct;
    keywords["class"] = tkClass;
    keywords["meta"] = tkMeta;
    keywords["func"] = tkFunction;
    keywords["null"] = tkNullLiteral;

    keywords["true"] = tkTrue;
    keywords["false"] = tkFalse;
    keywords["yes"] = tkTrue;
    keywords["no"] = tkFalse;

    keywords["this"] = tkThis;
    keywords["if"] = tkIf;
    keywords["else"] = tkElse;
    keywords["while"] = tkWhile;
    keywords["for"] = tkFor;
    keywords["foreach"] = tkForeach;
    keywords["is"] = tkIs;
    keywords["!is"] = tkNotIs;
    keywords["import"] = tkImport;
    keywords["module"] = tkModule;
    keywords["fallback"] = tkFallback;
    keywords["return"] = tkReturn;
    keywords["break"] = tkBreak;
    keywords["as"] = tkAs;

    keywords["panic"] = tkPanic;

    keywords["local"] = tkLocal;
    keywords["private"] = tkLocal;
    keywords["global"] = tkGlobal;
    keywords["public"] = tkGlobal;
}

alias TokenizerErrorHandler = void delegate(string, Token, string);

struct Lexer
{
private:
    bool skipComments = false;
    string source;
    size_t start;
    size_t current;

    // TODO: Optimize this via caching?
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

    void internalErrFunc(string source, Token tk, string error)
    {
        writeln(source.getErrorText(tk, error));
    }

    // Lexing utils

    bool isValidIdenChar(char c)
    {
        return isAlphaNum(c) || c == '_';
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

    // dead simple lol
    Token lexChar() {
        advance();
        if (advance() != '\'') {
            Token error = mkError();
            errorHandler(source, error, "Character literals can only contain a single character!");
            return error;
        }
        return mkToken(tkChar, start, current);
    }

    Token lexString()
    {
        while (peek != '"' && !eof)
        {
            advance();
        }

        if (eof)
        {
            Token error = mkError();
            errorHandler(source, error, "string unterminated!");
            return error;
        }

        // Read closing "
        advance();
        return mkToken(tkStringLiteral, start, current);
    }

    Token lexNumeric()
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
            return mkToken(tkNumberLiteral);
        }
        // return integer (non-decimal)
        return mkToken(tkIntLiteral);
    }

    Token lexIdentifier()
    {
        while (isValidIdenChar(peek))
            advance();

        string idxText = source[start .. current];
        TokenId token = idxText in keywords ? keywords[idxText] : tkUnknown;
        return mkToken(token == tkUnknown ? tkIdentifier : token);
    }

    /// Skips unwanted characters and updates the position/line buffer
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
            case '/':
                if (skipComments) {
                    // If it isn't a comment, we need to be able to skip back.
                    size_t cur = current;
                    advance();
                    if (match('/'))
                    {
                        // single line comment
                        while (peek() != '\n' && !eof)
                            advance();
                        advance();
                        break;
                    }
                    else if (match('*'))
                    {
                        // multiline line comment
                        char lastPeek;
                        while (!(lastPeek == '*' && peek() == '/') && !eof)
                        {
                            lastPeek = peek();
                            advance();
                        }
                        advance();
                        break;
                    }
                    else if (match('+'))
                    {
                        // multiline line doc comment
                        char lastPeek;
                        while (!(lastPeek == '+' && peek() == '/') && !eof)
                        {
                            lastPeek = peek();
                            advance();
                        }
                        advance();
                        break;
                    }
                    // Wasn't a comment, skip back (division or something like that)
                    current = cur;
                }
                start = current;
                return;
            default:
                start = current;
                return;
            }
        }
    }

public:
    /// Error handler
    TokenizerErrorHandler errorHandler;



    // Lexing

    /// Make "unknown" token
    Token mkToken()
    {
        return mkToken(tkUnknown);
    }

    /// Make empty token
    Token mkEmpty()
    {
        return Token(&source, tkUnknown, start, current, line, pos);
    }

    /// Make error marker token
    Token mkError()
    {
        return Token(&source, tkError, start, current, line, pos);
    }

    /// Make token with id
    Token mkToken(TokenId id)
    {
        return Token(&source, id, start, current, line, pos);
    }

    /// Make token with custom parameters.
    Token mkToken(TokenId id, size_t start, size_t len)
    {
        return Token(&source, id, start, len, line, pos);
    }

    /// Get the source code this lexer is attached to.
    string getSource()
    {
        return source;
    }

    /// Constructs a new lexer.
    this(string source, bool skipComments = true)
    {
        this.source = source;
        this.start = 0;
        this.current = 0;
        this.errorHandler = &internalErrFunc;
        this.skipComments = skipComments;
    }

    /// Gets wether END OF FILE was reached.
    bool eof()
    {
        return current >= source.length;
    }

    /// Gets wether END OF FILE was reached.
    bool leof()
    {
        return current > source.length;
    }

    /// Rewind lexer to token.
    void rewindTo(Token* tk)
    {
        this.start = tk.start;
        this.current = tk.start;
    }

    /// One index of lookahead
    void peekNext(Token* token)
    {
        scanToken(token);
        rewindTo(token);
    }

    /// Scan a token.
    void scanToken(Token* token)
    {
        // skip whitespace, comments, etc.
        skipUnwanted();
        Token strToken = mkEmpty();

        if (eof)
        {
            *token = mkToken(tkEOF);
            return;
        }

        char c = advance();
        switch (c)
        {
        case '(':
            strToken = mkToken(tkOpenParan);
            break;
        case ')':
            strToken = mkToken(tkCloseParan);
            break;
        case '[':
            strToken = mkToken(tkOpenBracket);
            break;
        case ']':
            strToken = mkToken(tkCloseBracket);
            break;
        case '{':
            strToken = mkToken(tkStartScope);
            break;
        case '}':
            strToken = mkToken(tkEndScope);
            break;
        case ',':
            strToken = mkToken(tkListSep);
            break;
        case '.':
            strToken = mkToken(tkDot);
            break;
        case '~':
            strToken = mkToken(tkConcat);
            break;
        case '+':
            if (match('+')) strToken = mkToken(tkInc);
            else strToken = mkToken(match('=') ? tkAddAssign : tkAdd);
            break;
        case '-':
        if (match('-')) strToken = mkToken(tkDec);
            else strToken = mkToken(match('=') ? tkSubAssign : tkSub);
            break;
        case '*':
            strToken = mkToken(match('=') ? tkMulAssign : tkMul);
            break;
        case '%':
            strToken = mkToken(match('=') ? tkModAssign : tkMod);
            break;
        case '^':
            strToken = mkToken(match('=') ? tkPowAssign : tkPow);
            break;
        case ';':
            strToken = mkToken(tkEndStatement);
            break;
        case ':':
            strToken = mkToken(tkColon);
            break;
        case '!':
            strToken = mkToken(match('=') ? tkNotEqual : tkNot);
            break;
        case '=':
            strToken = mkToken(match('=') ? tkEqual : tkAssign);
            break;
        case '<':
            strToken = mkToken(match('=') ? tkLessThanOrEq : tkLessThan);
            break;
        case '>':
            strToken = mkToken(match('=') ? tkGreaterThanOrEq : tkGreaterThan);
            break;
        case '/':
            if (match('/'))
            {
                // single line comment
                while (peek() != '\n' && !eof)
                    advance();
                strToken = mkToken(tkCommentSingle);
                break;
            } else if (match('*')) {
                // multiline line comment
                char lastPeek;
                while (!(lastPeek == '*' && peek() == '/') && !eof)
                {
                    lastPeek = peek();
                    advance();
                }
                advance();
                strToken = mkToken(tkCommentMulti);
                break;
            } else if (match('+')) {
                // multiline line doc comment
                char lastPeek;
                while (!(lastPeek == '+' && peek() == '/') && !eof)
                {
                    lastPeek = peek();
                    advance();
                }
                advance();
                strToken = mkToken(tkCommentDoc);
                break;
            }
            strToken = mkToken(match('=') ? tkDivAssign : tkDiv);
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
