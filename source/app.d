import std.stdio;
import cujit;
import cucore;
import std.file;
import std.conv;

int main(string[] args)
{
    initJIT();
    JITEngine engine = new JITEngine();
    scope(exit) destroy(engine);
    try
    {
        engine.compileScriptFile(args[1]);
        engine.printAllIR();
    }
    catch (CompilationException ex)
    {
        writeln(ex.msg);
		return -1;
    }
    //debug engine.printAllIR();
    return engine.call!int("main(string[])", args);
}
