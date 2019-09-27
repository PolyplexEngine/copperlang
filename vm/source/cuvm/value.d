module cuvm.value;
import std.traits;
import std.conv;

enum IsValidCuArray(T) = (!is(T == string) && !is(T == immutable(char))) || (is(T : string[]) || is(T : immutable(char)[]));

/**
    A value in the VM
*/
struct CuValue {
    /**
        The actual type of the value pool value
    */
    CuValueType TYPE;

    /**
        The type of the value pool value exposed
    */
    CuValueType EXPOSED_TYPE;

    /**
        The flags for the value
    */
    CuAccessorFlags FLAGS;

    /**
        The data of the value pool item
    */
    CuValueData[] DATA;

    /**
        This constructor tries intelligently to guess the type of the input
        or use the provided type by the user
    */
    this(T)(T value, CuAccessorFlags flags = CuAccessorFlags.NONE, CuValueType exposed = CuValueType.ANY) if (!isArray!T || is(T : string)) {
        import std.uni : toUpper;
        import std.format : format;
        this.TYPE = ValueTypeFromName(T.stringof);
        this.EXPOSED_TYPE = exposed;
        this.FLAGS = flags;
        mixin(q{
            CuValueData xvalue;
            xvalue.%s = value;
            DATA = [xvalue];
        }.format(T.stringof.toUpper));
    }

    /**
        This constructor tries intelligently to guess the type of the input
        or use the provided type by the user
    */
    this(T)(T[] values, CuAccessorFlags flags = CuAccessorFlags.NONE, CuValueType exposed = CuValueType.ANY) if (IsValidCuArray!T) {
        import std.uni : toUpper;
        import std.format : format;
        this.TYPE = ValueTypeFromName(T.stringof);
        this.EXPOSED_TYPE = exposed;
        this.FLAGS = flags;
        pragma(msg, T.stringof.toUpper);
        foreach(value; values) {
            mixin(q{
                CuValueData xvalue;
                xvalue.%s = value;
                DATA ~= xvalue;
            }.format(T.stringof.toUpper));
        }
    }

    /**
        This constructor is aimed at the compiler
    */
    this(CuValueType type, CuValueData[] data, CuAccessorFlags flags = CuAccessorFlags.NONE, CuValueType exposed = CuValueType.ANY) {
        this.TYPE = type;
        this.EXPOSED_TYPE = exposed;
        this.FLAGS = flags;
        this.DATA = data;
    }

    string toString() {
        import std.format : format;
        import std.array : join;

        // Fetch and format data (including arrays)
        string data;
        if (DATA.length == 1) data = DATA[0].toString(TYPE);
        else {
            // TODO: Clean this stuff up
            string[] dataList;
            foreach(dt; DATA) {
                dataList ~= dt.toString(TYPE);
            }
            data = "[%s]".format(dataList.join(", "));
        }

        // Output it all
        return "%s %s(%s) %s".format(FLAGS, EXPOSED_TYPE, TYPE, data);
    }
}

/**
    The data stored by a pool
*/
union CuValueData {
    /// ubyte
    ubyte UBYTE;

    /// ushort
    ushort USHORT;

    /// uint
    uint UINT;

    /// byte
    byte BYTE;

    /// short
    short SHORT;

    /// int
    int INT;

    /// double
    double DOUBLE;

    /// float
    float FLOAT;

    /// char
    char CHAR;

    /// string
    string STRING;

    string toString(CuValueType type) {
        import std.conv : text;
        switch (type) {
            case CuValueType.UBYTE:
                return UBYTE.text;
            case CuValueType.USHORT:
                return USHORT.text;
            case CuValueType.UINT:
                return UINT.text;
            case CuValueType.BYTE:
                return BYTE.text;
            case CuValueType.SHORT:
                return SHORT.text;
            case CuValueType.INT:
                return INT.text;
            case CuValueType.FLOAT:
                return FLOAT.text;
            case CuValueType.DOUBLE:
                return DOUBLE.text;
            case CuValueType.CHAR:
                return CHAR.text;
            case CuValueType.STRING:
                return STRING.text;
            default: return "ERROR";
        }
    }
}

bool IS_TYPE_INTERGRAL(CuValueType type) {
    switch (type) {
        case CuValueType.UBYTE:
            return true;
        case CuValueType.USHORT:
            return true;
        case CuValueType.UINT:
            return true;
        case CuValueType.BYTE:
            return true;
        case CuValueType.SHORT:
            return true;
        case CuValueType.INT:
            return true;
        default: return false;
    }
}

bool IS_TYPE_SIGNED_INTERGRAL(CuValueType type) {
    switch (type) {
        case CuValueType.BYTE:
            return true;
        case CuValueType.SHORT:
            return true;
        case CuValueType.INT:
            return true;
        default: return false;
    }
}

bool IS_TYPE_UNSIGNED_INTERGRAL(CuValueType type) {
    switch (type) {
        case CuValueType.UBYTE:
            return true;
        case CuValueType.USHORT:
            return true;
        case CuValueType.UINT:
            return true;
        default: return false;
    }
}

bool IS_TYPE_FLOATING(CuValueType type) {
    return (type == CuValueType.FLOAT);
}

bool IS_TYPE_DOUBLE(CuValueType type) {
    return (type == CuValueType.DOUBLE);
}

bool IS_TYPE_NUMERIC(CuValueType type) {
    switch (type) {
        case CuValueType.UBYTE:
            return true;
        case CuValueType.USHORT:
            return true;
        case CuValueType.UINT:
            return true;
        case CuValueType.BYTE:
            return true;
        case CuValueType.SHORT:
            return true;
        case CuValueType.INT:
            return true;
        case CuValueType.FLOAT:
            return true;
        case CuValueType.DOUBLE:
            return true;
        default: return false;
    }
}

bool IS_TYPE_STRING(CuValueType type) {
    return (type == CuValueType.STRING);
} 

bool IS_TYPE_CHAR(CuValueType type) {
    return (type == CuValueType.CHAR);
} 

int AS_SIGNED(CuValueData data, CuValueType origin) {
    if (IS_TYPE_SIGNED_INTERGRAL(origin)) return data.INT;
    if (IS_TYPE_UNSIGNED_INTERGRAL(origin)) return cast(int)data.UINT;
    if (IS_TYPE_FLOATING(origin)) {
        if (origin == CuValueType.FLOAT) return cast(int)data.FLOAT;
        return cast(int)data.DOUBLE;
    }
    if (IS_TYPE_STRING(origin)) {
        return data.STRING.to!int;
    }
    throw new Exception("Cannot convert "~origin~" to INT");
}

uint AS_UNSIGNED(CuValueData data, CuValueType origin) {
    if (IS_TYPE_SIGNED_INTERGRAL(origin)) return cast(uint)data.INT;
    if (IS_TYPE_UNSIGNED_INTERGRAL(origin)) return data.UINT;
    if (IS_TYPE_FLOATING(origin)) {
        if (origin == CuValueType.FLOAT) return cast(uint)data.FLOAT;
        return cast(uint)data.DOUBLE;
    }
    if (IS_TYPE_STRING(origin)) {
        return data.STRING.to!uint;
    }
    throw new Exception("Cannot convert "~origin~" to UINT");
}

double AS_DOUBLE(CuValueData data, CuValueType origin) {
    if (IS_TYPE_SIGNED_INTERGRAL(origin)) return cast(double)data.INT;
    if (IS_TYPE_UNSIGNED_INTERGRAL(origin)) return cast(double)data.UINT;
    if (IS_TYPE_FLOATING(origin)) {
        if (origin == CuValueType.FLOAT) return cast(double)data.FLOAT;
        return data.DOUBLE;
    }
    if (IS_TYPE_STRING(origin)) {
        return data.STRING.to!double;
    }
    throw new Exception("Cannot convert "~origin~" to DOUBLE");
}

float AS_FLOAT(CuValueData data, CuValueType origin) {
    if (IS_TYPE_SIGNED_INTERGRAL(origin)) return cast(float)data.INT;
    if (IS_TYPE_UNSIGNED_INTERGRAL(origin)) return cast(float)data.UINT;
    if (IS_TYPE_FLOATING(origin)) {
        if (origin == CuValueType.FLOAT) return data.FLOAT;
        return cast(float)data.DOUBLE;
    }
    if (IS_TYPE_STRING(origin)) {
        return data.STRING.to!float;
    }
    throw new Exception("Cannot convert "~origin~" to FLOAT");
}

string AS_STRING(CuValueData data, CuValueType origin) {
    if (IS_TYPE_SIGNED_INTERGRAL(origin)) return data.INT.text;
    if (IS_TYPE_UNSIGNED_INTERGRAL(origin)) return data.UINT.text;
    if (IS_TYPE_FLOATING(origin)) {
        if (origin == CuValueType.FLOAT) return data.FLOAT.text;
        return data.DOUBLE.text;
    }
    if (IS_TYPE_STRING(origin)) {
        return data.STRING;
    }
    if (IS_TYPE_CHAR(origin)) {
        return ""~data.CHAR;
    }
    throw new Exception("Cannot convert "~origin~" to STRING");
}

CuValueType ValueTypeFromName(string name) {
    switch(name) {
        case "UBYTE",   "ubyte":    return CuValueType.UBYTE;
        case "USHORT",  "ushort":   return CuValueType.USHORT;
        case "UINT",    "uint":     return CuValueType.UINT;
        case "BYTE",    "byte":     return CuValueType.BYTE;
        case "SHORT",   "short":    return CuValueType.SHORT;
        case "INT",     "int":      return CuValueType.INT;
        case "FLOAT",   "float":    return CuValueType.FLOAT;
        case "DOUBLE",  "double":   return CuValueType.DOUBLE;
        case "CHAR",    "char":     return CuValueType.CHAR;
        case "STRING",  "string":   return CuValueType.STRING;

        default: return CuValueType.ANY;
    }
}

/**
    The type of the data in the value pool
*/
enum CuValueType : ubyte {
    ANY,
    UBYTE,
    USHORT,
    UINT,
    BYTE,
    SHORT,
    INT,
    FLOAT,
    DOUBLE,
    CHAR,
    STRING
}

/**
    Accessor flags
*/
enum CuAccessorFlags : ubyte {
    NONE = 0x0,
    PTR = 0x1,
    EXDECL = 0x8
}