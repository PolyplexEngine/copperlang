module cujit.jithelpers;
import std.conv;
import std.conv;
import std.stdio;

/*
    This file contains the convenience functions used by copper to allow easy type conversion.

    Everything is exported in here.
*/

/**
    Text exdecl
*/
extern(C) void print(string text) {
    writeln(text);
}

/**
    string comparison
*/
extern(C) bool streq(string a, string b) {
    return a == b;
}

/// INTEGRAL (TO STRING)

extern(C) string ubyte_to_string(ubyte value) {
    return value.text;
}

extern(C) string ushort_to_string(ushort value) {
    return value.text;
}

extern(C) string uint_to_string(uint value) {
    return value.text;
}

extern(C) string ulong_to_string(ulong value) {
    return value.text;
}

extern(C) string byte_to_string(byte value) {
    return value.text;
}

extern(C) string short_to_string(short value) {
    return value.text;
}

extern(C) string int_to_string(int value) {
    return value.text;
}

extern(C) string long_to_string(long value) {
    return value.text;
}


/// FLOATING POINT (TO STRING)

extern(C) string float_to_string(float value) {
    return value.text;
}

extern(C) string double_to_string(double value) {
    return value.text;
}


// EVERYTHING (FROM STRING)

extern(C) int string_to_int(string value) {
    return value.to!int;
}

// TODO: fill this part out