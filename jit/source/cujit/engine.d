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
    IModuleProvider modprovider;
    CuBuilder builder;

    CuModule[] modules;

public:
    /**
        Initialize the JIT engine
    */
    this(string basepath = "src/") {
        engine = new ExecutionEngine();
        builder = new CuBuilder(this);

        modprovider = new FileModuleProvider();
        modprovider.setRoot(basepath);

    }

    ~this() {
        destroy(builder);
        destroy(engine);
    }

    @property
    IModuleProvider provider() {
        return modprovider;
    }

    void provider(IModuleProvider provider) {
        this.modprovider = provider;
    }

    void compileScriptFile(string moduleFile) {
        import std.file : readText;
        import std.stdio : writeln;
        CuModule mod = builder.build(readText(moduleFile));
        modules ~= mod;
        engine.AddModule(mod.llvmMod);
    }

    /**
        Prints the IR of all the current bound modules
    */
    void printAllIR() {
        foreach(module_; modules) {
            writeln(module_.getIR);
        }
    }

    string[] listAllFunctions() {
        import std.format : format;
        string[] funcList;

        foreach(mod; modules) {
            foreach(value; mod.declarations) {
                if (value.type.typeKind != CuTypeKind.function_) continue;

                CuFunction func = cast(CuFunction)value;
                if (func.isExternal) {
                    funcList ~= "%s (external C)".format(func.name);
                } else {
                    funcList ~= "%s (copper native)".format(func.mangledName);
                }
            }
        }
        return funcList;
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