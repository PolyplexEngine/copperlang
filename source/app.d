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
	engine.compileScriptFile("tests/test.cu");

	alias factorialPtr = int function(float, float);
	factorialPtr speedCalc = engine.getFunction!factorialPtr("speedCalc(float, float)");
	writeln(speedCalc(10f, 0.6f));
}
