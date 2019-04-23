import std.stdio;
import culexer;
import cuparser;
import cucore.node;
import std.file;

void main(string[] args)
{
	Parser* parser = new Parser(readText("tests/test.cu"));
	Node* node = parser.parse();
	writeln(node.toString);
}
