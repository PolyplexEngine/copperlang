module cuvm.vm;
import cuvm.chunk;
import cuvm.opcodes;
import std.traits;
import cuvm.value;
import cuvm.stack;

enum VMStatus {
    OK,
    CompileError,
    RuntimeError
}

struct VM {
private:
    Stack!CuValue stack;

    CuValue strOP(CuValue b, CuValue a) {
        import std.format : format;
        CuValueType targetType = a.TYPE;
        if (!IS_TYPE_STRING(b.TYPE) && !IS_TYPE_CHAR(b.TYPE)) throw new Exception("Second operand is not a string appendable!");
        if (IS_TYPE_STRING(targetType)) {
            string av = AS_STRING(a.DATA[0], a.TYPE);
            string bv = AS_STRING(b.DATA[0], b.TYPE);
            return CuValue(av ~ bv, a.FLAGS, a.EXPOSED_TYPE);
        }
        return CuValue("");
    }

    CuValue binOP(string op)(CuValue b, CuValue a) {
        import std.format : format;

        CuValueType targetType = a.TYPE;
        if (!IS_TYPE_NUMERIC(b.TYPE)) throw new Exception("Second operand is not numeric!");

        if (IS_TYPE_SIGNED_INTERGRAL(targetType)) {
            int av = AS_SIGNED(a.DATA[0], a.TYPE);
            int bv = AS_SIGNED(b.DATA[0], b.TYPE);
            mixin(q{return CuValue(av %s bv, a.FLAGS, a.EXPOSED_TYPE);}.format(op));
        }

        if (IS_TYPE_UNSIGNED_INTERGRAL(targetType)) {
            int av = AS_UNSIGNED(a.DATA[0], a.TYPE);
            int bv = AS_UNSIGNED(b.DATA[0], b.TYPE);
            mixin(q{return CuValue(av %s bv, a.FLAGS, a.EXPOSED_TYPE);}.format(op));
        }

        if (IS_TYPE_FLOATING(targetType)) {
            float av = AS_FLOAT(a.DATA[0], a.TYPE);
            float bv = AS_FLOAT(b.DATA[0], b.TYPE);
            mixin(q{return CuValue(av %s bv, a.FLAGS, a.EXPOSED_TYPE);}.format(op));
        }

        if (IS_TYPE_DOUBLE(targetType)) {
            double av = AS_DOUBLE(a.DATA[0], a.TYPE);
            double bv = AS_DOUBLE(b.DATA[0], b.TYPE);
            mixin(q{return CuValue(av %s bv, a.FLAGS, a.EXPOSED_TYPE);}.format(op));
        }

        return CuValue(0, CuAccessorFlags.PTR, a.TYPE);
    }

    VMStatus run() {
        import std.stdio : writeln, writefln, write;
        while (true) {
            OpCode instr;
            switch(instr = this.read!ubyte()) {
                case opRETURN:
                    return VMStatus.OK;
                
                case opCONST:
                    stack.push(chunk.pool[this.read!size_t]);
                    break;
                
                case opNEGATE:
                    CuValue value = stack.pop();
                    if (IS_TYPE_SIGNED_INTERGRAL(value.TYPE) && value.DATA.length == 1) {
                        stack.push(CuValue(-value.DATA[0].INT, value.FLAGS, value.EXPOSED_TYPE));
                    } else {
                        return VMStatus.RuntimeError;
                    }
                    break;

                case opADD:
                    stack.push(binOP!("+")(stack.pop(), stack.pop()));
                    break;

                case opSUB:
                    stack.push(binOP!("-")(stack.pop(), stack.pop()));
                    break;

                case opMUL:
                    stack.push(binOP!("*")(stack.pop(), stack.pop()));
                    break;

                case opDIV:
                    stack.push(binOP!("/")(stack.pop(), stack.pop()));
                    break;

                case opMOD:
                    stack.push(binOP!("%")(stack.pop(), stack.pop()));
                    break;

                case opAPPEND:
                    stack.push(strOP(stack.pop(), stack.pop()));
                    break;

                case opPRINT:
                    CuValue value = stack.pop();
                    foreach(data; value.DATA) {
                        write(data.toString(value.TYPE));
                    }
                    write("\n");
                    break;
                
                case opSTK:
                    writeln(stack);
                    break;

                default: return VMStatus.RuntimeError;
            }
        }
    }

    T read(T)() if(isNumeric!T && !is(T : ubyte)) {
        import std.bitmanip : bigEndianToNative;
        scope(exit) ip += T.sizeof;
        return bigEndianToNative!T(ip[0..T.sizeof]);
    }

    ubyte read(T)() if(is(T : ubyte))  {
        return *ip++;
    }

public:
    Chunk* chunk;
    ubyte* ip;

    VMStatus execute(Chunk* chunk) {
        this.chunk = chunk;
        this.ip = chunk.code.ptr;
        stack.reset();
        return run();
    }
}