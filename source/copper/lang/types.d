module copper.lang.types;
import std.format;
import std.traits;

alias ValType = ubyte;

// Unsigned intergral
enum ValType vaUByte = 0;
enum ValType vaUShort = 1;
enum ValType vaUInt = 2;
enum ValType vaULong = 3;

// Signed intergral
enum ValType vaByte = 10;
enum ValType vaShort = 11;
enum ValType vaInt = 12;
enum ValType vaLong = 13;

// floating point
enum ValType vaFloat = 20;
enum ValType vaDouble = 21;

// characters and text
enum ValType vaChar = 30;
enum ValType vaString = 31;

// Various
enum ValType vaPtr = 42;

/// A value in the VM.
public struct ChunkVal
{

    static ChunkVal constr(T)(T input)
    {
        ChunkVal cv;
        static if (is(T == ubyte))          cv.type = vaUByte;
        else static if (is(T == ushort))    cv.type = vaUShort;
        else static if (is(T == uint))      cv.type = vaUInt;
        else static if (is(T == ulong))     cv.type = vaULong;
        else static if (is(T == byte))      cv.type = vaByte;
        else static if (is(T == short))     cv.type = vaShort;
        else static if (is(T == int))       cv.type = vaInt;
        else static if (is(T == long))      cv.type = vaLong; 
        else static if (is(T == float))     cv.type = vaFloat;         
        else static if (is(T == double))    cv.type = vaDouble;          
        else static if (is(T == char))      cv.type = vaChar;        
        else static if (is(T == string))    cv.type = vaString;       
        else                                cv.type = vaPtr;
        cv.as = ValData.create!T(input);
        return cv;
    }

    /// The VM type for this value
    ValType type;

    /// The data contained
    ValData as;
}

private enum isBasicType(T) = isNumeric!T || is (T : bool) || is (T : char);

/// The actual content
public union ValData
{
    /// creates a new value instance.
    static ValData create(T)(T data) {
        ValData dat;

        static if (is(T : ubyte[])) {

            dat.ubyteArr = data;
        } else static if (isBasicType!T) {

            mixin(q{dat.%s_ = data;}.format(T.stringof));
        } else {

            static if (!isPointer(data)) {
                dat.object_ = cast(void*)&data;
            } else {
                dat.object_ = cast(void*)data;
            }
        }
        return dat;
    }
    

    /// ubyte
    ubyte ubyte_;

    /// ushort
    ushort ushort_;

    /// uint
    uint uint_;

    /// ulong
    ulong ulong_;

    /// byte
    byte byte_;

    /// short
    short short_;

    /// int
    int int_;

    /// long
    long long_;

    /// float
    float float_;

    /// double
    double double_;

    /// char
    char char_;

    /// ptr size
    size_t ptr_;

    /// Object, array and D pointer
    void* object_;

    /// Array of data, used internally.
    ubyte[size_t.sizeof] ubyteArr;
}