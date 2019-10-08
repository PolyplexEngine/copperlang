import std.stdio;
import cujit;
import std.file;
import std.conv;

void main(string[] args)
{
	initJIT();
	JITEngine engine = new JITEngine();
	engine.compileScriptFile(args[1]);
	engine.printAllIR();
	writeln(engine.call!string("main(void)"));
}
