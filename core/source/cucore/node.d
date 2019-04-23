module cucore.node;
import cucore.token;
import cucore.ast;
import std.conv;
import std.format;
import cucore.strutils;
import std.stdio;

/// A node in the Abstract Syntax Tree
struct Node {
private:
    size_t children;

public:

    /// Constructor
    this (Token token, ASTTId id = astX) {
        this.id = id;
        this.token = token;

        this(id);
    }

    /// Constructor
    this (ASTTId id) {
        this.id = id;
        this.name = token.lexeme;
    }

    /// At node to children at start
    void addStart(Node* node) {
        if (node is null) return;
        if (firstChild is null && lastChild is null) {
            lastChild = node;
        }

        if (firstChild !is null) {
            firstChild.left = node;
            node.right = firstChild;
        }
        firstChild = node;

        node.parent = &this;
        children++;
    }

    /// Add node to children at end
    void add(Node* node) {
        if (node is null) return;
        if (firstChild is null) {
            firstChild = node;
        }

        if (lastChild !is null) {
            lastChild.right = node;
            node.left = lastChild;
        }
        lastChild = node;

        node.parent = &this;
        children++;
    }

    /// Count of children this node is parent to.
    size_t childrenCount() {
        return children;
    }

    /// The AST Type Id associated with this Node.
    ASTTId id;

    /// The token associated with this node
    Token token;

    /// The first child the node is parent to
    Node* firstChild;

    /// The last child the node is parent to
    Node* lastChild;

    /// The node to the left of this node
    Node* left;

    /// The node to the right of this node
    Node* right;

    /// Parent to this node
    Node* parent;

    /// Temporary debug lexeme
    string name;

    string toString(size_t indent = 0) {
        string rgt = right !is null ? right.toString(indent) : "";
        string chd = children > 0 ? " "~firstChild.toString(indent+1) : "";

        /// TODO: This ugly code needs some serious rewriting.
        string txt = token.lexeme != "" ? token.lexeme : "";
        string typ = token.id != tkUnknown ? token.id.text : "<arb>";
        string astid = id.getString() !is null ? id.getString()~" " : "";

        string offs = (chd.length > 0 ? "\n" ~ "".offsetBy(indent*2) : "");
        string offsrc = (right !is null ? "," : "");
        string offsr = offsrc ~ (right !is null ? "".offsetBy(indent*2) : "");

        return ("\n%s(%s%s%s%s)%s%s").format("".offsetBy(indent*2), astid, txt, chd, offs, offsr, rgt);
    }
}