module copper.lang.compiler.vm.compiler;
import copper.lang.parser.node;
import copper.lang.compiler;
import copper.lang.compiler.vm.chunk;
import copper.lang.parser;
import copper.lang.vm;
import copper.lang.token;
import copper.share.utils;
import std.conv : to;

/// A compiler warning
class CompileWarning : Exception
{
public:
    this(string msg)
    {
        super(msg);
    }
}


class VMCompiler : Compiler
{
private:
    DynamicStack!(Scope*) scopes;
    TypeRegistry types;

    RegisterMap rmap;
    Declarations declarations;
    ChunkBuilder builder;
    string moduleName;
    size_t stackDepth;

    bool matchTypes(Node* type, string typeName) {
        return (type.token.lexeme == typeName);
    }

    bool matchTypes(Node* type, string typeName) {
        return (type.token.lexeme == typeName);
    }

    size_t packToSizeT(T)(T value)
    {
        void* valPtr = cast(void*)&value;
        return *cast(size_t*) valPtr;
    }

    size_t literalToNumeric(Node* node)
    {
        string lexeme = node.token.lexeme;
        switch (node.token.id)
        {
        case tkIntLiteral:
            return to!int(lexeme);
        case tkNumberLiteral:
            return packToSizeT!double(to!double(lexeme));
        case tkTrue:
            return packToSizeT!int(1);
        case tkFalse:
            return packToSizeT!int(0);
        default:
            throw new Exception("Cannot convert " ~ lexeme ~ " to a numeric");
        }
    }

    void module_(Node* node)
    {
        moduleName = getModuleName(node.firstChild);
        writeln(moduleName);
        moduleBody(node.right);
    }

    void moduleBody(Node* node)
    {
        if (node.id == astFunction)
        {
            functionDeclaration(node);
        }

        if (node.right !is null)
            moduleBody(node.right);
    }

    void functionDeclaration(Node* node)
    {
        FuncDecl funcDecl;
        funcDecl.name = node.token.lexeme;

        Scope* scope_ = new Scope();

        // Get the parameter list root
        Node* paramListRoot = node.firstChild;

        // Get the return type
        Node* returnType = paramListRoot.right.id == astReturnType ? paramListRoot.right : null;
        funcDecl.returnType = returnType !is null ? returnType.token.lexeme : "void";

        size_t stackDiff;

        // Iterate over parameters and add them
        if (paramListRoot.firstChild !is null)
        {
            Node* type = paramListRoot.firstChild;
            immutable(size_t) startStackdepth = stackDepth;
            do
            {
                if (type is null) break;
                Node* nameNode = type.firstChild;
                string name = nameNode.token.lexeme;

                /// Get some basic information about the type
                string typeName = type.token.lexeme;
                CuTypeInfo* basicInfo = types.getBasicInfo(typeName);
                size_t typeSize = basicInfo.size;

                // Fill out param for funcdecl and scope
                ParamDecl param = ParamDecl(stackDepth-startStackdepth, basicInfo, name);
                funcDecl.parameters ~= param;
                scope_.variables[name] = param;

                // TODO: move stack by proper size.
                writeln("arg ", name, " of size ", typeSize, " declared");
                stackDepth += typeSize;

                // Next type.
                type = type.right;
            }
            while (type !is null);
            writeln("Stack depth is now ", stackDepth, "; was ", startStackdepth, " diff of ", stackDepth-startStackdepth);
            stackDiff = stackDepth - startStackdepth;
        }

        // Push scope to scope stack
        scope_.stackDepth = stackDepth;
        scopes.push(scope_);

        // Set symbols, declaration mappings and compile the body.
        declarations.functions ~= funcDecl;
        builder.setSymbol(funcDecl.toString());
        stackDepth += size_t.sizeof;

        functionBody(returnType !is null ? returnType.right : paramListRoot.right);

        stackDepth -= stackDiff;

        scopes.pop();
    }

    void functionBody(Node* node)
    {
        scopeBody(node.firstChild);
    }

    void optimizeScope(Node* node)
    {
        do
        {
            if (node.id == astReturn)
            {

                // Remove dead nodes (nodes after a return in this scope)
                if (node.right !is null)
                {
                    warning("Unreachable code, will be optimized out!", node.right);
                    destroy(node.right);
                }
            }
            if (node.right is null)
                break;
            node = node.right;
        }
        while (node !is null);
    }

    void scopeBody(Node* node)
    {
        optimizeScope(node);
        do
        {
        sw:
            switch (node.id)
            {
            case astBranch:
                branch(node.firstChild);
                break sw;
            case astReturn:
                return_(node);
                break sw;
            default:
                error("Invalid statement!", node);
                return;
            }
            if (node.right is null)
                break;
            node = node.right;
        }
        while (node !is null);
    }

    void return_(Node* node)
    {
        // TODO: Type check return node.

        if (node.firstChild !is null)
        {
            expression(node.firstChild);
            builder.writeRET(8);
            return;
        }

        // It's a void return.
        builder.writeRET();
    }

    void branch(Node* node)
    {

    }

    void pushRegister(Register reg) {
        builder.writePSHR(reg);
        stackDepth += size_t.sizeof;
    }

    void pushValue(size_t value) {
        builder.writePSHV(value);
        stackDepth += size_t.sizeof;
    }

    void popValues(size_t size) {
        if (size != 0) {
            builder.writePOP(size);
            stackDepth -= size;
        }
    }

    void pushExprValue(Node* node)
    {
        if (node.token.id == tkIntLiteral || node.token.id == tkNumberLiteral
                || node.token.id == tkTrue || node.token.id == tkFalse)
        {

            // TODO: proper stackdepth handling
            stackDepth += size_t.sizeof;
            builder.writePSHV(literalToNumeric(node));
            return;
        }

        error("Invalid type for raw-value expression!", node);
        return;
    }

    void expression(Node* node)
    {

        // Optimize the expression by collapsing expression branches where possible
        optimizeExpression(node);

        // It's a negate expression
        if (node.token.id == tkSub && node.firstChild.right is null)
        {

            // TODO: proper stackdepth handling
            stackDepth += size_t.sizeof;
            Node* child = node.firstChild;
            builder.writePSHV(-literalToNumeric(child));
            return;
        }

        // It's a not expression
        if (node.token.id == tkNot && node.firstChild.right is null)
        {

            // TODO: proper stackdepth handling
            stackDepth += size_t.sizeof;
            // TODO: type checking + var get
            Node* child = node.firstChild;
            builder.writePSHV(!literalToNumeric(child));
            return;
        }

        // It's a single value expression
        if (node.firstChild is null)
        {
            // TODO: proper stackdepth handling
            stackDepth += size_t.sizeof;
            pushExprValue(node);
            return;
        }

        // It's a fullblown expression
        switch (node.token.id)
        {
        case tkAdd:
            addExpr(node);
            break;
        case tkSub:
            subExpr(node);
            break;
        case tkMul:
            mulExpr(node);
            break;
        case tkDiv:
            divExpr(node);
            break;
        default:
            error("Invalid operation!", node);
            return;
        }

    }

    size_t exprFetchTo(Node* node, Register reg, size_t offset = 0)
    {
        scope(exit) 
            builder.writeFRME();
        if (subxExpr(node))
        {
            builder.writePEEK(reg, offset);
            stackDepth += size_t.sizeof;
            return size_t.sizeof;
        }
        else
        {
            Scope* scope_ = scopes.peek();
            size_t sdepth = stackDepth - scope_.stackDepth;
            size_t actualDepth = sdepth + scope_.variables[node.token.lexeme].offset;
            builder.writePEEK(reg, actualDepth);
            return 0;
        }
    }

    bool subxExpr(Node* node)
    {
        if (node.id == astIdentifier)
            return false;

        if (node.id == astExpression || node.token.id == tkAdd
                || node.token.id == tkSub || node.token.id == tkMul || node.token.id == tkDiv)
        {
            expression(node);
            return true;
        }

        pushExprValue(node);
        return true;
    }

    void addExpr(Node* node)
    {
        size_t stackChange = exprFetchTo(node.firstChild, regGP0, size_t.sizeof);
        stackChange += exprFetchTo(node.lastChild, regGP1, stackChange > 0 ? stackChange : 0);
        builder.writeADD(regGP0, regGP1);
        popValues(stackChange);
        pushRegister(regGP0);
    }

    void subExpr(Node* node)
    {
        size_t stackChange = exprFetchTo(node.firstChild, regGP0, size_t.sizeof);
        stackChange += exprFetchTo(node.lastChild, regGP1, stackChange > 0 ? stackChange : 0);
        builder.writeSUB(regGP0, regGP1);
        popValues(stackChange);
        pushRegister(regGP0);
    }

    void mulExpr(Node* node)
    {
        size_t stackChange = exprFetchTo(node.firstChild, regGP0, size_t.sizeof);
        stackChange += exprFetchTo(node.lastChild, regGP1, stackChange > 0 ? stackChange : 0);
        builder.writeMUL(regGP0, regGP1);
        popValues(stackChange);
        pushRegister(regGP0);
    }

    void divExpr(Node* node)
    {
        size_t stackChange = exprFetchTo(node.firstChild, regGP0, size_t.sizeof);
        stackChange += exprFetchTo(node.lastChild, regGP1, stackChange > 0 ? stackChange : 0);
        builder.writeDIV(regGP0, regGP1);
        popValues(stackChange);
        pushRegister(regGP0);
    }

    /*void modExpr(Node* node) {
        subxExpr(node.firstChild);
        subxExpr(node.lastChild);
        builder.writePEEK(regGP0, size_t.sizeof);
        builder.writePEEK(regGP1, size_t.sizeof*2);
        builder.writeMOD(regGP0, regGP1);
        builder.writePOP(size_t.sizeof*2);
        builder.writePSHR(regGP0);
    }*/

    /// Optimizes an expression by pre-calculating values when possible.
    void optimizeExpression(Node* node)
    {

    }

    void parameterAccessFunc(Register target, FuncDecl func, string parameter)
    {
        size_t paramIndex = func.paramIndexOf(parameter);
        size_t paramCount = func.parameters.length;
        size_t paramOffset = paramCount - paramIndex;
        // Add 1 so that we skip the return pointer.
        builder.writePEEK(target, paramOffset + 1);
    }

    void constValueNumeric(Register target, size_t value)
    {
        builder.writeMOVC(value, target);
    }

public:
    override void compile(Node* node) {

    }

    CObject* compile(Node* node)
    {
        scopes = DynamicStack!(Scope*)([]);
        types = new TypeRegistry();
        builder = new ChunkBuilder();
        module_(node.firstChild);
        //builder.writeHALT();
        return builder.build();
    }
}
