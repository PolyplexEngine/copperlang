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
        engine.printAllIR();
    }
    catch (CompilationException ex)
    {
        writeln(ex.msg);
		return;
    }
    //debug engine.printAllIR();
    engine.call!void("main(string[])", args);
}
