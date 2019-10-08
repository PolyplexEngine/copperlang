import std.stdio;
import culexer;
import cuparser;
import cuparser.compilationException;
import cucore.node;
import cujit;
import dllvm;
import std.file;
import std.conv;

void main(string[] args)
{
    initJIT();
    JITEngine engine = new JITEngine();
    try
    {
        engine.compileScriptFile(args[1]);
    }
    catch (CompilationException e)
    {
        writeln("there was an error on line:"~e.token.line.text);
    }
    engine.printAllIR();
    writeln(engine.call!string("main(void)"));
}
