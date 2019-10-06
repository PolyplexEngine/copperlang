import std.stdio;
import culexer;
import cuparser;
import cucore.node;
import cujit;
import dllvm;
import std.file;
import std.conv;

void main(string[] args)
{
	initJIT();
	JITEngine engine = new JITEngine();
	engine.compileScriptFile(args[1]);
	writeln(engine.call!string("main(void)"));
}
