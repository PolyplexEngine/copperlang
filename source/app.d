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

void testTComp() {
	writeln("\n===================== tests/test.cu =====================");
	try {
		lex("tests/test.cu");
		auto parser = new Parser(readText("tests/test.cu"));
		Node* n = parser.parse();
		if (n !is null) writeln(n.toString());
	} catch(Exception ex) {
		writeln("[ERROR]:\n", ex.msg.offsetByLines(8));
	}
	writeln("\n===================== bytecode =====================");
	Chunk* tchunk = new Chunk(0, []);
	tchunk.writePushConst(24);
	tchunk.writePushConst(1337);
	tchunk.writePushConst(1_000_000);
	tchunk.writePushConst(24);
	tchunk.writePushConst(24);
	tchunk.writePushConst(24);
	tchunk.writePushConst(24);
	tchunk.write(opRET);

	VM vm;
	writeln(vm.interpret(tchunk));
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