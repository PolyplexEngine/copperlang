module cujit.builders.func;
import cujit.llb, cujit.cubuild, cujit.builder;
import cucore.node, cucore.ast, cucore.token, cucore;
import std.conv;
import dllvm;
import std.stdio;
import std.format;
import std.array;

/**
    A function build context
*/
class CuFuncBuildContext {
private:
    CuFunction self;
    Builder builder;
    CuSection[] scopes;

    void buildBody(Node* ast, CuSection section, bool handleReturn = true) {
        if (ast is null) return;
        builder.PositionAtStart(section.llvmBlock);
        Node* bodyleaf = ast.firstChild;

        // Allocate all variables on the stack
        foreach(name, param; self.parameters) {
            this.allocateStackVar(param.allocSpace, param.type, name, self.getParam(name));
        }

        // Start parsing the body
        if (bodyleaf !is null) {
            do {
                switch(bodyleaf.id) {
                    case astReturn:
                        buildRet(bodyleaf);
                        break;

                    case astFunctionCall:
                        buildFuncCall(bodyleaf, null);
                        break;

                    case astBranch:
                        buildBranch(bodyleaf);
                        break;

                    case astDeclaration:
                        Node* attribs = bodyleaf.firstChild;
                        Node* nameNode = attribs.right;
                        Node* assignExpr = nameNode.firstChild;
                        CuType type = self.parentModule.findType(bodyleaf.token.lexeme);

                        // If there's no assignment expression, skip that part
                        if (assignExpr is null) {
                            this.allocateStackVar(nameNode, type, nameNode.token.lexeme);
                            break;
                        }

                        this.allocateStackVar(nameNode, type, nameNode.token.lexeme, buildExpression(assignExpr, type));
                        break;

                    case astAssignment:
                        CuValue value = fetchVariableFromScopes(bodyleaf, bodyleaf.token.lexeme);
                        Node* op = bodyleaf.firstChild;
                        switch(bodyleaf.token.id) {
                            case tkAddAssign:
                                buildAssign(value, buildBinOp(bodyleaf, buildFetch(value, value.type), buildExpression(op, value.type), value.type));
                                break;

                            case tkSubAssign:
                                buildAssign(value, buildBinOp(bodyleaf, buildFetch(value, value.type), buildExpression(op, value.type), value.type));
                                break;

                            case tkMulAssign:
                                buildAssign(value, buildBinOp(bodyleaf, buildFetch(value, value.type), buildExpression(op, value.type), value.type));
                                break;

                            case tkDivAssign:
                                buildAssign(value, buildBinOp(bodyleaf, buildFetch(value, value.type), buildExpression(op, value.type), value.type));
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

        if (!handleReturn) return;

        // Automatically return void at end of void function
        if (self.returnType.typeKind == CuTypeKind.void_) {
            builder.BuildRetVoid();
        }
    }

    void buildRet(Node* idx) {
        if (idx.firstChild !is null) {
            CuValue exprVal = buildExpression(idx.firstChild, self.returnType);
            enforceTypeCompat(idx.firstChild, exprVal, self.returnType);
            builder.BuildRet(buildImplicitCast(idx.firstChild, exprVal, self.returnType).llvmValue);
            return;
        }

        // Return void if no expression provided
        if (self.returnType.typeKind != CuTypeKind.void_) {
            // TODO: proper exception
            throw new CompilationException(idx, "Cannot return void from a "~self.returnType.typeName~" function!");
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
                return buildBinOp(op, lhs, rhs, expectedType);

            case tkAs:
                CuValue from = buildExpression(lhsn, expectedType);
                CuType to = self.parentModule.findType(rhsn.token.lexeme);
                return buildCast(from, to, expectedType);

            case tkEqual, tkNotEqual, tkLessThan, tkLessThanOrEq, tkGreaterThan, tkGreaterThanOrEq, tkIs, tkNotIs:
                CuValue lhs = buildExpression(lhsn, expectedType);
                CuValue rhs = buildExpression(rhsn, expectedType);
                return buildCompare(op, lhs, rhs);

            default: 
                switch(op.id) {
                    
                    case astFunctionCall:
                        return buildFuncCall(op, expectedType);

                    default:
                        return buildFetch(op, expectedType);
                }
        }
    }

    void enforceTypeCompat(Node* node, CuValue val, CuType expectedType) {
        // Verify that the types are compatible.
        if (!expectedType.isImplicitCompatibleWith(val.type)) {
            throw new CompilationException(node, val.name ~ " is not compatible with type "~expectedType.typeName);
        }
    }

    void enforceTypeCompat(Node* node, CuValue lhs, CuValue rhs) {
        // Verify that the types are compatible.
        if (!lhs.type.isImplicitCompatibleWith(rhs.type)) {
            throw new CompilationException(node, lhs.name ~ " is not compatible with " ~ rhs.name);
        }
    }

    CuValue buildFuncCall(Node* funcNode, CuType expectedType) {
        CuFunction func = self.parentModule.findFunction(funcNode.name, []);
        if (func is null) throw new CompilationException(funcNode, "Function "~funcNode.name~" was not found!");
        Value[] vals;

        Node* valExpr = funcNode.firstChild.firstChild;
        int i = 0;
        while(valExpr !is null) {
            vals ~= buildExpression(valExpr, func.orderedParams[i].type).llvmValue;
            valExpr = valExpr.right;
            i++;
        }
        if (vals.length != func.orderedParams.length) {
            throw new CompilationException(funcNode, "Not enough arguments supplied to %s!".format(func.name));
        }

        // TODO: Fill in arguments
        return new CuValue(func.returnType, builder.BuildCall(func.llvmFunc, vals));
    }

    CuValue buildCompare(Node* opnode, CuValue lhs, CuValue rhs) {
        enforceTypeCompat(opnode, lhs, rhs);
        rhs = buildImplicitCast(opnode, lhs, rhs);
        
        switch(opnode.token.id) {
            
            // ==
            case tkEqual:
                if (lhs.type.isIntegral) {
                    return new CuValue(createBool(), builder.BuildICmp(IntPredicate.Equal, lhs.llvmValue, rhs.llvmValue));
                } else if (lhs.type.isFloating) {
                    return new CuValue(createBool(), builder.BuildFCmp(RealPredicate.UnorderedEqual, lhs.llvmValue, rhs.llvmValue));
                }
                throw new CompilationException(opnode, "Operation '%s' is not implemented for %s".format(opnode.token.lexeme, lhs.type.typeName));
            
            // !=
            case tkNotEqual:
                if (lhs.type.isIntegral) {
                    return new CuValue(createBool(), builder.BuildICmp(IntPredicate.NotEqual, lhs.llvmValue, rhs.llvmValue));
                } else if (lhs.type.isFloating) {
                    return new CuValue(createBool(), builder.BuildFCmp(RealPredicate.UnorderedNotEqual, lhs.llvmValue, rhs.llvmValue));
                }
                throw new CompilationException(opnode, "Operation '%s' is not implemented for %s".format(opnode.token.lexeme, lhs.type.typeName));
            
            // <
            case tkLessThan:
                if (lhs.type.isIntegral) {
                    return new CuValue(createBool(), builder.BuildICmp(lhs.type.isSigned ? IntPredicate.SignedLesser : IntPredicate.UnsignedLesser, lhs.llvmValue, rhs.llvmValue));
                } else if (lhs.type.isFloating) {
                    return new CuValue(createBool(), builder.BuildFCmp(RealPredicate.UnorderedLesser, lhs.llvmValue, rhs.llvmValue));
                }
                throw new CompilationException(opnode, "Operation '%s' is not implemented for %s".format(opnode.token.lexeme, lhs.type.typeName));
            
            // <=
            case tkLessThanOrEq:
                if (lhs.type.isIntegral) {
                    return new CuValue(createBool(), builder.BuildICmp(lhs.type.isSigned ? IntPredicate.SignedLesserEqual : IntPredicate.UnsignedLesserEqual, lhs.llvmValue, rhs.llvmValue));
                } else if (lhs.type.isFloating) {
                    return new CuValue(createBool(), builder.BuildFCmp(RealPredicate.UnorderedLesserEqual, lhs.llvmValue, rhs.llvmValue));
                }
                throw new CompilationException(opnode, "Operation '%s' is not implemented for %s".format(opnode.token.lexeme, lhs.type.typeName));
            
            // >
            case tkGreaterThan:
                if (lhs.type.isIntegral) {
                    return new CuValue(createBool(), builder.BuildICmp(lhs.type.isSigned ? IntPredicate.SignedGreater : IntPredicate.UnsignedGreater, lhs.llvmValue, rhs.llvmValue));
                } else if (lhs.type.isFloating) {
                    return new CuValue(createBool(), builder.BuildFCmp(RealPredicate.UnorderedGreater, lhs.llvmValue, rhs.llvmValue));
                }
                throw new CompilationException(opnode, "Operation '%s' is not implemented for %s".format(opnode.token.lexeme, lhs.type.typeName));
            
            // >=
            case tkGreaterThanOrEq:
                if (lhs.type.isIntegral) {
                    return new CuValue(createBool(), builder.BuildICmp(lhs.type.isSigned ? IntPredicate.SignedGreaterEqual : IntPredicate.UnsignedGreaterEqual, lhs.llvmValue, rhs.llvmValue));
                } else if (lhs.type.isFloating) {
                    return new CuValue(createBool(), builder.BuildFCmp(RealPredicate.UnorderedGreaterEqual, lhs.llvmValue, rhs.llvmValue));
                }
                throw new CompilationException(opnode, "Operation '%s' is not implemented for %s".format(opnode.token.lexeme, lhs.type.typeName));
            
            // UNKNOWN
            default:
                throw new CompilationException(opnode, "Operation '%s' is not implemented yet.".format(opnode.token.lexeme));
        }
    }

    CuValue buildBinOp(Node* opnode, CuValue lhs, CuValue rhs, CuType expectedType) {
        enforceTypeCompat(opnode, lhs, rhs);

        string op = opnode.token.lexeme;

        rhs = buildImplicitCast(opnode, lhs, rhs);

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

    CuValue buildImplicitCast(Node* node, CuValue lhs, CuValue rhs) {
        return buildImplicitCast(node, rhs, lhs.type);
    }

    CuValue buildImplicitCast(Node* node, CuValue from, CuType to) {
        // Implicit up-cast
        if (from.type.sizeOf <= to.sizeOf) {
            return buildSizeCast(from, to);
        }

        throw new CompilationException(node, "Cannot down-cast type implictly, use 'as "~to.typeName~"' to down-cast.");
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
    CuValue allocateStackVar(Node* allocRoot, CuType type, string name, CuValue data) {
        CuValue stackAlloc = allocateStackVar(allocRoot, type, name);
        builder.BuildStore(data.llvmValue, stackAlloc.llvmValue);
        return stackAlloc;
    }

    /**
        Allocate stack variable
    */
    CuValue allocateStackVar(Node* allocRoot, CuType type, string name) {
        enforceStackVarValidity(allocRoot, name);

        Value stackAlloc = builder.BuildAlloca(type.llvmType, name);
        scopes[$-1].allocatedStackVars[name] = new CuValue(type, stackAlloc);
        return scopes[$-1].allocatedStackVars[name];
    }

    CuValue buildFetch(Node* val, CuType expectedType) {
        if (val.token.id == tkIdentifier) {
            CuValue addr = fetchVariableFromScopes(val, val.token.lexeme);


            switch (addr.type.typeKind) {
                case CuTypeKind.dynamic_array, CuTypeKind.string_:
                    switch (val.firstChild.id) {
                        case astIdentifier:
                            if (val.firstChild.name == "length") return buildLengthFetch(addr);
                            throw new Exception("Invalid identifier for "~val.name);

                        case astParameters:

                            // TODO: allow multidmensional arrays and AAs
                            CuValue index = buildExpression(val.firstChild.firstChild, expectedType);
                            return buildArrayFetch(addr, index);

                        default:
                            throw new Exception("Malformed AST");
                    }
                
                default: 
                    break;
            }
            return new CuValue(addr.type, builder.BuildLoad(addr.llvmValue, addr.name));
        }
        return buildLiteral(val, expectedType);
    }

    CuValue buildFetch(CuValue addr, CuType expectedType) {
        return new CuValue(addr.type, builder.BuildLoad(addr.llvmValue, addr.name));
    }

    CuValue buildLengthFetch(CuValue array) {
        return new CuValue(
            createSizeT(),
            builder.BuildLoad(
                builder.BuildStructGEP(array.llvmValue, 0),
                array.name~".length"
            )
        );
    }

    CuValue buildArrayFetch(CuValue array, CuValue index) {
        CuDynArrayType type = cast(CuDynArrayType)array.type;

        // Dynamic arrays are a length followed by a pointer, this fetches the array from that struct
        CuValue arrayRoot = new CuValue(type.elementType, builder.BuildStructGEP(array.llvmValue, 1));

        return new CuValue(
            type.elementType,

            // Load the output value
            builder.BuildLoad(

                // Indexes the array with the defined value the expression evaluated to
                builder.BuildInboundsGEP(
                    
                    // Now load the array in so we can index it
                    builder.BuildLoad(arrayRoot.llvmValue, arrayRoot.name),
                    [index.llvmValue]
                ), 
                array.name
            )
        );
    }

    void buildBranch(Node* branchExpr) {
        Node* exprNode = branchExpr.firstChild;
        Node* thenNode = exprNode.right;
        Node* elseNode = thenNode.right;
        CuSection thenSection;
        CuSection elseSection;
        CuSection endSection;

        // destination if then falls through
        CuSection destSection;

        // Create sections
        thenSection = self.appendSection("%s_b_then".format(self.mangledName), scopes[$-1]);
        if (elseNode !is null) elseSection = self.appendSection("%s_b_else".format(self.mangledName), scopes[$-1]);
        endSection = self.appendCopySection("%s_b_end".format(self.mangledName), scopes[$-1]);

        destSection = elseSection !is null ? elseSection : endSection;

        // We pre-create the sections
        // TODO: else section

        // The expression
        CuValue matchExpr = buildExpression(exprNode, createBool());

        scopes ~= thenSection;
        buildBody(thenNode, scopes[$-1], false);
        builder.BuildBr(endSection.llvmBlock);
        scopes.length--;

        if (elseSection !is null) {
            scopes ~= elseSection;
            buildBody(elseNode, scopes[$-1], false);
            builder.BuildBr(endSection.llvmBlock);
            scopes.length--;
        }

        // First we make the actual branch
        builder.PositionAtEnd(scopes[$-1].llvmBlock);
        builder.BuildCondBr(matchExpr.llvmValue, thenSection.llvmBlock, destSection.llvmBlock);

        // Then we do a switcheroo and make the end block our new main block area.
        scopes[$-1] = endSection;
        builder.PositionAtStart(endSection.llvmBlock);
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
            case tkTrue:
                return constBool(true);
            case tkFalse:
                return constBool(false);
            case tkStringLiteral, tkMultilineStringLiteral:
                // Cut out the quotes.
                string stringVal = val.token.lexeme[1..$-1];

                // TODO: Handle escape sequences more gracefully
                CuValue global = self.parentModule.addGlobalConstVar(createString(), constStringLiteral(stringVal.replace("\\n", "\n")));
                return constString(global, stringVal.length);
            default: throw new Exception("Unsupported literal.");
        }
    }

    /// Enforce the validity of stack variable names
    void enforceStackVarValidity(Node* testOrigin, string name) {
        foreach_reverse(sc; scopes) {
            //if (name in sc.allocatedStackVars) throw new CompilationException(testOrigin, "Variable with name '%s' is already present in the current scope!".format(name));
        }
    }

    /// Fetch a variable from any of the current scopes
    CuValue fetchVariableFromScopes(Node* fetchFor, string name) {
        foreach_reverse(sc; scopes) {
            if (name in sc.allocatedStackVars) return sc.allocatedStackVars[name];
        }
        throw new CompilationException(fetchFor, "No variable %s in scope!".format(name));
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
        builder = new Builder();
        scopes ~= self.getSection("entry");
        buildBody(self.bodyAST, scopes[0]);
        return true;
    }
}