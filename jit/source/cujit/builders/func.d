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
    CuModule parentModule;
    CuDecl parent;
    CuFunction self;
    
    Node* ast;

public:
    /**
        Constructs a new building context
    */
    this(CuModule mod, CuFunction self, CuDecl parent = null) {
        this.parentModule = mod;
        this.parent = parent;
        this.self = self;
    }

    /**
        Builds this function, result is automatically available inside the parent module
    
        Returns true if the build succeeded with no problems
    */
    bool build(Node* astNode) {
        try {
            this.ast = astNode;
        } catch (Exception ex) {
            // TODO: better error messages
            writefln("An error occured during compilation\nMessage: %s", ex.msg);
            return false;
        }
        return true;
    }
}

// void buildFunctionBody(CuBuilder cbld, Node* ast, CuFunction* func) {
//     Builder builder = new Builder(Context.Global);
//     builder.PositionAtStart(func.getSection("entry"));

//     Function llvmF = func.llvmFunc();

//     Node* statements = ast.firstChild;

//     // Go through the body and compile all the statements
//     if (statements !is null) {
//         do {
//             switch(statements.id) {
//                 case astReturn:
//                     buildReturn(builder, statements, func);
//                     break;

//                 case astFunctionCall:
//                     buildFuncCallExpr(builder, statements, func);
//                     break;

//                 case astDeclaration:
//                     Node* nameNode = statements.firstChild;
//                     string declname = nameNode.token.lexeme;

//                     Type variableType = stringToBasicType(Context.Global, statements.token.lexeme);

//                     func.declareVariable(variableType, declname, builder.BuildAlloca(variableType, declname));
                    
//                     Value val = func.findVariableAddr(declname);
//                     Type type = func.findVariableType(declname);

//                     // If we also got assignment, do the assignment
//                     if (nameNode.firstChild !is null) {
//                         builder.BuildStore(buildExpr(builder, nameNode.firstChild, func, type), val);
//                     }
//                     break;
//                 case astAssignment:
//                     Value val = func.findVariableAddr(statements.token.lexeme);
//                     Type type = func.findVariableType(statements.token.lexeme);
//                     builder.BuildStore(buildExpr(builder, statements.firstChild, func, type), val);
//                     break;
//                 default: throw new Exception("Not implemented");
//             }

//             statements = statements.right;
//         } while(statements !is null);
//     }

//     // Automatically append a return void statement for void functions
//     if (func.llvmType.ReturnType.Kind == TypeKind.Void) {
//         builder.BuildRetVoid();   
//     }
// }

// /**
//     Builds a return statement
// */
// void buildReturn(Builder builder, Node* ast, CuFunction* func) {
    
//     // Void return if we have no return expression
//     if (ast.firstChild is null) {
//         builder.BuildRetVoid();
//     }

//     // Return with expression
//     builder.BuildRet(buildExpr(builder, ast.firstChild, func));
// }

// Value buildExpr(Builder builder, Node* ast, CuFunction* func, Type constType = null) {
//     switch(ast.token.id) {
//         case tkAdd:
//             return buildAdd(builder, ast, func, constType);

//         case tkSub:
//             return buildSub(builder, ast, func, constType);

//         case tkMul:
//             return buildMul(builder, ast, func, constType);

//         case tkDiv:
//             return buildDiv(builder, ast, func, constType);

//         case tkMod:
//             return buildDiv(builder, ast, func, constType);

//         case tkIdentifier:

//             // Function call expression
//             if (ast.id == astFunctionCall) {
//                 return buildFuncCallExpr(builder, ast, func);
//             }

//             return func.findValue(ast.token.lexeme, builder);

//         default:
//             // Constant expression
//             if (isConst(ast)) {
//                 return buildConst(builder, ast, func, constType);
//             }
//             throw new Exception("Invalid token or unimplemented!");
//     }
// }

// /**
//     Build add instruction
// */
// Value buildAdd(Builder builder, Node* ast, CuFunction* func, Type constType = null) {
//     Node* valANode = ast.firstChild;
//     Node* valBNode = ast.lastChild;
//     Value valA;
//     Value valB;

//     // lhs expr
//     if (valANode.id == astExpression || valBNode.id == astFunctionCall) {
//         valA = buildExpr(builder, valANode, func);
//     } else {
//         if (isConst(valANode)) valA = buildConst(builder, valANode, func, constType);
//         else valA = func.findValue(valANode.token.lexeme, builder);
//     }

//     // rhs expr
//     if (valBNode.id == astExpression || valBNode.id == astFunctionCall) {
//         valB = buildExpr(builder, valBNode, func);
//     } else {
//         if (isConst(valBNode)) valB = buildConst(builder, valBNode, func, constType);
//         else valB = func.findValue(valBNode.token.lexeme, builder);
//     }

//     // add
//     switch(valA.TypeOf.Kind) {
//         case TypeKind.Int:
//             return builder.BuildAdd(valA, valB);
//         case TypeKind.Float32, TypeKind.Float64:
//             return builder.BuildFAdd(valA, valB);
//         default: throw new Exception("Invalid operation");
//     }
// }

// /**
//     Build add instruction
// */
// Value buildSub(Builder builder, Node* ast, CuFunction* func, Type constType = null) {
//     Node* valANode = ast.firstChild;
//     Node* valBNode = ast.lastChild;
//     Value valA;
//     Value valB;

//     // lhs expr
//     if (valANode.id == astExpression || valBNode.id == astFunctionCall) {
//         valA = buildExpr(builder, valANode, func);
//     } else {
//         if (isConst(valANode)) valA = buildConst(builder, valANode, func, constType);
//         else valA = func.findValue(valANode.token.lexeme, builder);
//     }

//     // rhs expr
//     if (valBNode.id == astExpression || valBNode.id == astFunctionCall) {
//         valB = buildExpr(builder, valBNode, func);
//     } else {
//         if (isConst(valBNode)) valB = buildConst(builder, valBNode, func, constType);
//         else valB = func.findValue(valBNode.token.lexeme, builder);
//     }

//     // add
//     switch(valA.TypeOf.Kind) {
//         case TypeKind.Int:
//             return builder.BuildSub(valA, valB);
//         case TypeKind.Float32, TypeKind.Float64:
//             return builder.BuildFSub(valA, valB);
//         default: throw new Exception("Invalid operation");
//     }
// }

// /**
//     Build add instruction
// */
// Value buildMul(Builder builder, Node* ast, CuFunction* func, Type constType = null) {
//     Node* valANode = ast.firstChild;
//     Node* valBNode = ast.lastChild;
//     Value valA;
//     Value valB;

//     // lhs expr
//     if (valANode.id == astExpression || valBNode.id == astFunctionCall) {
//         valA = buildExpr(builder, valANode, func);
//     } else {
//         if (isConst(valANode)) valA = buildConst(builder, valANode, func, constType);
//         else valA = func.findValue(valANode.token.lexeme, builder);
//     }

//     // rhs expr
//     if (valBNode.id == astExpression || valBNode.id == astFunctionCall) {
//         valB = buildExpr(builder, valBNode, func);
//     } else {
//         if (isConst(valBNode)) valB = buildConst(builder, valBNode, func, constType);
//         else valB = func.findValue(valBNode.token.lexeme, builder);
//     }

//     // add
//     switch(valA.TypeOf.Kind) {
//         case TypeKind.Int:
//             return builder.BuildMul(valA, valB);
//         case TypeKind.Float32, TypeKind.Float64:
//             return builder.BuildFMul(valA, valB);
//         default: throw new Exception("Invalid operation");
//     }
// }

// /**
//     Build add instruction
// */
// Value buildDiv(Builder builder, Node* ast, CuFunction* func, Type constType = null) {
//     Node* valANode = ast.firstChild;
//     Node* valBNode = ast.lastChild;
//     Value valA;
//     Value valB;

//     // lhs expr
//     if (valANode.id == astExpression || valBNode.id == astFunctionCall) {
//         valA = buildExpr(builder, valANode, func);
//     } else {
//         if (isConst(valANode)) valA = buildConst(builder, valANode, func, constType);
//         else valA = func.findValue(valANode.token.lexeme, builder);
//     }

//     // rhs expr
//     if (valBNode.id == astExpression || valBNode.id == astFunctionCall) {
//         valB = buildExpr(builder, valBNode, func);
//     } else {
//         if (isConst(valBNode)) valB = buildConst(builder, valBNode, func, constType);
//         else valB = func.findValue(valBNode.token.lexeme, builder);
//     }

//     // add
//     switch(valA.TypeOf.Kind) {
//         case TypeKind.Int:
//             return builder.BuildSDiv(valA, valB);
//         case TypeKind.Float32, TypeKind.Float64:
//             return builder.BuildFDiv(valA, valB);
//         default: throw new Exception("Invalid operation");
//     }
// }

// /**
//     Build add instruction
// */
// Value buildMod(Builder builder, Node* ast, CuFunction* func, Type constType = null) {
//     Node* valANode = ast.firstChild;
//     Node* valBNode = ast.lastChild;
//     Value valA;
//     Value valB;

//     // lhs expr
//     if (valANode.id == astExpression || valBNode.id == astFunctionCall) {
//         valA = buildExpr(builder, valANode, func);
//     } else {
//         if (isConst(valANode)) valA = buildConst(builder, valANode, func, constType);
//         else valA = func.findValue(valANode.token.lexeme, builder);
//     }

//     // rhs expr
//     if (valBNode.id == astExpression || valBNode.id == astFunctionCall) {
//         valB = buildExpr(builder, valBNode, func);
//     } else {
//         if (isConst(valBNode)) valB = buildConst(builder, valBNode, func, constType);
//         else valB = func.findValue(valBNode.token.lexeme, builder);
//     }

//     // add
//     switch(valA.TypeOf.Kind) {
//         case TypeKind.Int:
//             return builder.BuildSRem(valA, valB);
//         default: throw new Exception("Can't get the remainder of a float value");
//     }
// }

// Value buildFuncCallExpr(Builder builder, Node* ast, CuFunction* func) {
//     string funcToCall = ast.token.lexeme;

//     Value[] paramOut;

//     Node* params = ast.firstChild;
//     if (params.firstChild !is null) {
//         uint i = 0;
//         params = params.firstChild;
//         do {
//             paramOut ~= buildExpr(builder, params, func);
//             i++;
//             params = params.right;
//         } while (params !is null);
//     }

//     Function otherFunc = func.findFunction(funcToCall, paramOut);
//     return builder.BuildCall(otherFunc, paramOut);
// }

// /**
//     Returns true if the node leaf is a constant value
// */
// bool isConst(Node* ast) {
//     return (ast.token.id == tkIntLiteral || ast.token.id == tkNumberLiteral);
// }

// Value buildConst(Builder builder, Node* ast, CuFunction* func, Type constType = null) {
//     Context ctx = Context.Global;

//     switch(ast.token.id) {
//         case tkIntLiteral:
//             return new ConstInt(constType !is null ? constType : ctx.CreateInt64(), ast.token.lexeme, 10);
//         case tkNumberLiteral:
//             return new ConstReal(constType !is null ? constType : ctx.CreateFloat32(), ast.token.lexeme.to!float);
//         case tkNullLiteral:
//             return new Null(constType !is null ? constType : ctx.CreateInt32());

//         default: throw new Exception("Not a constant value!");
//     }
// }