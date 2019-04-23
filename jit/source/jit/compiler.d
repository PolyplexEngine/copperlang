module copper.lang.compiler.jit.compiler;
import copper.lang.parser.node;
import copper.lang.compiler;
import copper.share.utils;
import copper.lang.parser;
import copper.lang.token;
import std.stdio;
import llvm;

/**
    Copperlang JIT compiler utilizing LLVM
*/
class LLVMCompiler : Compiler {
private:
    DynamicStack!(Scope*) scopes;
    TypeRegistry types;
    LLVMContextRef llvmContext;

    JITModule mod;

    void module_(Node* node)
    {
        mod = JITModule(getModuleName(node.firstChild));
        writeln(mod.moduleName);
        moduleBody(node.right);
    }

    void moduleBody(Node* node)
    {
        if (node.id == astFunction)
        {
            functionDeclaration(node);
        }

        if (node.right !is null)
            moduleBody(node.right);
    }

    void functionDeclaration(Node* node)
    {
        FuncDecl funcDecl;
        funcDecl.name = node.token.lexeme;

        Scope* scope_ = new Scope();

        // Get the parameter list root
        Node* paramListRoot = node.firstChild;

        // Get the return type
        Node* returnType = paramListRoot.right.id == astReturnType ? paramListRoot.right : null;
        funcDecl.returnType = returnType !is null ? returnType.token.lexeme : "void";

        LLVMFunctionType

    }

    void functionBody(Node* node)
    {
        scopeBody(node.firstChild);
    }
    
    void scopeBody(Node* node)
    {
    }

    void return_(Node* node)
    {
    }

    void branch(Node* node)
    {

    }

public:
    override void compile(Node* node) {
        scopes = DynamicStack!(Scope*)([]);
        types = new TypeRegistry();

        module_(node.firstChild);
    }
}

struct JITModule {
private:
    LLVMModuleRef llvmModule;

public:
    string moduleName;
    this(string moduleName) {
        this.moduleName = moduleName;
        import std.string : toStringz;
        LLVMModuleCreateWithName(toStringz(moduleName));
    }
}

shared static this() {
    writeln("Attempting to bind to LLVM...");
    LLVM.load("libLLVM-7.0.1.so");
    if (!LLVM.loaded) {
        stderr.writeln("Failed to bind to LLVM! Try installing LLVM or using the built-in VM (which has slower performance)");
    } else {
        writeln("LLVM was bound to successfully!");
    }
}