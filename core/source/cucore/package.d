module cucore;
public import cucore.list;
public import cucore.strutils;
import cucore.token;
import cucore.node;

/**
    A copper exception that happened during compilation
*/
class CompilationException : Exception
{
    /**
        The token of the exception occurance
    */
    public Token* token;

    /**
        The source code
    */
    public string source;

    /**
        The error message.
    */
    public string errMsg;

    /**
        Constructs new exception
    */
    this(string source, Token* tk, string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(getOutText(source, *tk, msg), file, line);
        this.token = tk;
        this.source = source;
        this.errMsg = msg;
    }

    /**
        Constructs new exception
    */
    this(Node* n, string msg, string file = __FILE__, size_t line = __LINE__)
    {
        this(n.token.source, &n.token, msg, file, line);
    }
}