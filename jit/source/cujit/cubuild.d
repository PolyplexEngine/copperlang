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
        The declaration for the type

        Note: this is only relevant if the type is a class or struct
    */
    CuDecl typeDecl;
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
        default: return state.findType(type);
    }
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

    CuModule addModule(string name, Node* ast) {
        CuModule mod = new CuModule(name, ast);
        modules ~= mod;
        return mod;
    }

    /**
        Finds an LLVM type by name
    */
    CuType findType(string type) {
        import std.conv : to;

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
}

/**
    A LLVM Module
*/
class CuModule {
private:
    string name_;
    Node* ast;
    string[] imports;

package(cujit):
    Module llvmMod;
    CuDecl[string] declarations;

public:

    this(string name, Node* ast) {
        this.llvmMod = new Module(name);
        this.ast = ast;
        this.name_ = name;
    }

    void addImport(string import_) {
        this.imports ~= import_;
    }

    string name() {
        return name_;
    }

    string getIR() {
        return llvmMod.toString();
    }
}

/**
    A copper declaration
*/
class CuDecl {
protected:
    // List of either parameters or members based on if its a function or a struct/class
    int[string] paramsOrMembers;

public:
    /**
        The type of the declaration
    */
    CuType type;

    /**
        The (human readable) name of this declaration
    */
    string name;

    /**
        The visibility of this declaration
    */
    Visibility visibility;
}

/**
    A copper function
*/
class CuFunction : CuDecl {
private:
    Function llvmFunc;

public:
    /**
        The return type of the function
    */
    CuType returnType;

    /**
        The types of the parameters
    */
    CuType[] paramTypes;

    /**
        The parent module of a function
    */
    CuModule parentModule;

    /**
        The parent struct or class of a function
    */
    CuDecl parent;

    @property
    string mangledName() {
        string[] tNames;
        foreach(param; paramTypes) {

        }

        return "%s%s(%s)".format((parent !is null ? parent.name~"::" : ""), this.name, );
    }

}

class CuClass : CuDecl {

}

class CuStruct : CuDecl {

}