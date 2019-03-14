module copper.lang.compiler.chunk;
import copper.lang.arch;
import copper.lang.types;
import std.traits;
private struct AddrMap {
    size_t to;
    size_t[] maps;
}

public struct Chunk
{
private:
    size_t addressMappings;
    AddrMap[size_t] addressMap;

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

    size_t newAddrPtr(size_t to = -1) {
        addressMap[addressMappings++] = AddrMap(to, []);
        return addressMappings-1;
    }

    size_t newAddrPtr() {
        addressMap[addressMappings++] = AddrMap(count, []);
        return addressMappings-1;
    }

    void setAddrPtr(size_t map, size_t value) {
        addressMap[map].to = value;
    }

    void setAddrPtr(size_t map) {
        addressMap[map].to = count;
    }

    void addRef(size_t mapping, size_t position) {
        addressMap[mapping].maps ~= position;
    }

    void updateRefs() {
        foreach(mapping; addressMap) {
            foreach(address; mapping.maps) {
                writeDataAt(mapping.to, address);
            }
        }
    }

    /// capacity
    size_t capacity()
    {
        return instr.length;
    }

    void write(OPCode code, Option options) {
        grow(Instr.sizeof);
        Instr instr;
        instr.opcode = code;
        instr.options = options;
        placeEnd(&instr, Instr.sizeof);
    }

    void write(OPCode code) {
        grow(Instr.sizeof);
        Instr instr;
        instr.opcode = code;
        instr.options = 0;
        placeEnd(&instr, Instr.sizeof);
    }

    void writeDataAt(T)(T data, size_t offset) {
        grow(size_t.sizeof);

        ChunkVal val = ChunkVal.constr(data);

        // Apply the value.
        instr[offset .. offset + val.as.ubyteArr.length] = val.as.ubyteArr;
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
    
    /// Gets the current position for use in labels
    size_t labelOffset() {
        return count;
    }

    /// Pop values off stack
    void writePOP(size_t amount = 1) {
        write(opPOP);
        writeData(amount);
    }

    /// Push value to stack
    void writePSH(Register register) {
        write(opPSH);
        writeData(register);
    }

    /// peek value from stack
    void writePEEK(Register register, size_t offset) {
        write(opPEEK);
        writeData(register);
        writeData(offset);
    }

    /// Call Copper subroutine
    void writeCALL(size_t cuAddress) {
        write(opCALL);
        writeData(cuAddress);
    }

    /// Call a D function
    void writeCALL(void* dptr) {
        write(opCALLDPTR);
        writeData(cast(size_t)dptr);
    }

    /// Return to caller
    void writeRET() {
        write(opRET);
    }

    /// Jump to address
    void writeJMP(size_t address) {
        write(opJMP);
        addRef(address, count);
        writeData!size_t(0);
    }

    /// Jump to address if zero
    void writeJZ(size_t address) {
        write(opJZ);
        addRef(address, count);
        writeData!size_t(0);
    }

    /// Jump to address if not zero
    void writeJNZ(size_t address) {
        write(opJZ);
        addRef(address, count);
        writeData!size_t(0);
    }
    
    /// Jump to address if sign
    void writeJS(size_t address) {
        write(opJS);
        addRef(address, count);
        writeData!size_t(0);
    }
    
    /// Jump to address if not sign
    void writeJNS(size_t address) {
        write(opJNS);
        addRef(address, count);
        writeData!size_t(0);
    }
    
    /// Jump to address if carry
    void writeJC(size_t address) {
        write(opJC);
        addRef(address, count);
        writeData!size_t(0);
    }
    
    /// Jump to address if not carry
    void writeJNC(size_t address) {
        write(opJNC);
        addRef(address, count);
        writeData!size_t(0);
    }
    
    /// Jump to address if equal
    void writeJE(size_t address) {
        write(opJE);
        addRef(address, count);
        writeData!size_t(0);
    }
    
    /// Jump to address if not equal
    void writeJNE(size_t address) {
        write(opJNE);
        addRef(address, count);
        writeData!size_t(0);
    }
    
    /// Jump to address if above
    void writeJA(size_t address) {
        write(opJE);
        addRef(address, count);
        writeData!size_t(0);
    }
    
    /// Jump to address if above or equal
    void writeJAE(size_t address) {
        write(opJAE);
        addRef(address, count);
        writeData!size_t(0);
    }
    
    /// Jump to address if below
    void writeJB(size_t address) {
        write(opJB);
        addRef(address, count);
        writeData!size_t(0);
    }
    
    /// Jump to address if below or equal
    void writeJBE(size_t address) {
        write(opJBE);
        addRef(address, count);
        writeData!size_t(0);
    }

    /// Compare values of 2 registers
    void writeCMP(Register x, Register y) {
        write(opCMP);
        writeData(x);
        writeData(y);
    }

    /// Load value to register from address
    void writeLDR(Register x, size_t address, ptrdiff_t addressOffset = 0) {
        write(opLDR);
        writeData(x);
        writeData(address);
        writeData(addressOffset);
    }

    /// Store value from register to address
    void writeSTR(Register x, size_t address, ptrdiff_t addressOffset = 0) {
        write(opSTR);
        writeData(x);
        writeData(address);
        writeData(addressOffset);
    }

    /// Move value from one register to another
    void writeMOV(Register x, Register y) {
        write(opMOV);
        writeData(x);
        writeData(y);
    }

    /// Move constant value to register X
    void writeMOVC(size_t value, Register x) {
        write(opMOVC);
        writeData(x);
        writeData(value);
    }

    /// Add value from X with value from Y, store in X.
    void writeADD(Register x, Register y) {
        write(opADD);
        writeData(x);
        writeData(y);
    }

    /// Subtract value from X with value from Y, store in X.
    void writeSUB(Register x, Register y) {
        write(opSUB);
        writeData(x);
        writeData(y);
    }

    /// Mulitply value in x, by value in y. Store in GP0 (and GP1 if needed)
    void writeMUL(Register x, Register y) {
        write(opMUL);
        writeData(x);
        writeData(y);
    }

    /// Divide values from register X with register Y, store in X
    void writeDIV(Register x, Register y) {
        write(opDIV);
        writeData(x);
        writeData(y);
    }



    void free()
    {
        destroy(instr);
    }
}
