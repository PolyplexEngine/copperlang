module copper.lang.vm.types;

alias vtType = ubyte;

extern(C) enum vtType vtBadType  = 0;
extern(C) enum vtType vtAny      = 1;
extern(C) enum vtType vtTable    = 2;
extern(C) enum vtType vtStruct   = 3;
extern(C) enum vtType vtInt      = 4;
extern(C) enum vtType vtNumber   = 5;
extern(C) enum vtType vtString   = 6;
extern(C) enum vtType vtPtr      = 7;
extern(C) enum vtType vtMeta     = 8;
extern(C) enum vtType vtFunction = 9;

string vtToString(vtType type) {
    switch(type) {
        case(vtAny):        return "any";
        case(vtTable):      return "table";
        case(vtStruct):     return "struct";
        case(vtInt):        return "int";
        case(vtString):     return "string";
        case(vtPtr):        return "ptr";
        case(vtMeta):       return "meta";
        case(vtFunction):   return "function";
        default:
            return "bad type";
    }
}
/*
private vtType getType(Token token) {
    if (token == Token.tkStruct)
        return vtStruct;
    if (token == Token.tkTable)
        return vtTable;
    if (token == Token.tkAny)
        return vtAny;
    if (token == Token.tkPtr)
        return vtPtr;
    if (token == Token.tkMeta)
        return vtMeta;
    if (token == Token.tkFunction)
        return vtFunction;
    if (token == Token.tkInt || token == Token.tkIntConst)
        return vtInt;
    if (token == Token.tkNumber || token == Token.tkNumberConst)
        return vtNumber;
    if (token == Token.tkString || token == Token.tkStringConst)
        return vtString;
    return vtBadType;
}*/