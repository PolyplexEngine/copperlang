module copper.lang.compiler.compiler;
import copper.lang.parser.node;
import copper.share.utils;
import std.stdio;

/// A tag descriping which kind of type this is.
enum TypeTag : ubyte {
    /// A basic type
    Basic,

    /// A structure
    Struct,

    /// A class
    Class
}

enum Visibility {
    PRIVATE,
    PROTECTED,
    PUBLIC
}

/// Basic type info
/// Do not use this other than for basic types
struct CuTypeInfo {
    /// Tag
    TypeTag tag;

    /// Wether the type is stored on the stack or in the heap
    bool onStack;

    /// Size of type data in bytes
    /// If a dynamic size, set it to size_t.sizeof
    /// Dynamic types are pointer types.
    size_t size;

    /// Name of type
    string typeName;
}

struct CuMember {

    /// The visibility
    Visibility visibility;
    
    /// The type of the member
    CuTypeInfo* type;

    /// The name of the member
    string name;
}

/// Type information for a struct
struct CuTypeInfo_Struct {
    /// The CuTypeInfo base
    CuTypeInfo baseInfo;
    alias baseInfo this;

    /// The visibility
    Visibility visibility;

    /// The fields
    CuMember[] fields;
}

/// Type information for a class
struct CuTypeInfo_Class {
    /// The CuTypeInfo base
    CuTypeInfo baseInfo;
    alias baseInfo this;

    /// The visibility
    Visibility visibility;

}

package
{
    // Contains the different types of type info in a union.
    union TypeInfoUnion {
        CuTypeInfo        base;
        CuTypeInfo_Struct struct_;
        CuTypeInfo_Class  class_;
    }
    struct RegisterMap
    {
        string[8] gp;

        ptrdiff_t gpOf(string refv)
        {
            foreach (i, reg; gp)
            {
                if (reg == refv)
                    return i;
            }
            return -1;
        }

        string[4] fp;

        ptrdiff_t fpOf(string refv)
        {
            foreach (i, reg; fp)
            {
                if (reg == refv)
                    return i;
            }
            return -1;
        }

        size_t stackBase;
        size_t stackMoved;
    }

    struct FuncDecl
    {
        string name;
        string returnType;
        ParamDecl[] parameters;

        string toString()
        {
            string paramDecls;
            foreach (param; parameters)
            {
                paramDecls ~= param.toString();
            }
            return name ~ "." ~ returnType ~ paramDecls;
        }

        size_t paramIndexOf(string name)
        {
            foreach (i, param; parameters)
            {
                if (param.name == name)
                    return i;
            }
            throw new Exception("Parameter " ~ name ~ " not found in scope!");
        }
    }

    struct Scope
    {
        size_t stackDepth;
        ParamDecl[string] variables;
    }


    struct ParamDecl
    {
        size_t offset;
        CuTypeInfo* type;
        string name;

        string toString()
        {
            return "." ~ type.typeName;
        }
    }

    struct StructDecl
    {
        string name;
        string injects;
        size_t size;
        size_t[string] offsets;
    }

    struct Declarations
    {
        FuncDecl[] functions;
        StructDecl[] structs;
    }

    /// TODO: Type mapping
    struct TypeMap
    {

    }
}

/// A registry of type information.
class TypeRegistry {
private:
    TypeInfoUnion[string] registeredTypes;

public:

    this() {
        registeredTypes = [
            "ubyte"  : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, ubyte.sizeof, "ubyte")),
            "byte"   : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, byte.sizeof, "byte")),
            "bool"   : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, bool.sizeof, "bool")),

            "ushort" : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, ushort.sizeof, "ushort")),
            "short"  : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, short.sizeof, "short")),

            "uint"   : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, uint.sizeof, "uint")),
            "int"    : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, int.sizeof, "int")),
            "char"   : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, char.sizeof, "char")),

            "ulong"  : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, ulong.sizeof, "ulong")),
            "long"   : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, long.sizeof, "long" )),

            "size_t" : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, size_t.sizeof, "size_t")),
            "ptr"    : TypeInfoUnion(CuTypeInfo(TypeTag.Basic, true, size_t.sizeof, "ptr"))
        ];
    }

    /// Returns true if the type is registered in this type registry.
    bool hasType(string typeName) {
        return (typeName in registeredTypes) !is null;
    }

    /// Return true of the type is registered in this type registry, and the type is a basic type.
    bool hasBasic(string typeName) {
        return hasType(typeName) && registeredTypes[typeName].base.tag == TypeTag.Basic;
    }
    
    /// Return true of the type is registered in this type registry, and the type is a struct type.
    bool hasStruct(string typeName) {
        return hasType(typeName) && registeredTypes[typeName].base.tag == TypeTag.Struct;
    }
    
    /// Return true of the type is registered in this type registry, and the type is a class type.
    bool hasClass(string typeName) {
        return hasType(typeName) && registeredTypes[typeName].base.tag == TypeTag.Class;
    }

    /// Gets basic type info
    CuTypeInfo* getBasicInfo(string typeName) {
        return &registeredTypes[typeName].base;
    }

    /// Gets struct type info
    CuTypeInfo_Struct* getStructInfo(string typeName) {
        return &registeredTypes[typeName].struct_;
    }

    /// Gets class type info
    CuTypeInfo_Class* getClassInfo(string typeName) {
        return &registeredTypes[typeName].class_;
    }

    /// Gets the size in bytes of a type.
    /// For structs and classes the size will INCLUDE the size of the properties/fields.
    size_t getSizeOf(string typeName) {
        return registeredTypes[typeName].base.size;
    }
}

abstract class Compiler {

    /// Print error
    void error(string errMsg, Node* node)
    {
        writeln(getOutText(node.token.source, node.token, "ERROR: " ~ errMsg));
    }

    /// Print warning
    void warning(string wrnMsg, Node* node)
    {
        writeln(getOutText(node.token.source, node.token, "WARNING: " ~ wrnMsg));
    }

    /// Get name of module of the AST node
    string getModuleName(Node* node)
    {
        if (node.firstChild !is null)
        {
            return node.token.lexeme ~ "." ~ getModuleName(node.firstChild);
        }
        return node.token.lexeme;
    }

    /// Compile compiles an AST node, each implementation right now implements its own way of getting the result out
    /// A generic interface will be made eventually.
    abstract void compile(Node* root);
}

Compiler newJIT() {
    return new LLVMCompiler();
}