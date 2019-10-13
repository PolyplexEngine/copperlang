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
    this(string type, string name, CuModule origin, string fetcher) {
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
    The kind of type
*/
enum CuTypeKind : string {

    /// Boolean - Int8
    bool_ = "bool",

    /// Unsigned byte - Int8
    ubyte_ = "ubyte",

    /// Unsigned short - Int16
    ushort_ = "ushort",

    /// Unsigned int - Int32
    uint_ = "uint",

    /// Unsigned long - Int64
    ulong_ = "ulong",

    /// Signed byte - Int8
    byte_ = "byte",

    /// Signed short - Int16
    short_ = "short",

    /// Signed int - Int32
    int_ = "int",

    /// Signed long - Int64
    long_ = "long",

    /// Float - Float32
    float_ = "float",

    /// Double - Float64
    double_ = "double",

    /// Char - Int32
    char_ = "char",

    /// String - Int32[]
    string_ = "string",

    /// Ptr - VoidPtr
    ptr_ = "ptr",

    /// Void type
    void_ = "void",

    /// T[(size)] - Array
    static_array = "static_array",

    /// T[] - VoidPtr + size_t
    dynamic_array = "dynamic_array",

    /// function
    function_ = "func",

    /// class
    class_ = "class",

    /// struct
    struct_ = "struct",

    /**
        32 bit: Int32
        64 bit: Int64
    */
    size_t_ = "size_t"
}

/**
    Extracts the low level LLVM types from the high level copper types
*/
Type[] extractTypes(CuType[] types) {
    Type[] otypes;
    foreach(type; types) {
        otypes ~= type.llvmType;
    }
    return otypes;
}

/**
    A copper type

    This is a high level wrapper over LLVM's type system
*/
class CuType {
private:

    this() { }

    this(CuTypeKind kind, Type type) {
        this.typeKind = kind;
        this.typeName = cast(string)kind;
        this.llvmType = type;
    }

public:
    /**
        The kind of type this type is
    */
    CuTypeKind typeKind;

    /**
        The (human readable) name of the type
    */
    string typeName;

    /**
        The underlying LLVM type
    */
    Type llvmType;

    /**
        The declaration for the type (if any)
    */
    CuDecl declaration;

    /**
        Gets wether the type is an integral type.
    */
    @property
    bool isIntegral() {
        switch(typeKind) {
            case CuTypeKind.byte_, CuTypeKind.ubyte_,
                CuTypeKind.short_, CuTypeKind.ushort_,
                CuTypeKind.int_, CuTypeKind.uint_,
                CuTypeKind.long_, CuTypeKind.ulong_,
                CuTypeKind.size_t_,
                CuTypeKind.bool_,
                CuTypeKind.char_:
                    return true;
            default:
                return false;
        }
    }

    /**
        Gets the size of the type in bytes
    */
    @property
    size_t sizeOf() {
        switch(typeKind) {
            
            case CuTypeKind.byte_, CuTypeKind.ubyte_, CuTypeKind.char_, CuTypeKind.bool_:
                return 1;
            
            case CuTypeKind.short_, CuTypeKind.ushort_:
                return 2;
            
            case CuTypeKind.int_, CuTypeKind.uint_, CuTypeKind.float_:
                return 4;
            
            case CuTypeKind.long_, CuTypeKind.ulong_, CuTypeKind.double_:
                return 8;

            case CuTypeKind.size_t_, CuTypeKind.ptr_, CuTypeKind.function_:
                return size_t.sizeof;
            
            // For other (aggregate types) sizeOf should be implemented locally
            default: return 0;
        }
    }

    /**
        Gets wether the type is a numeric type
    */
    bool isFloating() {
        return (typeKind == CuTypeKind.float_ || typeKind == CuTypeKind.double_);
    }

    /**
        Gets wether the type is a numeric type
    */
    bool isNumeric() {
        return isIntegral || isFloating;
    }

    /**
        Gets wether the integer type is signed
    */
    bool isSigned() {
        return (typeKind == CuTypeKind.byte_ || typeKind == CuTypeKind.short_ || typeKind == CuTypeKind.int_ || typeKind == CuTypeKind.long_);
    }

    /**
        Returns wether the type is (implicitly) compatible with an other type

        Implicitly compatible types can be converted between without an explicit 'as' operator
    */
    bool isImplicitCompatibleWith(CuType other) {
        return (this.typeKind == other.typeKind) || (isIntegral && other.isIntegral) || (isFloating && other.isFloating);
    }

    /**
        Returns wether the type is smaller than an other type

        If so, it means the type requires an implict downcast to be compatible.
    */
    bool isSmallerThan(CuType other) {
        return this.sizeOf < other.sizeOf;
    }
}

/**
    A copper pointer type
*/
class CuPointerType : CuType {
public:
    /**
        The type of data the pointer points to
    */
    CuType elementType;

    /**
        Creates a new pointer
    */
    this(CuType elementType, CuTypeKind kind = CuTypeKind.ptr_) {
        this.typeKind = kind;
        this.typeName = cast(string)kind;
        this.elementType = elementType;
        this.llvmType = Context.Global.CreatePointer(elementType.llvmType);
    }
}

/**
    A copper array type
*/
class CuArrayType : CuType {
public:
    /**
        The type of the elements in the array
    */
    CuType elementType;

    /**
        The length of the array
    */
    size_t length;

    /**
        Creates a new pointer
    */
    this(CuType elementType, size_t length) {
        this.typeKind = CuTypeKind.static_array;
        this.typeName = cast(string)CuTypeKind.static_array;
        this.elementType = elementType;
        this.length = length;
        this.llvmType = Context.Global.CreateArray(elementType.llvmType, cast(uint)length);
    }
}

/**
    A dynamic array
*/
class CuDynamicArrayType : CuType {
private:
    this() { }

public:
    /**
        The array pointer to element 0 type
    */
    CuPointerType pointer;
    
    /**
        The array length type (size_t)
    */
    CuType length;

    this(CuType elementType) {
        this.typeKind = CuTypeKind.dynamic_array;
        this.typeName = cast(string)CuTypeKind.dynamic_array;
        this.pointer = createPointer(elementType);
        this.length = createSizeT();
        this.llvmType = Context.Global.CreateStruct([length.llvmType, pointer.llvmType], false);
    }
}

/**
    A string
*/
class CuStringType : CuDynamicArrayType {
public:
    this() {
        this.typeKind = CuTypeKind.string_;
        this.typeName = cast(string)CuTypeKind.string_;
        this.pointer = createPointer(createChar());
        this.length = createSizeT();
        this.llvmType = Context.Global.CreateStruct([length.llvmType, pointer.llvmType], false);
    }
}

/**
    A copper function type
*/
class CuFuncType : CuType {
public:

    /**
        The return type of the function
    */
    CuType returnType;

    /**
        The types of the arguments of the function
    */
    CuType[] argumentTypes;

    /**
        Creates a new function type
    */
    this(CuType returnType, CuType[] argumentTypes) {
        this.typeKind = CuTypeKind.function_;
        this.typeName = cast(string)CuTypeKind.function_;
        this.returnType = returnType;
        this.argumentTypes = argumentTypes;
        this.llvmType = Context.Global.CreateFunction(returnType.llvmType, argumentTypes.extractTypes, false);
    }
}

/**
    A copper struct type
*/
class CuStructType : CuType {
public:

    /**
        The types of the struct's members
    */
    CuType[] memberTypes;

    /**
        Wether the struct's data is packed
    */
    bool isPacked;

    /**
        The specified name
    */
    string name;

    /**
        Creates a new function type
    */
    this(string name, CuType[] members, bool isPacked = false) {
        this.typeKind = CuTypeKind.struct_;
        this.typeName = cast(string)CuTypeKind.struct_;
        this.isPacked = isPacked;
        this.name = name;
        this.memberTypes = members;

        // Convert data to LLVM suitable data
        Type[] llvmTypes = new Type[members.length];
        foreach(i, member; members) {
            llvmTypes[i] = member.llvmType;
        }

        this.llvmType = Context.Global.CreateStruct(name, llvmTypes, isPacked);
    }

    /**
        Creates a new function type
    */
    this(CuType[] members, bool isPacked = false) {
        this.typeKind = CuTypeKind.struct_;
        this.typeName = cast(string)CuTypeKind.struct_;
        this.isPacked = isPacked;
        this.name = name;
        this.memberTypes = members;

        // Convert data to LLVM suitable data
        Type[] llvmTypes = new Type[members.length];
        foreach(i, member; members) {
            llvmTypes[i] = member.llvmType;
        }

        this.llvmType = Context.Global.CreateStruct(llvmTypes, isPacked);
    }
}

/**
    A copper class type
*/
class CuClassType : CuType {

}

/**
    Creates a basic type from a type name
*/
CuType createTypeFromName(CuState state, string type) {
    switch (type) {
        case "bool":    return createBool();
        case "ubyte":   return createUByte();
        case "ushort":  return createUShort();
        case "uint":    return createUInt();
        case "ulong":   return createULong();
        case "size_t":  return createSizeT();
        case "byte":    return createByte();
        case "short":   return createShort();
        case "int":     return createInt();
        case "long":    return createLong();
        case "float":   return createFloat();
        case "double":  return createDouble();
        case "string":  return createString();
        case "void":    return createVoid();
        default: return state.findType(type);
    }
}

/**
    void
*/
CuType createVoid() {
    return new CuType(CuTypeKind.void_, Context.Global.CreateVoid());
}

/**
    Creates a boolean type
*/
CuType createBool() {
    return new CuType(CuTypeKind.bool_, Context.Global.CreateByte);
}

/**
    Creates a ubyte type
*/
CuType createUByte() {
    return new CuType(CuTypeKind.ubyte_, Context.Global.CreateByte);
}

/**
    Creates a ushort type
*/
CuType createUShort() {
    return new CuType(CuTypeKind.ushort_, Context.Global.CreateInt16);
}

/**
    Creates a uint type
*/
CuType createUInt() {
    return new CuType(CuTypeKind.uint_, Context.Global.CreateInt32);
}

/**
    Creates a ulong type
*/
CuType createULong() {
    return new CuType(CuTypeKind.ulong_, Context.Global.CreateInt64);
}

/**
    Creates a byte type
*/
CuType createByte() {
    return new CuType(CuTypeKind.byte_, Context.Global.CreateByte);
}

/**
    Creates a short type
*/
CuType createShort() {
    return new CuType(CuTypeKind.short_, Context.Global.CreateInt16);
}

/**
    Creates a int type
*/
CuType createInt() {
    return new CuType(CuTypeKind.int_, Context.Global.CreateInt32);
}

/**
    Creates a long type
*/
CuType createLong() {
    return new CuType(CuTypeKind.long_, Context.Global.CreateInt64);
}

/**
    Creates a size_t type
*/
CuType createSizeT() {
    version(D_LP64) return new CuType(CuTypeKind.size_t_, Context.Global.CreateInt64);
    else return new CuType(CuTypeKind.size_t_, Context.Global.CreateInt32);
}

/**
    Creates a 32 bit floating point type
*/
CuType createFloat() {
    return new CuType(CuTypeKind.float_, Context.Global.CreateFloat32);
}

/**
    Creates a 64 bit floating point type
*/
CuType createDouble() {
    return new CuType(CuTypeKind.double_, Context.Global.CreateFloat64);
}

/**
    Creates a pointer pointing to the specified type
*/
CuPointerType createPointer(CuType to) {
    return new CuPointerType(to);
}

/**
    Creates a new static array type
*/
CuArrayType createStaticArray(CuType elements, size_t length) {
    return new CuArrayType(elements, length);
}

/**
    Creates a new dynamic array type
*/
CuDynamicArrayType createDynamicArray(CuType elements) {
    return new CuDynamicArrayType(elements);
}

/**
    Creates a new string type (dynamic array of UTF-8 chars)
*/
CuStringType createString() {
    return new CuStringType();
}

/**
    Creates a new char type (UTF-8)
*/
CuType createChar() {
    return new CuType(CuTypeKind.char_, Context.Global.CreateByte);
}

/**
    Creates a new struct type
*/
CuStructType createStruct(string name, CuType[] memberTypes, bool isPacked = false) {
    return new CuStructType(name, memberTypes, isPacked);
}

/**
    Creates a new struct type
*/
CuStructType createStruct(CuType[] memberTypes, bool isPacked = false) {
    return new CuStructType(memberTypes, isPacked);
}

/**
    Creates a new function type
*/
CuFuncType createFunc(CuType returnType, CuType[] paramTypes) {
    return new CuFuncType(returnType, paramTypes);
}

/**
    A copper state containing modules and handles indexing across modules
*/
class CuState {
public:
    CuModule[] modules;

    /**
        Adds a module to the state
    */
    CuModule addModule(string name, Node* ast) {
        CuModule mod = new CuModule(this, name, ast);
        return mod;
    }

    /**
        Finds an LLVM type by name
    */
    CuType findType(string type) {
        import std.conv : to;
        import std.stdio;

        if (type == "") return null;

        // Handle arrays
        if (type.isDynamicArray) {
            return new CuPointerType(findType(type[0..$-2]));
        } else if (type.isStaticArray) {
            string arrayLenStr = type.fetchArrayLength();

            // It wasn't an array anyway.
            if (arrayLenStr is null) return null;

            return new CuArrayType(findType(type[0..$-(arrayLenStr.length+2)]), arrayLenStr.to!uint);
        } else {
            // First attempt to find it as a basic type
            CuType t = createTypeFromName(this, type);
            if (t is null) {

                // Iterate through all modules
                foreach(mod; modules) {

                    // Look at each declaration in said modules and check the type
                    foreach(CuDecl decl; mod.declarations) {
                        if (decl.type.typeName == type) {
                            return decl.type;
                        }
                    }
                }
            }

            return t;
        }
    }

    /**
        Finds a declaration (of any type)
    */
    CuDecl findDeclaration(string name) {
         // Iterate through all modules
        foreach(mod; modules) {

            // Look at each declaration in said modules and check the type
            foreach(CuDecl decl; mod.declarations) {
                if (decl.name == name) {
                    return decl;
                }
            }
        }
        return null;
    }

    /**
        Tries to find a function as closely matching as possible
    */
    CuFunction findFunction(string name, CuType[] argTypes, bool ignoreTypes = false) {
         // Iterate through all modules
        foreach(mod; modules) {
            foreach (CuDecl decl; mod.declarations) {

                // Skip non-functions
                if (decl.type.typeKind != CuTypeKind.function_) continue;

                CuFunction funcDecl = cast(CuFunction)decl;

                // If the local (non-mangled) name matches
                if (funcDecl.name == name) {
                    // TODO: do the type level matching
                    return funcDecl;
                }
            }
        }
        return null;
    }
}

/**
    A LLVM Module
*/
class CuModule {
private:
    CuState parentState;
    string name_;
    Node* ast;
    string[] imports;

package(cujit):
    Module llvmMod;
    CuDecl[string] declarations;
    CuDecl[] weakDeclarations;
    CuDecl[string] globals;

    /**
        Adds a strong (finished) declaration to the module
    */
    void addDeclaration(string name, CuDecl declaration) {
        declarations[name] = declaration;
    }

    /**
        Adds a weak declaration to the module
        (one in the progress of being constructed)
    */
    void addWeakDeclaration(CuDecl declaration) {
        weakDeclarations ~= declaration;
    }

    CuValue addGlobalConstVar(CuType type, CuValue value) {
        string name = "%s.%s".format(type.typeName, globals.length);
        GlobalVariable var = llvmMod.AddGlobalVar(value.type.llvmType, name);
        var.Initializer = cast(Constant)value.llvmValue;
        var.IsGlobalConst = true;
        var.Visibility = VisibilityType.Hidden;
        var.Significance = AddressSignificance.GloballyInsignificant;
        globals[name] = new CuDecl(this, type, name);
        return new CuValue(type, var);
    }

public:

    /**
        Creates a new module
    */
    this(CuState state, string name, Node* ast) {
        this.llvmMod = new Module(name);
        this.ast = ast;
        this.name_ = name;
        this.parentState = state;
        this.parentState.modules ~= this;
    }

    /**
        Add module import
    */
    void addImport(string import_) {
        this.imports ~= import_;
    }

    /**
        The name of the module
    */
    string name() {
        return name_;
    }

    /**
        The LLVM IR of the module
    */
    string getIR() {
        return llvmMod.toString();
    }

    /**
        Try to find a type (across all modules)
    */
    CuType findType(string type) {
        return parentState.findType(type);
    }

    /**
        Try to find a type (across all modules)
    */
    CuDecl findDeclaration(string name) {
        return parentState.findDeclaration(name);
    }

    /**
        Try to find a function (across all modules)

        Note: this takes the local name, not the mangled name.
    */
    CuFunction findFunction(string name, CuType[] typeMatch) {
        return parentState.findFunction(name, typeMatch);
    }
}

/**
    A copper declaration
*/
class CuDecl {
private:
    this() { }

public:

    /**
        Wether this declaration is external
    */
    bool isExternal;

    /**
        The parent module of the declaration
    */
    CuModule parentModule;

    /**
        The type of the declaration
    */
    CuType type;

    /**
        The parent struct or class of a declaration
    */
    CuDecl parent;

    /**
        The (human readable) name of this declaration
    */
    string name;

    /**
        The visibility of this declaration
    */
    Visibility visibility;

    /**
        The LLVM offset if any
    */
    size_t offset;

    /**
        The node where it is allocated
    */
    Node* allocSpace;

    /**
        Creates a new copper declaration
    */
    this(CuModule module_, CuType type, string name, CuDecl parent = null, Visibility visibility = Visibility.Global, bool isExdecl = false) { 
        this.parentModule = module_;
        this.type = type;
        this.name = name;
        this.parent = parent;
        this.visibility = visibility;
        this.isExternal = isExdecl;
    }
}

/**
    A copper code section

    A code section is a small wrapper around LLVM's BasicBlock
*/
class CuSection {
private:
    this(CuFunction owner, BasicBlock block, string name, CuSection parent = null) {
        this.owner = owner;
        this.llvmBlock = block,
        this.parent = parent;
        this.name = name;
    }

public:

    /**
        The name of the section
    */
    string name;

    /**
        The basic block this section wraps
    */
    BasicBlock llvmBlock;

    /**
        The owner function this is attached to
    */
    CuFunction owner;

    /**
        The parent section (the section that this was created from)
    */
    CuSection parent;

    /**
        Allocated variables on the stack
    */
    CuValue[string] allocatedStackVars;
}

/**
    A copper function
*/
class CuFunction : CuDecl {
private:
    CuDecl[string] idxMapping;
    CuSection[string] sectionMapping;
    CuDecl[] idxList;

package(cujit):
    Function llvmFunc;
    Node* bodyAST;

public:
    this(CuModule module_, CuType returnType, string name, CuDecl[] parameters, Visibility visibility = Visibility.Global, bool isExdecl = false) {

        this.parentModule = module_;
        this.name = name;

        // Generate the struct type info
        CuType[] paramTypes = new CuType[parameters.length];
        idxList = new CuDecl[parameters.length];
        foreach(i, param; parameters) {

            // Fetch the CuType from the declaration and set its mapping, might as well do both.
            paramTypes[i] = param.type;
            if (param.name in idxMapping) {
                throw new Exception("There already exists a parameter called "~param.name~" in "~mangledName~"!");
            }
            idxMapping[param.name] = param;
            idxList[i] = param;
            param.offset = i;

            // Update the member declaration's parent while we're at it.
            param.parent = this;
        }

        // Set the type and make it point back to the declaration
        this.type = createFunc(returnType, paramTypes);
        this.funcType.declaration = this;
        this.isExternal = isExdecl;
        this.visibility = visibility;
    }

    /**
        The copper type of the function
    */
    @property
    CuFuncType funcType() {
        return cast(CuFuncType)type;
    }

    /**
        Gets the return type of this function
    */
    @property
    CuType returnType() {
        return funcType.returnType;
    }

    /**
        Returns the mangled name of the type
    */
    @property
    string mangledName() {
        import std.array : join;

        // Get the parameter type names
        string[] tNames = new string[funcType.argumentTypes.length];
        foreach(i, param; funcType.argumentTypes) {
            tNames[i] = param.typeName;
        }

        return "%s%s(%s)".format((parent !is null ? parent.name~"::" : ""), this.name, tNames.length > 0 ? tNames.join(",") : "void");
    }

    /**
        Finalizes the function.

        After a function has been finalized its declaration cannot be changed.

        Its body can be; though.
    */
    void finalize(bool cCompat = false) {
        if (llvmFunc !is null) throw new Exception(this.mangledName~" is already finalized!");
        llvmFunc = new Function(this.parentModule.llvmMod, cast(FuncType)this.funcType.llvmType, cCompat ? name : mangledName);

        parentModule.addDeclaration(cCompat ? name : mangledName, this);
    }

    /**
        Gets a section from the mapping

        Adds a new section if none was found
    */
    CuSection getSection(string name, CuSection from = null) {
        if (name !in sectionMapping) {
            sectionMapping[name] = new CuSection(this, llvmFunc.AppendBasicBlock(Context.Global, name), name, from);
        }
        return sectionMapping[name];
    }

    /**
        Appends a new section
    */
    CuSection appendSection(string name, CuSection from = null) {
        BasicBlock block = llvmFunc.AppendBasicBlock(Context.Global, name);
        CuSection section = new CuSection(this, block, block.Name, from);
        sectionMapping[block.Name] = section;
        return sectionMapping[block.Name];
    }

    /**
        Appends a section and copies the references from the origin section in
    */
    CuSection appendCopySection(string name, CuSection copyFrom) {
        CuSection appended = appendSection(name);

        // Copy stack vars over
        appended.allocatedStackVars = copyFrom.allocatedStackVars;

        return appended;
    }

    /**
        Gets a function parameter

        Returns null if the parameter wasn't found
    */
    CuValue getParam(string name) {
        if (name !in idxMapping) return null;
        return new CuValue(idxMapping[name].type, llvmFunc.GetParam(cast(uint)idxMapping[name].offset));
    }

    /**
        Gets the index mapped parameters.
    */
    @property
    CuDecl[string] parameters() {
        return idxMapping;
    }

    /**
        Gets the index mapped parameters in numeric order
    */
    @property
    CuDecl[] orderedParams() {
        return idxList;
    }

    /**
        Sets the body ast
    */
    void setBodyAST(Node* ast) {
        this.bodyAST = ast;
    }
}

/**
    A copper structure
*/
class CuStruct : CuDecl {
private:
    CuDecl[] members_;
    uint[string] idxMapping;

public:
    /**
        Creates a new struct
    */
    this(CuModule module_, string name, CuDecl[] members) {
        this.parentModule = module_;
        this.members_ = members;
        this.name = name;

        // Generate the struct type info
        CuType[] memberTypes = new CuType[members.length];
        foreach(i, member; members) {

            // Fetch the CuType from the declaration and set its mapping, might as well do both.
            memberTypes[i] = member.type;
            if (member.name in idxMapping) {
                throw new Exception("There already exists a member called "~member.name~" in "~name~"!");
            }
            idxMapping[member.name] = cast(uint)i;

            // Update the member declaration's parent while we're at it.
            member.parent = this;
        }

        // Set up the struct and make so that the type points back to the declaration
        this.type = createStruct(name, memberTypes, false);
        this.structType.declaration = this;

        // Add the struct to the module's declarations list
        this.parentModule.addDeclaration(name, this);
    }

    /**
        Gets the struct type of this struct
    */
    @property
    CuStructType structType() {
        return cast(CuStructType)type;
    }

    /**
        Tries to find a member in the struct, returns the offset if found or -1 if not.
    */
    int findMemberIndex(string name) {
        return (name in idxMapping ? cast(int)idxMapping[name] : -1);
    }

    /**
        The struct members
    */
    @property
    CuDecl[] members() {
        return members_;
    }
}

class CuClass : CuDecl {

}

/**
    A copper value
*/
class CuValue {
private:
    this() { }

public:
    /**
        The copper type
    */
    CuType type;

    /**
        The name of the value/variable
    */
    string name;

    /**
        The llvm value
    */
    Value llvmValue;

    /**
        Creates a new copper value
    */
    this(CuType type, Value value) {
        this.type = type;
        this.llvmValue = value;
        this.name = llvmValue.Name;
    }
}

/**
    Creates a constant integeral type based of the specified type
*/
CuValue constIntegral(CuType type, ulong val) {
    CuValue value = new CuValue();
    value.type = type;
    value.llvmValue = new ConstInt(value.type.llvmType, val, false);
    return value;
}

/**
    Creates a constant boolean value
*/
CuValue constBool(bool val) {
    CuValue value = new CuValue();
    value.type = createBool();
    value.llvmValue = new ConstInt(value.type.llvmType, val, false);
    return value;
}

/**
    Creates a constant ubyte value
*/
CuValue constUByte(ubyte val) {
    CuValue value = new CuValue();
    value.type = createUByte();
    value.llvmValue = new ConstInt(value.type.llvmType, val, false);
    return value;
}

/**
    Creates a constant ushort value
*/
CuValue constUShort(ushort val) {
    CuValue value = new CuValue();
    value.type = createUShort();
    value.llvmValue = new ConstInt(value.type.llvmType, val, false);
    return value;
}

/**
    Creates a constant uint value
*/
CuValue constUInt(uint val) {
    CuValue value = new CuValue();
    value.type = createUInt();
    value.llvmValue = new ConstInt(value.type.llvmType, val, false);
    return value;
}

/**
    Creates a constant ulong value
*/
CuValue constULong(ulong val) {
    CuValue value = new CuValue();
    value.type = createULong();
    value.llvmValue = new ConstInt(value.type.llvmType, val, false);
    return value;
}

/**
    Creates a constant byte value
*/
CuValue constByte(byte val) {
    CuValue value = new CuValue();
    value.type = createByte();
    value.llvmValue = new ConstInt(value.type.llvmType, val, true);
    return value;
}

/**
    Creates a constant short value
*/
CuValue constShort(short val) {
    CuValue value = new CuValue();
    value.type = createShort();
    value.llvmValue = new ConstInt(value.type.llvmType, val, true);
    return value;
}

/**
    Creates a constant int value
*/
CuValue constInt(int val) {
    CuValue value = new CuValue();
    value.type = createInt();
    value.llvmValue = new ConstInt(value.type.llvmType, val, true);
    return value;
}

/**
    Creates a constant long value
*/
CuValue constLong(long val) {
    CuValue value = new CuValue();
    value.type = createLong();
    value.llvmValue = new ConstInt(value.type.llvmType, val, true);
    return value;
}

/**
    Creates a constant floating point value
*/
CuValue constFloating(CuType type, double val) {
    CuValue value = new CuValue();
    value.type = type;
    value.llvmValue = new ConstReal(value.type.llvmType, val);
    return value;
}

/**
    Creates a const string literal (as global array)
*/
CuValue constStringLiteral(string val) {
    CuValue value = new CuValue();
    value.type = createStaticArray(createChar(), val.sizeof);
    value.llvmValue = new ConstString(val, true);
    return value;
}

/**
    Creates a constant string pointing to a literal
*/
CuValue constString(CuValue literal, size_t length) {
    CuValue value = new CuValue();
    value.type = createString();
    value.llvmValue = new ConstStruct([
        new ConstInt(createSizeT().llvmType, length, false),
        literal.llvmValue
    ], false);
    return value;
}

/**
    Creates a constant long value
*/
CuValue constFloat(float val) {
    CuValue value = new CuValue();
    value.type = createFloat();
    value.llvmValue = new ConstReal(value.type.llvmType, val);
    return value;
}


/**
    Creates a constant long value
*/
CuValue constDouble(double val) {
    CuValue value = new CuValue();
    value.type = createDouble();
    value.llvmValue = new ConstReal(value.type.llvmType, val);
    return value;
}

CuValue constStruct(CuValue[] values, bool packed = false) {
    CuValue value = new CuValue();

    Value[] llvmValues = new Value[values.length];
    CuType[] types = new CuType[values.length];
    foreach(i, val; values) {
        types[i] = val.type;
        llvmValues[i] = val.llvmValue;
    }
    value.type = createStruct(types, packed);

    value.llvmValue = new ConstStruct(llvmValues, packed);
    return value;
}