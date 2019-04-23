import std.stdio;
import copper.lang.vm;
import std.file;
import std.conv;
import copper.lang;
import copper.share.utils.strutils;
import copper.lang.compiler;
import std.process;
import copper.lang.arch;


void main(string[] args)
{
	if (args.length > 1) {
		if (args[1] == "--test-all") {
			writeln("\n============ LEXER ============");
			testLexer();

			writeln("\n============ FULL COMPILATION ============");
			testFullComp();

			writeln("\n============ SINGLE TEST ============");
			testTComp();
		}
		if (args[1] == "--test-single") {
			testTComp();
		}
		return;
	}
	testTComp();
	return;
}


void testLexer() {
	size_t failed = 0;
	mainloop: foreach(DirEntry file; dirEntries("tests/lexer", SpanMode.depth)) {
	try {
		failed += lex(file.name) ? 0 : 1;
	} catch(Exception ex) {
		failed++;
		writeln("FAILED! ", ex.msg);
	}
		
	}
	writeln("=================================\nDone! ", failed, " lexer tests failed!");
}

bool lex(string fileName) {
	writeln("\n===================== ", fileName, " =====================");
	Lexer lx = Lexer(readText(fileName));
	Token tk;
	string ot = "";
	while (!lx.eof) {
		lx.scanToken(&tk);
		if (tk.id == tkError) {
			return false;
		}
		ot ~= "(" ~ tk.toString ~ ") ";
	}
	writeln(ot);
	return true;
}

void testCompilation() {
	writeln("\n===================== tests/test.cu =====================");
	auto parser = new Parser(readText("tests/test.cu"));

	/*CopperCompiler compiler = new CopperCompiler();
	Node* n = parser.parse();
	if (n !is null) { 
		writeln(n.toString());
		CObject* obj = compiler.compile(n);
		if (obj !is null) {
			State* state = new State(obj);
			//writeln("BYTECODE= ", obj.chunk.toString);
			writeln("Returned value ", state.call("timesTwo.int.int.int.int", 4, 3, 2));
		}
	}*/
}

void testTComp() {
	try {
		//testCompilation();
	} catch(Exception ex) {
		writeln(ex.msg);
	}

	writeln("\n===================== bytecode =====================");
	
	/*import copper.lang.casm.assembler;
	Assembler assembler = new Assembler();
	CObject* object = assembler.assemble(readText("tests/test.casm"));
	State* state = new State(object);
	writeln("BYTECODE= ", object.chunk.toString);
	writeln("BinRet: ", state.call("factorial"), "...");*/
}

void testFullComp() {
	foreach(DirEntry file; dirEntries("tests/fullcomp", SpanMode.depth)) {
		writeln("\n===================== ", file.name, " =====================");
		try {
			auto parser = new Parser(readText(file.name));
			Node* n = parser.parse();
			if (n !is null) writeln(n.toString());
		} catch(Exception ex) {
			writeln("FAILED!\n", ex.msg);
		}
	}
}