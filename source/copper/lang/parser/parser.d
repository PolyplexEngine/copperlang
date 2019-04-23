module copper.lang.parser.parser;
import copper.lang;
import std.conv;
import std.format;
import copper.lang.lexer;
import std.stdio;
import copper.share.utils.strutils;

public:
/*
    Parses code from tokens to an extended AST.
    Also reads type mappings for use in the type analysis.
*/
struct Parser {
private:
    Token prevToken;
    Token curToken;
    Lexer lexer;
    bool doSkipComments;

    TypeMapping mapping;

    void getToken(Token* token, string func = __PRETTY_FUNCTION__) {
        prevToken = curToken;
        if (token is null) {
            lexer.scanToken(&curToken);
            return;
        }
        lexer.scanToken(token);
        string tk = token.lexeme ~ " @" ~ token.line.text ~ " " ~ token.pos.text;
        //writeln(tk, "\n", func.offsetBy(tk.length), "\n");
        curToken = *token;
    }

    void rewindTo(Token* token) {
        lexer.rewindTo(token);
    }

    void peekNext(Token* token, string func = __PRETTY_FUNCTION__) {
        lexer.peekNext(token);
        string tk = token.lexeme ~ " @" ~ token.line.text ~ " " ~ token.pos.text;
        //writeln(tk, "\n", func.offsetBy(tk.length), "\n");
    }

    Token previous() {
        return prevToken;
    }

    Token peek() {
        Token tk;
        lexer.peekNext(&tk);
        return tk;
    }

    bool check(Token tk, TokenId tkId) {
        if (eof) return false;
        return tk.id == tkId;
    }

    bool eof() {
        return lexer.eof;
    }

    bool leof() {
        return lexer.leof;
    }

    bool match(Token tk, TokenId[] vars) {
        foreach(tkx; vars) {
            if (check(tk, tkx)) {
                return true;
            }
        }
        return false;
    }

    void error(string errMsg, Token* tkRef = null) {
        if (tkRef is null) {
            Token tk;
            peekNext(&tk);
            throw new Exception(getOutText(lexer.getSource, tk, errMsg));
        }
        throw new Exception(getOutText(lexer.getSource, *tkRef, errMsg));
    }

    // impl
    Token consume(TokenId type, string errMsg, Token* tkRef = null, string funcCaller = __PRETTY_FUNCTION__) {
        Token tk;
        peekNext(&tk, funcCaller~" <consuming>");
        
        if (check(tk, type)) {
            getToken(&tk, funcCaller~" <consumed>");
            // Consume token
            return tk;
        }
        error(errMsg, tkRef !is null ? tkRef : &tk);
        return tk;
    }

    Node* comment() {
        Token tk;
        getToken(&tk);
        writeln(tk.toString);
        return new Node(tk);
    }

    void addType(Token basedOn, TypeId id) {
        import std.algorithm.searching : canFind;
        if (mapping.hasType(basedOn)) {
            error("Type with name "~basedOn.lexeme~" already exists in "~mapping.mod~"!", &basedOn);
        }
        mapping.add(RoughType(id, basedOn.lexeme));
        writeln("Added type of ", basedOn.lexeme, "...");
    }

    void updateType(Token* tk) {
        if (match(*tk, [tkIdentifier])) {
            if (mapping.hasType(*tk)) {
                if (mapping.get(*tk).typeId == tpClass) {
                    tk.id = tkClass;
                }
                if (mapping.get(*tk).typeId == tpStruct) {
                    tk.id = tkStruct;
                }
            }
        }
    }

    void skipComments() {
        Token tk;
        getToken(&tk);
        while (match(tk, [tkCommentDoc, tkCommentMulti, tkCommentSingle])) {
            getToken(&tk);
        }
        rewindTo(&tk);
    }

    /*
                                    Type scanning
    */

    bool isVarDecl() {
        Token tk;
        peekNext(&tk);

        if (isType(tk)) return true;
        return false;
    }

    void skipNonTypes() {
        Token tk;
        getToken(&tk);
        // Skip ahead till any of the useful tokens are seen.
        // Or if none are found continue where left off.
        while (!match(tk, [tkClass, tkModule, tkStruct]) && !eof) {
            getToken(&tk);
        }
        // If not end of file, we've reached a point of interrest.
        if (!eof) rewindTo(&tk);
    }

    void skipToStatementEnd(Token tk) {
        while(!match(tk, [tkEndStatement])) getToken(&tk);
    }

    void scanModule() {
        scope(exit) consume(tkEndStatement, "Expected end statement for module");
        consume(tkModule, "Expected module definition");
        string mod = "";
        
        // Get identifier chain for module
        Node* iden = identifierNoFunction();
        mod = iden.token.lexeme;
        if (iden.childrenCount > 0) {
            Node* visitor = iden.firstChild;
            while (visitor !is null) {
                mod ~= "."~visitor.token.lexeme;
                visitor = visitor.firstChild;
            }
        }
        mapping.mod = mod;
    }

    void scanRoot() {
        Token rootToken;
        peekNext(&rootToken);
        
        skipNonTypes();
        Token tk;
        getToken(&tk);
        while(!eof) {
            if (match(tk, [tkModule])) {
                rewindTo(&tk);
                scanModule();
            } else if (match(tk, [tkStruct])) {
                rewindTo(&tk);
                scanStruct();
            } else if (match(tk, [tkClass])) {
                rewindTo(&tk);
                scanClass();
            }
            skipNonTypes();
            getToken(&tk);
        }


        // Revert back to root token to start proper parsing
        rewindTo(&rootToken);
    }

    void scanClass() {
        Token name;
        Token tk;
        consume(tkClass, "Expected class definition");

        getToken(&name);
        getToken(&tk);
        addType(name, tpClass);

        while (!match(tk, [tkStartScope, tkEndStatement]) && !eof) {
            getToken(&tk);
        }
        if (match(tk, [tkStartScope])) skipBody();
    }

    void scanStruct() {
        Token name;
        Token tk;
        consume(tkStruct, "Expected struct definition");

        getToken(&name);
        getToken(&tk);
        addType(name, tpStruct);

        while (!match(tk, [tkStartScope, tkEndStatement]) && !eof) {
            getToken(&tk);
        }
        if (match(tk, [tkStartScope])) skipBody();
    }
    
    void skipBody() {
        Token tk;
        getToken(&tk);
        int offset = 1;
        while (offset > 0) {
            if (match(tk, [tkStartScope])) offset++;
            if (match(tk, [tkEndScope])) offset--;
            if (eof) break;
            getToken(&tk);
        }
        rewindTo(&tk);
    }

    /*
                                    Declaration
    */
    Node* module_() {
        // Skip any comments before the module declaration
        skipComments();
        Node* modNode = new Node(astModule);
        Token tk;
        peekNext(&tk);

        /// Get the module declaration if any
        if (match(tk, [tkModule])) {
            modNode.add(moduleDeclaration());
        }

        // Get imports and statements afterwards.
        while (!eof) {
            peekNext(&tk);
            if (match(tk, [tkModule])) {
                error("Module declaration must be the first declaration in the file!");
            }

            if (match(tk, [tkImport])) {
                modNode.add(importStatement());
                continue;
            }
            modNode.add(declaration());
        }

        return modNode;
    }


    Node* declaration(bool isTopLevel = true, bool isStruct = false) {
        Token tk;
        peekNext(&tk);

        // If done with file, return now.
        if (eof) return null;

        if (match(tk, [tkCommentDoc, tkCommentMulti, tkCommentSingle])) {
            return comment();
        }

        if (isType(tk) || match(tk, [tkExternalDeclaration, tkGlobal, tkLocal, tkFunction, tkStruct, tkClass, tkThis, tkMeta])) {
            return preDecl(isTopLevel, isStruct);
        }

        if (match(tk, [tkEndStatement])) {
            error("Unexpected ';'!");
        }

        error("Statements can't be executed in module space. Put statements in functions.");
        return null;
    }

    bool hasBeenDeclared = false;
    Node* moduleDeclaration() {
        Node* n = new Node(astDeclaration);

        // Make sure there's only 1 module declaration.
        if (hasBeenDeclared) {
            error("Module can only be declared once!");
        }

        hasBeenDeclared = true;

        // Keep token for error reporting.
        Token tk;
        peekNext(&tk);
        
        Token mod = consume(tkModule, "Expected module statement!");
        Node* iden = identifierNoFunction();
        
        scope (exit) consume(tkEndStatement, "Expected ';' to end module statement", &tk);

        // Return declaration.
        n.add(iden);
        n.token = mod;
        return n;
    }

    /*
        Functions
    */
    Node* funcDecl(bool isMeta) {
        Node* n;
        Token tk;

        // Make sure we're actually in a function.
        if (isMeta) {
            n = new Node(astMetaFunction);
            consume(tkMeta, "Expected 'meta'!");
        } else {
            n = new Node(astFunction);
            consume(tkFunction, "Expected 'func'!");
        }
        n.token = consume(tkIdentifier, "Expected function name!");
         

        // add parameters
        n.add(paramlist());
        
        Node* typ = type();
        if (typ !is null) {
            typ.id = astReturnType;
            n.add(typ);
        }
        // add body
        n.add(funcBody());

        consume(tkEndScope, "Expected '}' to end function scope!");

        // return function
        return n;
    }

    Node* constructorDecl() {
        Node* n;
        Token tk;

        n = new Node(astConstructor);
        consume(tkThis, "Expected 'this'!");

        // add parameters
        n.add(paramlist());

        // add body
        n.add(funcBody());

        consume(tkEndScope, "Expected '}' to end constructor scope!");

        // return function
        return n;
    }

    // TODO: merge this with scopeBody and come up with a better name?
    Node* funcBody() {

        Token tk;
        peekNext(&tk);
        
        Node* n = new Node(lexer.mkToken(), astBody);

        consume(tkStartScope, "Expected '{' to start function!");
        getToken(&tk);
        while (!match(tk, [tkEndScope]) && !eof) {
            rewindTo(&tk);
            n.add(bodyDeclaration());
            getToken(&tk);
        }
        rewindTo(&tk);

        if (eof) error("Function body not closed!");
        return n;
    }

    // generic body
    Node* scopeBody() {
        Token tk;
        peekNext(&tk);
        
        Node* n = new Node(lexer.mkToken(), astBody);

        consume(tkStartScope, "Expected '{' to start body!");
        getToken(&tk);
        while (!match(tk, [tkEndScope]) && !eof) {
            rewindTo(&tk);
            n.add(bodyDeclaration());
            getToken(&tk);
        }

        if (eof) error("Body not closed!");
        return n;
    }

    // generic body
    Node* declBody(bool isStruct) {
        Token tk;
        peekNext(&tk);
        
        Node* n = new Node(lexer.mkToken(), astBody);

        consume(tkStartScope, "Expected '{' to start body!");
        while (true) {
            peekNext(&tk);

            writeln(tk);
            if (match(tk, [tkEndScope])) {
                consume(tkEndScope, "Expected '}' to close body!");
                return n;
            }
            if (eof) break;

            n.add(declaration(false, isStruct));
        }

        // Bodu was not closed.
        error("Body not closed!");
        return null;
    }

    /*
        Body
    */
    Node* bodyDeclaration() {
        return statement();
    }

    /*
        Block of functions and variables
    */
    Node* classDeclaration() {
        Node* root = new Node(astClass);
        Node* injects;
        Node* bod;
        consume(tkClass, "Expected 'class'");
        Token name = consume(tkIdentifier, "Expected name");
        Token tk;
        peekNext(&tk);
        if (match(tk, [tkColon])) {
            injects = classExt();
        }
        bod = declBody(false);
        root.add(new Node(name));
        root.add(injects);
        root.add(bod);
        return root;
    }

    Node* structDeclaration() {
        Node* root = new Node(astStruct);
        Node* injects;
        Node* bod;
        consume(tkStruct, "Expected 'struct'");
        Token name = consume(tkIdentifier, "Expected name");
        Token tk;
        peekNext(&tk);
        if (match(tk, [tkLessThan])) {
            injects = structInject();
        }
        bod = declBody(true);
        root.add(new Node(name));
        root.add(injects);
        root.add(bod);
        return root;
    }

    Node* classExt() {
        Node* inj = new Node(astExtension);
        consume(tkColon, "Expected ':'!");
        Node* injName = identifierNoFunction();
        inj.add(injName);
        return inj;
    }

    Node* structInject() {
        Node* inj = new Node(astInjection);
        consume(tkLessThan, "Expected '<'!");
        Node* injName = identifierNoFunction();
        inj.add(injName);
        return inj;
    }  

    Node* preDecl(bool isTopLevel = false, bool isStruct = false) {
        Token tk;
        getToken(&tk);
        if (match(tk, [tkGlobal, tkLocal])) {
            Node* xdecl = decl(isTopLevel, isStruct);

            Token tk2;
            peekNext(&tk2);

            // exdecl, but for access-attribute versions
            if (match(tk2, [tkExternalDeclaration])) {
                xdecl.addStart(new Node(tk2, astAttribute));
                getToken(&tk2);
            }
            xdecl.addStart(new Node(tk, astAttribute));
            return xdecl;
        }

        // exdecl, but for non-access attribute versions
        if (match(tk, [tkExternalDeclaration])) {
            Node* xdecl = decl(isTopLevel, isStruct);
            xdecl.addStart(new Node(tk, astAttribute));
            return xdecl;
        }
        rewindTo(&tk);
        return decl(isTopLevel, isStruct);
    }

    Node* decl(bool isTopLevel = false, bool isStruct = false) {
        Token tk;
        peekNext(&tk);
        if (match(tk, [tkFunction])) return funcDecl(false);

        // TODO: Limit to only 1 depth level of structs/classes?
        if (match(tk, [tkStruct])) return structDeclaration();
        if (match(tk, [tkClass])) return classDeclaration();

        // Constructor & Meta function
        if (!isTopLevel && match(tk, [tkThis])) return constructorDecl();
        if (!isTopLevel && match(tk, [tkMeta])) return funcDecl(true);
        return varDecl();
    }

    Node* varDecl() {

        Node* root;
        // Get type for var decl
        Token type;
        Token name;

        // Get type of declaration
        peekNext(&type);
        if (mapping.hasType(type)) updateType(&type);

        if (!isType(type)) {
            error("Expected type defintion!");
        }
        
        root = this.type();

        // Get name of declaration
        name = consume(tkIdentifier, "Expected variable name");

        // Check for expression.
        Node* decl;
        Token tk;
        getToken(&tk);
        if (match(tk, [tkAssign, tkAddAssign, tkSubAssign, tkDivAssign, tkMulAssign])) {
            decl = expression();
        } else {
            rewindTo(&tk);
        }

        // The node for the assignment.
        Node* assignNode = new Node(name);
        assignNode.add(decl);

        // Consume statement end. (move this elsewhere?)
        consume(tkEndStatement, "Expected ';' after var declaration.");

        // Return the declaration
        root.add(assignNode);
        root.id = astDeclaration;
        return root;
    }
    /*
                                    Misc
    */

    Node* type() {
        Token tk;
        Token tk2;
        getToken(&tk);
        if (isType(tk)) {
            // Array handling
            getToken(&tk2);
            if (match(tk2, [tkOpenBracket])) {
                Token brck = tk2;
                tk2 = consume(tkCloseBracket, "Invalid array type specification!");
                brck.length++;
                brck.id = tkArray;
                Node* arrNode = new Node(brck);
                arrNode.add(new Node(tk));
                return arrNode;
            }
            rewindTo(&tk2);
            return new Node(tk);
        }
        rewindTo(&tk);
        return null;
    }

    bool isType(Token tk) {
        return (match(tk, [
            tkAny,
            tkUByte,
            tkUShort,
            tkUInt,
            tkULong,
            tkByte,
            tkShort,
            tkInt,
            tkLong,
            tkFloat,
            tkDouble,
            tkString,
            tkChar,
            tkPtr
        ]) || mapping.hasType(tk) || match(tk, [tkIdentifier]));
    }

    /*
                                    Statements
    */

    Node* statement() {

        Token tk;
        Token tk2;
        getToken(&tk);
        getToken(&tk2);
        rewindTo(&tk);

        if (isType(tk) && match(tk2, [tkIdentifier])) {
            return preDecl();
        }

        if (match(tk, [tkReturn])) {
            return returnStatement();
        }

        if (match(tk, [tkIf])) {
            return ifStatement();
        }

        if (match(tk, [tkFor])) {
            return forStatement();
        }

        if (match(tk, [tkWhile])) {
            return whileStatement();
        }

        if (match(tk, [tkFallback])) {
            return fallbackStatement();
        }

        // Return statement.
        if (match(tk, [tkReturn])) return returnStatement();

        return expressionStatement();
    }

    Node* expressionStatement() {
        scope(exit) consume(tkEndStatement, "Expected ';' to end statement");

        // Expression statement
        Node* expr = expression();
        if (expr is null) error("Invalid expression!");
        return expr;
    }

    /// statement which imports code from other module.
    Node* importStatement() {
        // Keep token for error reporting.
        Token tk;
        peekNext(&tk);
        scope (exit) consume(tkEndStatement, "Expected ';' to end import statement", &tk);
        
        Token imp = consume(tkImport, "Expected import statement!");
        Node* iden = identifierNoFunction();
        

        // Return import statement
        Node* n = new Node(imp);
        n.add(iden);
        return n;
    }

    Node* ifStatement() {
        consume(tkIf, "Expected 'if'");
        consume(tkOpenParan, "Expected '(' after 'if' statement.");
        Node* condition = expression();
        consume(tkCloseParan, "Expected ')' after condition.");

        Node* thenBranch;
        Node* elseBranch;

        Token tk;
        peekNext(&tk);

        if (match(tk, [tkStartScope])) {
            thenBranch = scopeBody();
        } else {
            auto bd = statement();
            thenBranch = new Node(astBody);
            thenBranch.add(bd);
        }

        peekNext(&tk);
        if (match(tk, [tkElse])) {
            consume(tkElse, "else expected!");
            peekNext(&tk);
            if (match(tk, [tkStartScope])) {
                elseBranch = scopeBody();
            } else {
                auto bd = statement();
                elseBranch = new Node(astBody);
                elseBranch.add(bd);
            }
        }

        Node* stmt = new Node(astBranch);
        stmt.add(condition);
        stmt.add(thenBranch);
        stmt.add(elseBranch);
        return stmt;
    }

    Node* parseForArgs() {
        Node* root = new Node(astParameters);
        Node* tempDecl;
        Node* condition;
        Node* conditionEnd;
        Token tk;
        getToken(&tk);
        if (match(tk, [tkEndScope])) {
            rewindTo(&tk);
            return root;
        }

        if (isType(tk)) {
            rewindTo(&tk);
            tempDecl = varDecl();
        } else {
            consume(tkEndStatement, "Expected ';'");
        }

        getToken(&tk);
        if (!match(tk, [tkEndStatement])) {
            rewindTo(&tk);
            condition = expression();
        }
        consume(tkEndStatement, "Expected ';'");

        peekNext(&tk);
        if (!match(tk, [tkEndScope])) {
            conditionEnd = expression();
        }

        root.add(tempDecl);
        root.add(condition);
        root.add(conditionEnd);
        return root;
    }

    Node* forStatement() {
        Node* root = new Node(astFor);

        consume(tkFor, "Expected 'for'");
        consume(tkOpenParan, "Expected '(' after 'for' statement.");

        Node* args = parseForArgs();

        consume(tkCloseParan, "Expected ')' after condition.");

        Node* bod = scopeBody();

        root.add(args);
        root.add(bod);
        return root;
    }

    Node* whileStatement() {
        Node* root = new Node(astWhile);

        consume(tkWhile, "Expected 'while'");
        consume(tkOpenParan, "Expected '(' after 'while' statement.");
        Node* expr = expression();
        consume(tkCloseParan, "Expected ')' after condition.");

        Node* bod = scopeBody();
        root.add(expr);
        root.add(bod);
        return root;
    }

    Node* foreachStatement() {
        error("Foreach statements are not supported yet.");
        return null;
    }

    Node* returnStatement() {
        // When the statement has been parsed, make sure it ends with ;
        Token tk;
        scope (exit) consume(tkEndStatement, "Expected ';' to end return statement", &tk);
    

        tk = consume(tkReturn, "Expected 'return'!");
        Node* n = new Node(tk, astReturn);
        peekNext(&tk);

        // If it doesn't end soon, it most likely contains an expression.
        if (!match(tk, [tkEndStatement])) n.add(expression());
        return n;
    }

    Node* fallbackStatement() {
        scope (exit) consume(tkEndStatement, "Expected ';' to end return statement");
        Token fallback = consume(tkFallback, "Expected 'fallback'!");
        return new Node(fallback);
    }


    /*
                                    Expressions
    */

    Node* expression() {
        return assignment();
    }

    Node* assignment() {
        Token tk;
        Node* expr = modifiers();
        
        getToken(&tk);
        if (match(tk, [tkAssign, tkAddAssign, tkSubAssign, tkDivAssign, tkMulAssign])) {
            Token eq = tk;
            Node* value = assignment();


            if (expr.token.id == tkIdentifier || expr.id == astIdentifier) {
                Node* n = new Node(expr.token);
                n.add(value);
                n.id = astAssignment;
                return n;
            }

            error("Invalid target for assignment", &eq);
        }

        rewindTo(&tk);
        return expr;
    }

    Node* modifiers() {
        Node* expr = casting();

        Token op;
        getToken(&op);
        while(match(op, [tkOr, tkAnd])) {
            Node* right = casting();

            // temp expression holder
            Node* texpr = new Node(op);
            texpr.add(expr);
            texpr.add(right);

            // Apply changes.
            expr = texpr;

            getToken(&op);
        }

        rewindTo(&op);

        // make sure it's marked as an expression.
        if (expr !is null && expr.id == astX) expr.id = astExpression;
        return expr;
    }

    Node* casting() {
        Node* expr = equality();

        Token op;
        getToken(&op);
        while(match(op, [tkAs])) {
            Node* right = type();
            if (right is null) error("Expected a type cast target!");

            // temp expression holder
            Node* texpr = new Node(op);
            texpr.add(expr);
            texpr.add(right);

            // Apply changes.
            expr = texpr;

            getToken(&op);
        }

        rewindTo(&op);

        return expr;
    }

    Node* equality() {
        Node* expr = comparison();

        Token op;
        getToken(&op);
        while(match(op, [tkNotEqual, tkEqual])) {
            Node* right = comparison();

            // temp expression holder
            Node* texpr = new Node(op);
            texpr.add(expr);
            texpr.add(right);

            // Apply changes.
            expr = texpr;

            getToken(&op);
        }

        rewindTo(&op);
        return expr;
    }

    Node* comparison() {
        Node* expr = addition();

        Token op;
        getToken(&op);
        while(match(op, [tkGreaterThan, tkGreaterThanOrEq, tkLessThan, tkLessThanOrEq, tkNotEqual, tkIs, tkNotIs])) {
            Node* right = addition();

            // temp expression holder
            Node* texpr = new Node(op);
            texpr.add(expr);
            texpr.add(right);

            // Apply changes.
            expr = texpr;

            getToken(&op);
        }

        rewindTo(&op);
        return expr;
    }

    Node* addition() {
        Node* expr = multiplication();

        Token op;
        getToken(&op);
        while(match(op, [tkSub, tkAdd])) {
            Node* right = multiplication();
            
            // temp expression holder
            Node* texpr = new Node(op);
            texpr.add(expr);
            texpr.add(right);

            // Apply changes.
            expr = texpr;

            getToken(&op);
        }

        rewindTo(&op);
        return expr;
    }

    Node* multiplication() {
        Node* expr = unary();

        Token op;
        getToken(&op);
        while(match(op, [tkDiv, tkMul])) {
            Node* right = unary();
            
            // temp expression holder
            Node* texpr = new Node(op);
            texpr.add(expr);
            texpr.add(right);

            // Apply changes.
            expr = texpr;

            getToken(&op);
        }

        rewindTo(&op);
        return expr;
    }

    Node* unary() {
        Token op;
        getToken(&op);
        if(match(op, [tkNot, tkSub])) {
            Node* right = unary();

            // The expression
            Node* expr = new Node(op);
            expr.add(right);

            return expr;
        }

        // Go back if not unary.
        rewindTo(&op);
        return primary();
    }

    Node* paramdef() {
        Token tk;
        Node* typ = type();
        if (typ is null) {
            error("Expected valid parameter type!");
        }

        getToken(&tk);
        if (!match(tk, [tkIdentifier])) {
            error("Expected parameter name, got " ~ tk.lexeme ~ ", belonging to " ~ typ.token.lexeme ~  "!");
        }
        typ.add(new Node(tk));
        return typ;
    }

    Node* paramlist() {
        consume(tkOpenParan, "Expected '(' to open parameter list");
        Token tk;
        Node* params = new Node(astParameterList);

        getToken(&tk);
        rewindTo(&tk);

        // No parameters
        if (match(tk, [tkCloseParan])) {
            consume(tkCloseParan, "Expected ')' to close parameter list");
            return params;
        }

        // Multiple parameters
        params.add(paramdef());
        getToken(&tk);
        while (match(tk, [tkListSep])) {
            params.add(paramdef());
            // Next iteration
            getToken(&tk);
        }

        // Done with parameters, go back.
        rewindTo(&tk);
        consume(tkCloseParan, "Expected ')' to close parameter list");
        return params;
    }

    Node* parameters() {
        consume(tkOpenParan, "Expected '(' to open parameters");
        Token tk;
        Node* params = new Node(astParameters);

        peekNext(&tk);

        // No parameters
        if (match(tk, [tkCloseParan])) {
            consume(tkCloseParan, "Expected ')' to close parameters");
            return params;
        }

        // Multiple parameters
        params.add(expression());
        getToken(&tk);

        while (match(tk, [tkListSep])) {
            params.add(expression());
            // Next iteration
            getToken(&tk);
        }

        // Done with parameters, go back.
        rewindTo(&tk);
        consume(tkCloseParan, "Expected ')' to close parameters, got '" ~ tk.lexeme ~ "'");
        return params;
    }

    Node* identifier(bool isThis = false) {
        Token tk;
        Token tk2;

        getToken(&tk);
        getToken(&tk2);

        Node* iden = new Node(tk);
        iden.id = astIdentifier;
        if (match(tk2, [tkDot])) {

            // Parse identifier lower down in content
            iden.add(identifier());
            return iden;
        } else if (match(tk2, [tkOpenParan])) {
            if (isThis) error("Cannot call constructor, type already constructed.");
            rewindTo(&tk2);
            iden.add(parameters());

            // Allow call().thing to be possible
            getToken(&tk2);
            if (match(tk2, [tkDot])) {
            
                // Parse identifier lower down in content
                iden.add(identifier());
                return iden;
            }
            rewindTo(&tk2);

            // This is a function call.
            iden.id = astFunctionCall;
            return iden;
        } else if (match(tk2, [tkInc, tkDec])) {
            if (isThis) error("Cannot increment or decrement 'this' reference.");
            Node* action = new Node(tk2);
            action.add(iden);
            return action;
        }

        rewindTo(&tk2);
        return iden;
    }

    Node* identifierNoFunction() {
        Token tk;
        Token tk2;

        getToken(&tk);
        getToken(&tk2);

        Node* iden = new Node(tk);
        iden.id = astIdentifier;

        if (match(tk2, [tkDot])) {

            // Parse identifier lower down in content
            iden.add(identifier());
            return iden;
        } else if(match(tk2, [tkOpenParan])) {

            throw new Exception("Function call not expected!");
        } else if (match(tk2, [tkInc, tkDec])) {

            Node* action = new Node(tk2);
            action.add(iden);
            return action;
        }

        rewindTo(&tk2);
        return iden;
    }

    Node* primary() {
        Token tk;
        getToken(&tk);
 
        if (match(tk, [tkIdentifier])) {
            rewindTo(&tk);
            return identifier();
        }

        if (match(tk, [tkThis])) {
            rewindTo(&tk);
            return identifier(true);
        }

        if (match(tk, [tkFalse, tkTrue, tkNumberLiteral, tkIntLiteral, tkStringLiteral])) {
            return new Node(tk);
        }

        if (match(tk, [tkNullLiteral])) return new Node(tk);
        

        if (match(tk, [tkOpenParan])) {
            Node* expr = expression();
            consume(tkCloseParan, "Expected ')' to close expression");
            return expr;
        }
        return null;
    }

public:
    this(string source) {
        this.lexer = Lexer(source);
    }

    /*
        Scan for types, this is run internally by parse
    */
    void scanTypes() {
        scanRoot();
    }

    /*
        Start parsing code
    */
    Node* parse() {
        // Scan the type mapping for this file.
        scanTypes();

        return module_();
    }

    TypeMapping getMapping() {
        return mapping;
    }
}