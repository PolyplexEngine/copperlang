module cuparser.compilationException;
import cucore.token;
import cucore.strutils;

class CompilationException : Exception
{
    public Token* token;
    public string source;
    public string errMsg;
    this(string source, Token* tk, string msg, string file = __FILE__, size_t line = __LINE__)
    {
        super(getOutText(source, *tk, msg), file, line);
        this.token = tk;
        this.source = source;
        this.errMsg = msg;
    }
}
