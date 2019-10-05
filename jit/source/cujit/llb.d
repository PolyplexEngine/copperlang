module cujit.llb;
import std.uni, std.array, std.string, std.algorithm.searching, std.conv, std.format;
import dllvm;

/**
    Converts a string to a basic type

    returns null if the string did not match any basic types
*/
// Type stringToBasicType(State state, string type) {
//     switch(type) {
//         case "byte", "ubyte", "bool": return Context.Global.CreateByte();
//         case "short", "ushort": return Context.Global.CreateInt16();
//         case "int", "uint": return Context.Global.CreateInt32();
//         case "long", "ulong": return Context.Global.CreateInt64();
//         case "float": return Context.Global.CreateFloat32();
//         case "double": return Context.Global.CreateFloat64();
//         case "void": return Context.Global.CreateVoid();
//         default: {
            
//             // Handle arrays
//             if (type.isDynamicArray) {
//                 return Context.Global.CreatePointer(state.findType(type[0..$-2]));
//             } else if (type.isStaticArray) {
//                 string arrayLenStr = type.fetchArrayLength();

//                 // It wasn't an array anyway.
//                 if (arrayLenStr is null) return null;

//                 return Context.Global.CreateArray(state.findType(type[0..$-(arrayLenStr.length+2)]), arrayLenStr.to!uint);
//             }

//             // Okay, there really was nothing, return null.
//             return null;
//         }
//     }
// }

/**
    It's a dynamic array if it ends with []
*/
bool isDynamicArray(string type) {
    return type.endsWith("[]");
}

/**
    It's probably a static array if it isn't a dynamic array but its type still ends with a ]
*/
bool isStaticArray(string type) {
    return !type.isDynamicArray && type.endsWith("]");
}

/**
    Fetches the array length portion of a type
*/
string fetchArrayLength(string type) {
    string data;
    foreach_reverse(c; type[0..$-1]) {
        if (c == '[') return data;
        data = c ~ data;
    }
    return null;
}

/**
    Mangles the name of a function

    Mangling goes as follows:
    [<parent name>::]<func name>([<arg type>[, ...]])
*/
string mangleName(Function func, Type parent = null, bool isClass = false) {
    string params;
    
    // If we're in a class, skip the first parameter (self pointer)
    foreach(i; (isClass ? 1 : 0)..func.ParamCount) {
        params = [params, func.GetParam(i).TypeOf.TypeName].join(",");
    }

    if (parent !is null) return "%s::%s(%s)".format(parent.TypeName, func.Name, params == "" ? "void" : params);
    else return "%s(%s)".format(func.Name, params == "" ? "void" : params);
}

string mangleName(string name, string[] argTypes, Type parent = null, bool isClass = false) {
    if (parent !is null) return "%s::%s(%s)".format(parent.TypeName, name, argTypes.length == 0 ? "void" : argTypes.join(","));
    else return "%s(%s)".format(name, argTypes.length == 0 ? "void" : argTypes.join(","));
}