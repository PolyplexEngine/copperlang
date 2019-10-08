import std.stdio;
import cujit;
import cucore;
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
    catch (CompilationException ex)
    {
        writeln(ex.msg);
		return;
    }
    engine.printAllIR();
    writeln(engine.call!string("main(void)"));
}
