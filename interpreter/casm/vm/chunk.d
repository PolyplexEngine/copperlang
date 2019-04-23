module copper.lang.compiler.vm.chunk;
import copper.lang.arch;
import copper.lang.types;
import std.traits;
import std.stdio : writeln;

private struct AddrMap {
    size_t to;
    size_t[] maps;
}

private template writeJMPA(string id) {
    import std.format : format;
    mixin(q{
    /// Jump to address in the %s condition
    void write%s(size_t address) {
        chunk.write(op%s);
        chunk.writeData!size_t(address);
    }

    /// Jump to address in the %s condition
    void write%s(string label) {
        chunk.write(op%s);
        asLabel(label);
    }}.format(id, id, id, id, id, id));
}

class SymbolTable {
private:
    // TODO: replace with proper symbol table
    size_t[string] symbols;

    void set(string name, size_t address) {
        symbols[name] = address;
    }

public:
    size_t get(string name) {
        if (name !in symbols) throw new Exception("No symbol with name "~name~" found!");
        return symbols[name];
    }
}

struct CObject {
public:
    Chunk* chunk;
    SymbolTable symbols;
}

public class ChunkBuilder {
private:
    Chunk chunk;
    SymbolTable symbols;
    AddrMap[string] labels;

public:
    this() {
        chunk = Chunk(0, []);
        symbols = new SymbolTable();
    }

    void setLabel(string name, size_t to) {
        if (name !in labels) {
            labels[name] = AddrMap(to, []);
        } else {
            labels[name].to = to;
        }
    }

    void setLabel(string name) {
        setLabel(name, chunk.count);
    }

    void setSymbol(string name, size_t to) {
        setLabel(name, to);
        symbols.set(name, to);
    }

    void setSymbol(string name) {
        setSymbol(name, chunk.count);
    }

    void asLabel(string name) {
        if (name !in labels) {
            labels[name] = AddrMap(0, []);
        }
        labels[name].maps ~= chunk.count;
        chunk.writeADDRPlaceholder();
    }

    CObject* build() {
        foreach(name, label; labels) {
            version(DEBUG) writeln("Redirecting ", name, " to ", format(("#%0" ~ format("%d", size_t.sizeof) ~ "x"), label.to), "...");
            foreach(target; label.maps) {
                chunk.writeDataAt(label.to, target);
            }
        }
        return new CObject(&chunk, symbols);
    }

    SymbolTable getTable() {
        return symbols;
    }

    /// Pop values off stack
    void writePOP(size_t amount = 1) {
        chunk.write(opPOP);
        chunk.writeData(amount);
    }

    /// Push value to stack
    void writePSHR(Register register) {
        writePSH(optRegister, cast(size_t)register);
    }
    /// Push value to stack
    void writePSHV(size_t value) {
        writePSH(optValue, value);
    }

    /// Push value to stack
    void writePSH(Option option, size_t value) {
        chunk.write(opPSH, option);
        chunk.writeData(value);
    }

    /// peek value from stack
    void writePEEK(Register register, size_t offset) {
        chunk.write(opPEEK);
        chunk.writeData(register);
        chunk.writeData(offset);
    }

    /// Call Copper subroutine
    void writeCALL(size_t cuAddress) {
        chunk.write(opCALL);
        chunk.writeData(cuAddress);
    }

    /// Call Copper subroutine
    void writeCALL(string label) {
        chunk.write(opCALL);
        asLabel(label);
    }

    /// Call a D function
    void writeCALL(void* dptr) {
        chunk.write(opCALLDPTR);
        chunk.writeData(cast(size_t)dptr);
    }

    /// Return to caller
    void writeRET() {
        writeRET(0);
    }

    /// Return to caller
    void writeRET(size_t returnValues) {
        chunk.write(opRET);
        chunk.writeData(returnValues);
    }

    /// Halt execution
    void writeHALT() {
        chunk.write(opHALT);
    }

    /// print frame info
    void writeFRME() {
        chunk.write(opFRME);
    }

    void writeJMPG(OPCode opcode, string label) {
        chunk.write(opcode);
        asLabel(label);
    }

    void writeJMPG(OPCode opcode, size_t addr) {
        chunk.write(opcode);
        chunk.writeData(addr);
    }

    mixin writeJMPA!("JMP");
    mixin writeJMPA!("JZ");
    mixin writeJMPA!("JNZ");
    mixin writeJMPA!("JS");
    mixin writeJMPA!("JNS");
    mixin writeJMPA!("JC");
    mixin writeJMPA!("JNC");
    mixin writeJMPA!("JE");
    mixin writeJMPA!("JNE");
    mixin writeJMPA!("JA");
    mixin writeJMPA!("JAE");
    mixin writeJMPA!("JB");
    mixin writeJMPA!("JBE");

    /// Compare values of 2 registers
    void writeCMPRR(Register x, Register y) {
        chunk.write(opCMP, optRegister);
        chunk.writeData(x);
        chunk.writeData(y);
    }

    /// Compare values of 2 registers
    void writeCMPVR(size_t x, Register y) {
        chunk.write(opCMP, optValue1 | optRegister2);
        chunk.writeData(x);
        chunk.writeData(y);
    }

    /// Compare values of 2 registers
    void writeCMPRV(Register x, size_t y) {
        chunk.write(opCMP, optValue2 | optRegister1);
        chunk.writeData(x);
        chunk.writeData(y);
    }

    /// Compare values of 2 registers
    void writeCMPVV(size_t x, size_t y) {
        chunk.write(opCMP, optValue);
        chunk.writeData(x);
        chunk.writeData(y);
    }

    /// Load value to register from address
    void writeLDR(Register x, size_t address, ptrdiff_t addressOffset = 0) {
        chunk.write(opLDR);
        chunk.writeData(x);
        chunk.writeData(address);
        chunk.writeData(addressOffset);
    }

    /// Store value from register to address
    void writeSTR(Register x, size_t address, ptrdiff_t addressOffset = 0) {
        chunk.write(opSTR);
        chunk.writeData(x);
        chunk.writeData(address);
        chunk.writeData(addressOffset);
    }

    /// Store value from register to address
    void writeALLOCV(Register output, size_t length) {
        chunk.write(opSTR, optRegister1 | optValue2);
        chunk.writeData(output);
        chunk.writeData(length);
    }

    /// Store value from register to address
    void writeALLOCR(Register output, Register length) {
        chunk.write(opSTR, optRegister);
        chunk.writeData(output);
        chunk.writeData(length);
    }

    /// Move value from one register to another
    void writeMOV(Register x, Register y) {
        chunk.write(opMOV);
        chunk.writeData(x);
        chunk.writeData(y);
    }

    /// Move constant value to register X
    void writeMOVC(size_t value, Register x) {
        chunk.write(opMOVC);
        chunk.writeData(x);
        chunk.writeData(value);
    }

    /// Add value from X with value from Y, store in X.
    void writeADD(Register x, Register y) {
        chunk.write(opADD);
        chunk.writeData(x);
        chunk.writeData(y);
    }

    /// Subtract value from X with value from Y, store in X.
    void writeSUB(Register x, Register y) {
        chunk.write(opSUB);
        chunk.writeData(x);
        chunk.writeData(y);
    }

    /// Mulitply value in x, by value in y. Store in GP0 (and GP1 if needed)
    void writeMUL(Register x, Register y) {
        chunk.write(opMUL);
        chunk.writeData(x);
        chunk.writeData(y);
    }

    /// Divide values from register X with register Y, store in X
    void writeDIV(Register x, Register y) {
        chunk.write(opDIV);
        chunk.writeData(x);
        chunk.writeData(y);
    }

    override string toString() {
        import std.conv : text;
        build();
        return chunk.instr.text;
    }
}

public struct Chunk
{
private:
    void grow(size_t amount = 1)
    {
        if (capacity < count + amount)
        {
            // grow the array by a factor of 2.
            instr.length = capacity < 8 ? 8 : (capacity) * 2;
        }
    }

    void place(void* data, size_t at, size_t length) {
        instr[at..at+length] = (cast(ubyte*)data)[0..length];
        count += length;
    }

    void placeEnd(void* data, size_t length) {
        grow(length);
        place(data, count, length);
    }

    void write(OPCode code, Option options) {
        grow(Instr.sizeof);
        import std.format : format;
        writeln("#%04x".format(count), " -> ", getString(code), " (" ~ "%04x".format(options) ~ ")");
        Instr instr;
        instr.opcode = code;
        instr.options = options;
        placeEnd(&instr, Instr.sizeof);
    }

    void write(OPCode code) {
        write(code, 0);
    }

    void writeDataAt(T)(T data, size_t offset) {
        grow(size_t.sizeof);

        ChunkVal val = ChunkVal.constr(data);

        // Apply the value.
        instr[offset .. offset + val.as.ubyteArr.length] = val.as.ubyteArr;
    }

    void writeADDRPlaceholder() {
        writeData!ulong(0);
    }

    void writeData(T)(T data)
    {
        grow(size_t.sizeof);

        ChunkVal val = ChunkVal.constr(data);

        // Apply the value.
        instr[count .. count + val.as.ubyteArr.length] = val.as.ubyteArr;
        static if (!COMPRESS_CODE) count += 8;
        else count += T.sizeof;
    }
    
public:
    /// count of chunks
    size_t count;

    /// Instructions
    ubyte[] instr;

    this(size_t count, ubyte[] instr) {
        this.count = count;
        this.instr = instr;
    }

    ~this()
    {
        destroy(instr);
    }

    /// capacity
    size_t capacity()
    {
        return instr.length;
    }

    /// Gets the current position for use in labels
    size_t labelOffset() {
        return count;
    }

    void free()
    {
        destroy(instr);
    }

    string toString() {
        import std.format : format;
        string oStr;
        foreach(i; 0..count) {
            size_t offs = i;
            size_t offsLen = offs+1;

            ubyte val = (ValData.create(instr[offs..offsLen])).byte_;

            oStr ~= "%02x ".format(val);
        }
        return oStr;
    }
}
