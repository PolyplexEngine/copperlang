module copper.lang.compiler.jit.compiler;
import llvm;
import std.stdio;

/**
    Copperlang JIT compiler utilizing LLVM
*/
class JITCompiler {
private:
    LLVMContextRef llvmContext;

public:

}

struct JITModule {
private:
    LLVMModuleRef llvmModule;

public:
    this(string moduleName) {
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