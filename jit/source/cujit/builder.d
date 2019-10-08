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
    CuState state;

    Node*[] funcsToScan;

private:
    CuModule buildRoot(Node* root) {
        CuModule module_ = new CuModule(state, scanModuleDecl(root.firstChild), root);
        scanImports(root.firstChild, module_);
        scanTypes(root.firstChild, module_);


        foreach(CuDecl decl; module_.weakDeclarations) {
            if (decl.type.typeKind == CuTypeKind.function_) {
                CuFuncBuildContext(cast(CuFunction)decl).build();
            }
        }

        // All declarations should be strong at this point.
        module_.weakDeclarations = [];
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
                funcsToScan ~= root;
            }

            // Go to next branch
            root = root.right;
        } while(root !is null);

        // After all other types are resolved, start scanning functions
        foreach(func; funcsToScan) {
            scanFunction(func, module_);
        }
        funcsToScan = [];
    }

    void scanFunction(Node* root, CuModule mod) {

        // The name of the function
        immutable(string) name = root.token.lexeme;
        CuDecl[] params;
        CuType returnType;
        
        Node* paramDefListOrAttrib = root.firstChild;
        params.length = paramDefList.childrenCount();
        if (paramDefList.firstChild !is null) {

            // Iterate through every parameter and build their type.
            Node* param = paramDefList.firstChild;
            size_t i = 0;
            do {
                CuDecl decl = nodeToParamDecl(param, mod);
                params[i++] = decl;
                param = param.right;
            } while (param !is null);
        }
        Node* bodyOrReturnType = paramDefList.right;
        if (bodyOrReturnType.id != astBody) {
            returnType = nodeToType(bodyOrReturnType);
            bodyOrReturnType = bodyOrReturnType.right;
        }
        
        CuFunction func = new CuFunction(mod, returnType, name, params);
        func.setBodyAST(bodyOrReturnType);
        mod.addWeakDeclaration(func);
    }

    CuDecl nodeToParamDecl(Node* node, CuModule mod) {
        return new CuDecl(mod, nodeToType(node.firstChild), node.token.lexeme);
    }

    CuType nodeToType(Node* node) {
        switch (node.token.id) {
            case tkArray:
                return createDynamicArray(nodeToType(node.firstChild));

            default:
                // If it's nothing of the above it's probably a type
                return createTypeFromName(state, node.token.lexeme);
        }
    }

    void buildFunction(CuFunction* func) {

        // Finally, build the body
        //buildFunctionBody(this, func.bodyAstNode, func);
    }

public:
    this(JITEngine engine) {
        this.engine = engine;
        this.state = new CuState();
    }

    /**
        Builds a copper module
    */
    CuModule build(string code) {
        import std.stdio : writeln;
        Node* ast = Parser(code).parse();
        writeln(ast.toString());
        return buildRoot(ast);
    }
}