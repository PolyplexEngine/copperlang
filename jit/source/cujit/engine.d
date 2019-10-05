module cujit.engine;
import cujit.builder;
import cujit.cubuild;
import dllvm;
import std.stdio;

/**
    The JIT engine
*/
class JITEngine {
package(cujit):
    ExecutionEngine engine;
    IModuleProvider provider;
    CuBuilder builder;

    CuModule[] modules;

public:
    /**
        Initialize the JIT engine
    */
    this(string basepath = "src/") {
        engine = new ExecutionEngine();
        builder = new CuBuilder(this);

        provider = new FileModuleProvider();
        provider.setRoot(basepath);

    }

    IModuleProvider getProvider() {
        return provider;
    }

    void compileScriptFile(string moduleFile) {
        import std.file : readText;
        import std.stdio : writeln;
        CuModule mod = builder.build(readText(moduleFile));
        modules ~= mod;
        engine.AddModule(mod.llvmMod);
        //writeln("Compiled IR\n", mod.llvmIR());
    }

    /**
        Prints the IR of all the current bound modules
    */
    void printAllIR() {
        foreach(module_; modules) {
            writeln(module_.getIR);
        }
    }

    /**
        Compiles a copper script
    */
    void compileScript(string script) {
        builder.build(script);
    }

    /**
        Gets a function by its function prototype
    */
    T getFunctionByProto(T)(string name) {
        auto fnc = engine.GetFunctionAddr!T(name);
        if (fnc is null) throw new Exception("Could not find function "~name);
        return fnc;
    }

    /**
        Gets a function by return type and argument types
    */
    auto getFunction(retType = void, args...)(string proto) {
        alias retT = retType function(args);
        return getFunctionByProto!retT(proto);
    }

    /**
        Calls a function with the specified prototype with the specified arguments
    */
    retType call(retType = void, Args...)(string proto, Args args) {
        auto fnc = (getFunction!(retType, Args)(proto));
        return fnc(args);
    }



    /**
        Recompiles all modules
        This will make any existing function pointer invalid!
    */
    void recompile() {
        engine.RecompileAll();
    }
}


/**
    Module providers allow JITEngines to recieve Copper files via other means.
*/
interface IModuleProvider {
    void setRoot(string rootPath);
    string getRoot();
    string getModule(string moduleId);
}

/**
    The default provider, reads modules from a src/ directory
*/
class FileModuleProvider : IModuleProvider {
private:
    string rootDir = "src/";

public:
    void setRoot(string rootPath) {
        rootDir = rootPath;
    }

    string getRoot() {
        return rootDir;
    }

    string getModule(string moduleId) {
        import std.path : buildPath, setExtension;
        import std.array : replace;
        import std.file : readText;
        return readText(buildPath(rootDir, moduleId.replace(".", "/")).setExtension(".cu"));
    }
}