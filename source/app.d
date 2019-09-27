import std.stdio;
import culexer;
import cuparser;
import cucore.node;
import std.file;
import cuvm;
import cuvm.pool;

void main(string[] args)
{
	Parser* parser = new Parser(readText("tests/test.cu"));
	Node* node = parser.parse();
	writeln(node.toString);

	Chunk chunk;
	chunk.write(opCONST);
	chunk.write(chunk.pool.add(CuValue(int(42))));

	chunk.write(opNEGATE);
	chunk.write(opPRINT);

	chunk.write(opCONST);
	chunk.write(chunk.pool.add(CuValue(16)));

	chunk.write(opCONST);
	chunk.write(chunk.pool.add(CuValue(2)));

	chunk.write(opMUL);
	chunk.write(opPRINT);

	chunk.write(opCONST);
	chunk.write(chunk.pool.add(CuValue("Hello, ")));

	chunk.write(opCONST);
	chunk.write(chunk.pool.add(CuValue("world!")));
	
	chunk.write(opAPPEND);
	chunk.write(opPRINT);

	chunk.write(opRETURN);

	chunk.dissasemble();

	VM vm;
	writeln("EXEC_RESULT=", vm.execute(&chunk));
}
