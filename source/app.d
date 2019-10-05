import std.stdio;
import culexer;
import cuparser;
import cucore.node;
import cujit;
import dllvm;
import std.file;

void main(string[] args)
{
	initJIT();
	JITEngine engine = new JITEngine();
	engine.compileScriptFile(args[1]);
	engine.printAllIR();

	//writeln(engine.call!(int)(args[2], 5));
}
