module cujit.builder;
import cujit.cubuild;
import cuparser.parser;
import cucore.node;
import cucore.ast;
import cucore.token;
import cujit;
import dllvm;
import cujit.llb;
import std.stdio;
import cujit.builders;

/**
    Compiles Copper code
*/
class CuBuilder {
package(cujit):
    Builder builder;
    JITEngine engine;

private:
    CuModule buildRoot(Node* root) {
        CuModule module_ = new CuModule(scanModuleDecl(root.firstChild), root);
        scanImports(root.firstChild, module_);
        scanTypes(root.firstChild, module_);

        // foreach(CuFunction globalFunc; module_.globalFunctions) {
        //     buildFunction(globalFunc);
        // }
        return module_;
    }

    // Converts a identifier tree in to a string joined by '.'
    string idenLeavesToModule(Node* start) {
        import std.array : join;
        string[] idenList;
        do {
            idenList ~= start.name;
            start = start.firstChild;
        } while (start !is null);
        return idenList.join(".");
    }

    string scanModuleDecl(Node* root) {
        do {
            
            if (root.id == astDeclaration && root.token.id == tkModule) {
                return idenLeavesToModule(root.firstChild);
            }

            // Go to next branch
            root = root.right;
        } while(root !is null);
        throw new Exception("No module name declared!");
    }

    void scanImports(Node* root, CuModule module_) {
        do {

            if (root.token.id == tkImport) {
                module_.addImport(idenLeavesToModule(root.firstChild));
            }

            // Go to next branch
            root = root.right;
        } while(root !is null);
    }

    void scanTypes(Node* root, CuModule module_) {
       do {

            if (root.id == astFunction) {
                //scanFunction(root, module_.addFunction(root, Visibility.Global, FuncKind.Global, root.token.lexeme));
            }

            // Go to next branch
            root = root.right;
        } while(root !is null);
    }

    void scanFunction(Node* root, CuFunction func) {
        // Type returnType;
        // Type[] paramTypes;
        // // LLVM Types and copper types are expressed differently
        // string[] paramCuTypes;

        // FuncType funcType;
        // Function funcInst;

        // Node* body;        

        // /// Scan parameters
        // Node* paramdefList = root.firstChild;
        // Node* param = paramdefList.firstChild;
        // if (param !is null) {
        //     do {
        //         string paramType = param.token.lexeme;
        //         string paramName = param.firstChild.token.lexeme;

        //         func.addParam(paramName);
        //         paramTypes ~= stringToBasicType(Context.Global, paramType);
        //         paramCuTypes ~= paramType;

        //         param = param.right;
        //     } while(param !is null);
        // }

        // /// Scan return type
        // Node* retType = paramdefList.right;
        // if (retType.id != astBody) {

        //     // We have a return type, set it
        //     returnType = stringToBasicType(Context.Global, retType.token.lexeme);
        //     body = retType.right;
        // } else {
        //     returnType = stringToBasicType(Context.Global, "void");
        //     body = retType;
        // }

        // // Do the magic that turns this in to an LLVM function
        // funcType = Context.Global.CreateFunction(returnType, paramTypes, false);
        // funcInst = new Function(func.llvmModule, funcType, func.mangleFunc(paramCuTypes));
        // func.finish(funcType, funcInst);
        // func.addSection("entry", funcInst.AppendEntryBlock());
        // func.assignBody(body);
    }

    void buildFunction(CuFunction* func) {

        // Finally, build the body
        //buildFunctionBody(this, func.bodyAstNode, func);
    }

public:
    this(JITEngine engine) {
        this.engine = engine;
    }

    /**
        Builds a copper module
    */
    CuModule build(string code) {
        import std.stdio : writeln;
        Node* ast = Parser(code).parse();
        return buildRoot(ast);
    }
}