module copper.lang.vm;
public import copper.lang.vm.vm;
public import copper.lang.vm.mem;
public import copper.lang.vm.stack;
public import copper.lang.vm.state;
public import copper.lang.arch;

/// Register data.
union GPRegData {

    /// A byte
    ubyte  byte_;

    /// A word
    ushort word;
    
    /// A double word
    uint   dword;

    /// A quad word
    ulong  qword;

    /// A ptr word
    size_t ptrword;

}

/// All the registers in the VM.
struct Registers {

    /// Initialize registers.
    void initialize() {

        // Initialize general-purpose registers.
        GPRegData init_;
        init_.qword = 0;
        gp = [init_, init_, init_, init_, init_, init_, init_, init_];
    }

    /// General Purpose Registers
    GPRegData[8] gp;

    ref GPRegData opIndex(Register reg) {
        Register regws = 0b00011111 & reg;
        if (regws >= regGP0 && regws <= regGP7) return gp[regws];
        throw new Exception("Invalid general-purpose register!");
    }

    /// Floating Point Register 0
    float fp0;

    /// Floating Point Register 1
    float fp1;

    /// Floating Point Register 2
    double fp2;

    /// Floating Point Register 3
    double fp3;

    /// Stack Pointer
    size_t esp;

    /// Flag Register
    Flag flg;

    /// Instruction pointer
    ubyte* ip;

    string toString() {
        import std.format : format;

        string outString = "";
        foreach(id, value; gp) {
            outString ~= format("GP%s: #%016x (hex)\n", id, value.qword);
        }
        outString ~= "\nfloating point\n";
        outString ~= format("FP0: #%08x         (hex)\n", fp0.floatToHexable);
        outString ~= format("FP1: #%08x         (hex)\n", fp1.floatToHexable);
        outString ~= format("FP2: #%016x (hex + highp)\n", fp2.doubleToHexable);
        outString ~= format("FP3: #%016x (hex + highp)\n", fp3.doubleToHexable);
        outString ~= "\nflags\n";
        outString ~= format("FLG:  %016b (binary)\n", flg);
        
        return outString;
    }
}

private uint floatToHexable(float val) {
    void* valST = cast(void*)&val;
    return *cast(uint*)valST;
}

private ulong doubleToHexable(double val) {
    void* valST = cast(void*)&val;
    return *cast(ulong*)valST;
}