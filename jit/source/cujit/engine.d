module cujit.engine;
import cujit.builder;
import cujit.cubuild;
import dllvm;

/**
    The JIT engine
*/
class JITEngine {
package(cujit):
    ExecutionEngine engine;
    IModuleProvider provider;
    CuBuilder builder;

    CuModule*[] modules;

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
        CuModule* mod = builder.build(readText(moduleFile));
        modules ~= mod;
        engine.AddModule(mod.llvmModule);
        writeln("Compiled IR\n", mod.llvmIR());
    }

    void compileScript(string script) {
        builder.build(script);
    }

    T getFunction(T)(string name) {
        return engine.GetFunctionAddr!T(name);
    }

    void recompile() {
        foreach(mod; modules) {
            engine.Recompile(mod.llvmModule);
        }
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