module copper.lang.parser.ast;
import copper.lang.token;

// This will see a lot of change over time.

alias ASTTId = ubyte;

/// Anything that isn't a seperate id.
enum ASTTId astX = 0;

/// The scope of a class
enum ASTTId astClass = 1;

/// The scope of a struct
enum ASTTId astStruct = 2;

/// The scope of a function
enum ASTTId astFunction = 3;

/// The scope of a metafunction
enum ASTTId astMetaFunction = 4;

/// The body of a scope
enum ASTTId astBody = 5;

/// A Statement
enum ASTTId astStatement = 10;

/// A Declaration
enum ASTTId astDeclaration = 11;

/// An assignment
enum ASTTId astAssignment = 12;

/// Comparison
enum ASTTId astComparison = 13;

/// A branch. (if, else if, else)
enum ASTTId astBranch = 20;

/// A while loop.
enum ASTTId astWhile = 21;

/// A for loop.
enum ASTTId astFor = 22;

/// A foreach loop
enum ASTTId astForeach = 23;

/// A unit test
enum ASTTId astUnit = 24;

/// Returning a value
enum ASTTId astReturn = 25;

/// A call to a function
enum ASTTId astFunctionCall = 26;

/// An expression
enum ASTTId astExpression = 30;

/// A list of parameters
enum ASTTId astParameterList = 31;

/// A list of parameter values
enum ASTTId astParameters = 32;

/// Return type of a function.
enum ASTTId astReturnType = 33;

/// An identifier
enum ASTTId astIdentifier = 40;

/// Extension
enum ASTTId astExtension = 100;

/// Injection
enum ASTTId astInjection = 101;

/// Attribute
enum ASTTId astAttribute = 200;

/// constructor
enum ASTTId astConstructor = 254;

/// Module
enum ASTTId astModule = 255;

string getString(ASTTId id) {
    switch(id) {
        case (astClass):
            return "<class>";
        case (astStruct):
            return "<struct>";
        case (astFunction):
            return "<func>";
        case (astMetaFunction):
            return "<meta>";
        case (astBody):
            return "<body>";
        case (astStatement):
            return "<stmt>";
        case (astDeclaration):
            return "<decl>";
        case (astAssignment):
            return "<assign>";
        case (astComparison):
            return "<comp>";
        case (astBranch):
            return "<branch>";
        case (astWhile):
            return "<while>";
        case (astFor):
            return "<for>";
        case (astForeach):
            return "<foreach>";
        case (astUnit):
            return "<unit>";
        case (astReturn):
            return "<return>";
        case (astFunctionCall):
            return "<func call>";
        case (astExpression):
            return "<expr>";
        case (astParameterList):
            return "<paramdef list>";
        case (astParameters):
            return "<params>";
        case (astIdentifier):
            return "<iden>";
        case (astExtension):
            return "<ext>";
        case (astInjection):
            return "<inject>";
        case (astAttribute):
            return "<attrib>";
        case (astModule):
            return "<module>";
        case (astConstructor):
            return "<constructor>";

        // Just so I don't miss it.
        case (astX):
        default:
            return null;
    }
}