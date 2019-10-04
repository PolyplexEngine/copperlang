module cujit.cubuild;
import cujit.llb;
import cujit.builder;
import cucore.node;
import dllvm;
import std.format;

/**
    An exception for when visibility rules are broken
*/
class VisibilityException : Exception {
    this(string type, string name, CuModule* origin, string fetcher) {
        super("%s %s (from %s) is not accessible from %s".format(type, name, origin.name, fetcher));
    }
}

/**
    The visibility of a value or function in a module
*/
enum Visibility {
    /// Visible to everything
    Global,

    /// Only visible to self or module scope
    Local
}

/**
    A copper module
*/
struct CuModule {
private:
    Node* node;
    Module module_;
    string moduleName;
    string[] refs;

    CuFunction*[] globalFuncs;

public:
    /**
        Constructs a new module
    */
    this(string moduleName, Node* node, Context ctx) {
        module_ = new Module(moduleName, ctx);
        this.moduleName = moduleName;
        this.node = node;
    }

    /**
        Gets a list of the modules imported by this module
    */
    @property
    string[] imports() {
        return refs;
    }

    /**
        Gets the name of this module
    */
    @property
    string name() {
        return moduleName;
    }

    /**
        The list of global functions
    */
    @property
    CuFunction*[] globalFunctions() {
        return globalFuncs;
    }

    /**
        Gets the underlying LLVM module
    */
    @property
    ref Module llvmModule() {
        return module_;
    }

    /**
        Gets the LLVM IR
    */
    @property
    string llvmIR() {
        return module_.toString();
    }

    /**
        Adds an import to the import list
    */
    void addImport(string name) {
        refs ~= name;
    }

    /**
        Add a new function to the module and return it
    */
    CuFunction* addFunction(Node* discoveredNode, Visibility visibility, FuncKind kind, string name, bool extension = false) {
        CuFunction* newFunc = new CuFunction(&this, discoveredNode, visibility, kind, name, extension);
        globalFuncs ~= newFunc;
        return newFunc;
    }
}

/**
    A copper definition
*/
struct CuVarDef {
    /**
        Constructs a named variable definition
    */
    this(string name, string typeName, Type llvmType) {
        this.name = name;
        this.typeName = typeName;
        this.llvmType = llvmType;
        this.index = 0;
    }

    /**
        Constructs an indexed variable definition
    */
    this(uint index, string name, string typeName, Type llvmType) {
        this.index = index;
        this.name = name;
        this.typeName = typeName;
        this.llvmType = llvmType;
    }

    /**
        The name of the definition
    */
    string name;

    /**
        The index of the definition (in the case of a parameter)
    */
    uint index;

    /**
        The (copper) name of a type
    */
    string typeName;

    /**
        The llvm type
    */
    Type llvmType;
}

/**
    The function kind
*/
enum FuncKind {
    /// A function in global scope
    Global,

    /// A function in the scope of a struct
    Struct,

    /// A function in the scope of a class
    Class
}

/**
    A copper function
*/
struct CuFunction {
private:
    Node* funcNode;
    Node* funcBodyNode;

    CuModule* parentModule;
    Visibility visiblityMode;
    string funcName = "UNCOMPILED";
    string unmangled = "";
    bool isExtension;

    FuncType funcType;
    Function llvmFunction;
    
    FuncKind funcKind;
    // A function can only be a member of a struct or a class therefore we put them in a union
    union {
        CuStruct* parentStruct;
        CuClass* parentClass;
    }

    uint[string] paramMapping;

    BasicBlock[string] sections;

    struct VarDef {
        Type type;
        Value value;
    }

    VarDef[string] variables;

public:
    /**
        Construct a Copper function
    */
    this(CuModule* parentModule, Node* node, Visibility visiblityMode, FuncKind kind, string name, bool extension = false) {
        this.parentModule = parentModule;
        this.funcKind = kind;
        this.isExtension = extension;
        this.visiblityMode = visiblityMode;
        this.funcNode = node;
        this.funcName = name;
        this.unmangled = name;
    }

    /**
        Assign the parent struct instance
    */
    void assignParent(CuStruct* struct_) {
        this.parentStruct = struct_;
    }

    /**
        Assign the parent class instance
    */
    void assignParent(CuClass* class_) {
        this.parentClass = class_;
    }

    void assignBody(Node* body) {
        funcBodyNode = body;
    }

    /**
        Finish this function definition by submitting its LLVM function type and its function object
    */
    void finish(FuncType type, Function llvmFunction) {
        this.funcType = type;
        this.llvmFunction = llvmFunction;

        this.funcName = llvmFunction.Name;
    }

    /**
        Gets the AST node of this function
    */
    @property
    Node* astNode() {
        return funcNode;
    }

    /**
        Gets the AST node of this function
    */
    @property
    Node* bodyAstNode() {
        return funcBodyNode;
    }

    /**
        Gets the name of this function
    */
    @property
    string name() {
        return funcName;
    }

    /**
        The LLVM function instance
    */
    @property
    Function llvmFunc() {
        return llvmFunction;
    }

    /**
        The LLVM function type
    */
    @property
    FuncType llvmType() {
        return funcType;
    }

    /**
        The LLVM module
    */
    @property
    Module llvmModule() {
        return parentModule.llvmModule;
    }

    /**
        Gets the function kind
    */
    @property
    FuncKind kind() {
        return funcKind;
    }

    /**
        Gets the function's visibility

        If in global scope; the visibility affects the access from other modules
    */
    @property
    Visibility visibility() {
        return visiblityMode;
    }

    /**
        Mapping between parameter and LLVM index
    */
    @property
    uint[string] params() {
        return paramMapping;
    }

    /**
        Finds the value with the specified name
    */
    Value findValue(string name, Builder builder) {
        // TODO: non-global non-function values
        if (name in params) {
            return llvmFunc.GetParam(params[name]);
        }

        if (name in variables) {
            return builder.BuildLoad(variables[name].value, name);
        }

        return null;
    }

    Function findFunction(string name, Value[] args) {
        foreach(CuFunction* func; parentModule.globalFunctions) {
            if (func.unmangled == name && func.params.length == args.length) {
                return func.llvmFunc;
            }
        }
        return null;
    }

    /**
        Returns the mangled name
    */
    string mangleFunc(string[] argTypes, Type parent = null, bool isClass = false) {
        return mangleName(funcName, argTypes, parent, isClass);
    }

    /**
        Add parameter to the mapping
    */
    void addParam(string name) {
        paramMapping[name] = cast(uint)paramMapping.length;
    }

    /**
        Add a section (basic block) to the function
    */
    void addSection(string name, BasicBlock block) {
        sections[name] = block;
    }

    /**
        Declare a variable
    */
    void declareVariable(Type type, string name, Value llvmValue) {
        variables[name] = VarDef(type, llvmValue);
    }

    /**
        Finds a variable (specifically)
    */
    Value findVariable(string name, Builder builder) {

        if (name in variables) {
            return builder.BuildLoad(variables[name].value, name);
        }
        
        throw new Exception("No such variable in scope");
    }
    
    Value findVariableAddr(string name) {

        if (name in variables) {
            return variables[name].value;
        }
        
        throw new Exception("No such variable in scope");
    }

    Type findVariableType(string name) {

        if (name in variables) {
            return variables[name].type;
        }
        
        throw new Exception("No such variable in scope");
    }

    BasicBlock getSection(string name) {
        return sections[name];
    }

    /**
        Enforce visibility rules, throws exception if rules are broken
    */
    void enforceVisibility(CuFunction* other) {
        if (visiblityMode == Visibility.Local) {
            if (other.parentModule != parentModule)
                throw new VisibilityException("function", llvmFunction.Name, parentModule, other.parentModule.name);

            // TODO: make declarations from the same module implicit friends?

            switch (kind) {
                case FuncKind.Class:
                    // If they are not the same kind they are definately not from the same type.
                    // Therefore we check that before checking if they are from the same class
                    if (other.kind != FuncKind.Class || this.parentClass != other.parentClass)
                        throw new VisibilityException("function", llvmFunction.Name, parentModule, other.name);
                    break;

                case FuncKind.Struct:
                    // If they are not the same kind they are definately not from the same type.
                    // Therefore we check that before checking if they are from the same struct
                    if (other.kind != FuncKind.Struct || this.parentStruct != other.parentStruct)
                        throw new VisibilityException("function", llvmFunction.Name, parentModule, other.name);
                    break;

                default: break;
            }
        }
    }
}

struct CuStruct {

}

struct CuClass {

}