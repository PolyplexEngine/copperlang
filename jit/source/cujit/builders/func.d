module cujit.builders.func;
import cujit.llb, cujit.cubuild, cujit.builder;
import cucore.node, cucore.ast, cucore.token;
import std.conv;
import dllvm;
import std.stdio;

/**
    A function build context
*/
struct CuFuncBuildContext {
private:
    CuFunction self;
    Node* ast;
    Builder builder;
    CuValue[string] allocatedStackVars;

    void buildBody(CuSection section) {
        builder.PositionAtStart(section.llvmBlock);
        Node* bodyleaf = ast.firstChild;

        // Allocate all variables on the stack
        foreach(name, param; self.parameters) {
            this.allocateStackVar(param.type, name, self.getParam(name));
        }

        // Start parsing the body
        if (bodyleaf !is null) {
            do {
                switch(bodyleaf.id) {
                    case astReturn:
                        buildRet(bodyleaf);
                        break;

                    case astDeclaration:
                        Node* nameNode = bodyleaf.firstChild;
                        Node* assignExpr = nameNode.firstChild;
                        CuType type = self.parentModule.findType(bodyleaf.token.lexeme);

                        // If there's no assignment expression, skip that part
                        if (assignExpr is null) {
                            this.allocateStackVar(type, nameNode.token.lexeme);
                            break;
                        }

                        this.allocateStackVar(type, nameNode.token.lexeme, buildExpression(assignExpr, type));
                        break;

                    case astAssignment:
                        CuValue value = allocatedStackVars[bodyleaf.token.lexeme];
                        Node* op = bodyleaf.firstChild;
                        switch(bodyleaf.token.id) {
                            case tkAddAssign:
                                buildAssign(value, buildBinOp("+", buildFetch(value, value.type), buildExpression(op, value.type), value.type));
                                break;
                            case tkSubAssign:
                                buildAssign(value, buildBinOp("-", buildFetch(value, value.type), buildExpression(op, value.type), value.type));
                                break;
                            case tkMulAssign:
                                buildAssign(value, buildBinOp("*", buildFetch(value, value.type), buildExpression(op, value.type), value.type));
                                break;
                            case tkDivAssign:
                                buildAssign(value, buildBinOp("/", buildFetch(value, value.type), buildExpression(op, value.type), value.type));
                                break;

                            default:
                                buildAssign(value, buildExpression(op, value.type));
                                break;
                        }
                        break;

                    default:
                        throw new Exception(bodyleaf.name ~ " is not implemented yet.");
                }

                // Go to next leaf
                bodyleaf = bodyleaf.right;
            } while (bodyleaf !is null);
        }

        // Automatically return void at end of void function
        if (self.returnType.typeKind == CuTypeKind.void_) {
            builder.BuildRetVoid();
        }
    }

    void buildRet(Node* idx) {
        if (idx.firstChild !is null) {
            CuValue exprVal = buildExpression(idx.firstChild, self.returnType);
            enforceTypeCompat(exprVal, self.returnType);
            builder.BuildRet(buildImplicitCast(exprVal, self.returnType).llvmValue);
            return;
        }

        // Return void if no expression provided
        if (self.returnType.typeKind != CuTypeKind.void_) {
            // TODO: proper exception
            throw new Exception("Cannot return void from a "~self.returnType.typeName~" function!");
        }
        builder.BuildRetVoid();
    }

    CuValue buildExpression(Node* op, CuType expectedType) {
        Node* lhsn = op.firstChild;
        Node* rhsn = op.lastChild;
        switch(op.token.id) {
            case tkAdd, tkSub, tkMul, tkDiv:
                CuValue lhs = buildExpression(lhsn, expectedType);
                CuValue rhs = buildExpression(rhsn, expectedType); 
                return buildBinOp(op.token.lexeme, lhs, rhs, expectedType);
            case tkAs:
                CuValue from = buildExpression(lhsn, expectedType);
                CuType to = self.parentModule.findType(rhsn.token.lexeme);
                return buildCast(from, to, expectedType);
            default: 
                return buildFetch(op, expectedType);
        }
    }

    void enforceTypeCompat(CuValue val, CuType expectedType) {
        // Verify that the types are compatible.
        if (!expectedType.isImplicitCompatibleWith(val.type)) {
            throw new Exception(val.name ~ " is not compatible with type "~expectedType.typeName);
        }
    }

    void enforceTypeCompat(CuValue lhs, CuValue rhs) {
        // Verify that the types are compatible.
        if (!lhs.type.isImplicitCompatibleWith(rhs.type)) {
            throw new Exception(lhs.name ~ " is not compatible with " ~ rhs.name);
        }
    }

    CuValue buildBinOp(string op, CuValue lhs, CuValue rhs, CuType expectedType) {
        enforceTypeCompat(lhs, rhs);

        rhs = buildImplicitCast(lhs, rhs);

        switch(op) {
            case "+":
                if (lhs.type.isIntegral) {
                    return new CuValue(lhs.type, builder.BuildAdd(lhs.llvmValue, rhs.llvmValue));
                } else if (lhs.type.isFloating) {
                    return new CuValue(lhs.type, builder.BuildFAdd(lhs.llvmValue, rhs.llvmValue));
                }
                return null;

            case "-":
                if (lhs.type.isIntegral) {
                    return new CuValue(lhs.type, builder.BuildSub(lhs.llvmValue, rhs.llvmValue));
                } else if (lhs.type.isFloating) {
                    return new CuValue(lhs.type, builder.BuildFSub(lhs.llvmValue, rhs.llvmValue));
                }
                return null;

            case "*":
                if (lhs.type.isIntegral) {
                    return new CuValue(lhs.type, builder.BuildMul(lhs.llvmValue, rhs.llvmValue));
                } else if (lhs.type.isFloating) {
                    return new CuValue(lhs.type, builder.BuildFMul(lhs.llvmValue, rhs.llvmValue));
                }
                return null;

            case "/":
                if (lhs.type.isIntegral) {
                    return new CuValue(lhs.type, builder.BuildSDiv(lhs.llvmValue, rhs.llvmValue));
                } else if (lhs.type.isFloating) {
                    return new CuValue(lhs.type, builder.BuildFDiv(lhs.llvmValue, rhs.llvmValue));
                }
                return null;

            default: throw new Exception("Unsupported operation of "~op~"!");
        }

    }

    CuValue buildImplicitCast(CuValue lhs, CuValue rhs) {
        return buildImplicitCast(rhs, lhs.type);
    }

    CuValue buildImplicitCast(CuValue from, CuType to) {
        // Implicit up-cast
        if (from.type.sizeOf <= to.sizeOf) {
            return buildSizeCast(from, to);
        }

        throw new Exception("Cannot down-cast type implictly, use 'as "~to.typeName~"' to down-cast.");
    }

    CuValue buildSizeCast(CuValue from, CuType to) {

        // They are the same type, skip casting.
        // Note this will break if you try to size cast between non-numeric types.
        if (from.type.typeKind == to.typeKind) return from;

        if (from.type.isFloating) {

            // It's essentially the same type, just change our interpretation
            if (from.type.sizeOf == to.sizeOf) {
                from.type = to;
                return from;
            }

            // LLVM should figure out if it's an up-cast or downcast automatically
            return new CuValue(to, builder.BuildFPCast(from.llvmValue, to.llvmType));
        }

        if (from.type.isIntegral) {

            // It's essentially the same type, just change our interpretation
            if (from.type.sizeOf == to.sizeOf) {
                from.type = to;
                return from;
            }

            // LLVM should figure out if it's an up-cast or downcast automatically
            return new CuValue(to, builder.BuildIntCast(from.llvmValue, to.llvmType, from.type.isSigned));
        }

        // Just act like it works
        return from;
        // throw new Exception("Unable to size cast type "~from.type.typeName~"!");
    }

    CuValue buildCast(CuValue from, CuType to, CuType expectedType) {
        
        if (to.isFloating()) {
            
            // Size casting
            if (from.type.isFloating()) return buildSizeCast(from, to);

            // float to int
            if (from.type.isIntegral()) {
                // Signed cast
                if (from.type.isSigned()) {
                    return new CuValue(to, builder.BuildSIToFP(from.llvmValue, to.llvmType));
                }

                // Unsigned cast
                return new CuValue(to, builder.BuildUIToFP(from.llvmValue, to.llvmType));
            }
        }

        if (to.isIntegral()) {

            // Size casting
            if (from.type.isIntegral()) return buildSizeCast(from, to);

            // int to float
            if (from.type.isFloating()) {

                // Signed cast
                if (to.isSigned()) {
                    return new CuValue(to, builder.BuildFPToSI(from.llvmValue, to.llvmType));
                }

                // Unsigned cast
                return new CuValue(to, builder.BuildFPToUI(from.llvmValue, to.llvmType));
            }
        }
        throw new Exception("Invalid cast from "~from.type.typeName ~ " to " ~ to.typeName);
    }

    /**
        Allocate stack variable with data
    */
    CuValue allocateStackVar(CuType type, string name, CuValue data) {
        CuValue stackAlloc = allocateStackVar(type, name);
        builder.BuildStore(data.llvmValue, stackAlloc.llvmValue);
        return stackAlloc;
    }

    /**
        Allocate stack variable
    */
    CuValue allocateStackVar(CuType type, string name) {
        Value stackAlloc = builder.BuildAlloca(type.llvmType, name);
        allocatedStackVars[name] = new CuValue(type, stackAlloc);
        return allocatedStackVars[name];
    }

    CuValue buildFetch(Node* val, CuType expectedType) {
        if (val.token.id == tkIdentifier) {
            CuValue addr = this.allocatedStackVars[val.token.lexeme];
            // Probably a variable
            return new CuValue(addr.type, builder.BuildLoad(addr.llvmValue, addr.name));
        }
        return buildLiteral(val, expectedType);
    }

    CuValue buildFetch(CuValue addr, CuType expectedType) {
        return new CuValue(addr.type, builder.BuildLoad(addr.llvmValue, addr.name));
    }

    void buildAssign(CuValue to, CuValue value) {
        builder.BuildStore(value.llvmValue, to.llvmValue);
    }

    CuValue buildLiteral(Node* val, CuType expectedType) {
        switch(val.token.id) {
            case tkIntLiteral:
                return constIntegral(expectedType, cast(ulong)(val.token.lexeme.to!long));
            case tkNumberLiteral:
                return constFloating(expectedType, val.token.lexeme.to!double);
            case tkStringLiteral, tkMultilineStringLiteral:
                // Cut out the quotes.
                string stringVal = val.token.lexeme[1..$-1];
                CuValue global = self.parentModule.addGlobalConstVar(createString(), constStringLiteral(stringVal));
                return constString(global, stringVal.sizeof);
            default: throw new Exception("Unsupported literal.");
        }
    }

public:
    /**
        Constructs a new building context
    */
    this(CuFunction self) {
        this.self = self;
    }

    /**
        Builds this function, result is automatically available inside the parent module
    
        Returns true if the build succeeded with no problems
    */
    bool build() {
        try {
            this.ast = self.bodyAST;
            builder = new Builder();
            buildBody(self.finalize());
        } catch (Exception ex) {
            // TODO: better error messages
            writefln("An error occured during compilation\nMessage: %s", ex.msg);
            return false;
        }
        return true;
    }
}