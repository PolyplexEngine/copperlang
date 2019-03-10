module copper.lang.parser.types;
import copper.lang.token;

alias TypeId = ubyte;

/// Any
enum TypeId tpAny = 0;

/// Int
enum TypeId tpInt = 1;

/// Number
enum TypeId tpNumber = 2;

/// String
enum TypeId tpString = 3;

/// Pointer
enum TypeId tpPtr = 4;

/// Function
enum TypeId tpFunction = 5;

/// User defined
enum TypeId tpUserDefined = 6;

/// A struct
enum TypeId tpStruct = 10;

/// A class
enum TypeId tpClass = 20;

alias TypeVisibilityId = ubyte;

enum TypeVisibilityId tvPublic = 1;
enum TypeVisibilityId tvPrivate = 0;


/// A rough type description used to make sure a given type name exists and check what underlying type it has
struct RoughType {
public:
    TypeId typeId;
    string name;
}

/// Extended rough type, with extra info put in
struct MemberType {
public:
    TypeId typeId;
    TypeVisibilityId visibility;
    string name;
    size_t alignment;
}

/// Used in the compilation process to store proper type data, used to make sure that stuff does as it should.
struct Type {
public:
    TypeVisibilityId visibility;
    TypeId typeId;
    string name;
    MemberType[] members;
}

/// Type mappings for a module
struct TypeMapping {
    /// The module/namespace the type resides in
    string mod;

    /// The rough types
    RoughType[string] types;

    bool add(RoughType type) {
        if (type.name in types) return false;

        types[type.name] = type;
        return true;
    }

    bool hasType(string name) {
        return (name in types) !is null;
    }

    bool hasType(Token token) {
        return hasType(token.lexeme);
    }

    RoughType get(string name) {
        return types[name];
    }

    RoughType get(Token token) {
        return get(token.lexeme);
    }
}