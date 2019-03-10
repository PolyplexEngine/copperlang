# Copper Grammar Listing
## Pre-words

Copper grammer is found in this file.

This document is incomplete and will change over time.

# Directory

Here's the list of subjects covered in this document.

1. [Grammar Layout ](#grammar-layout) (AKA How to read this document)
    
    1. [Root Definition](#root-definition)
    
    2. [Comments](#comments)
    
    3. [Content](#content)
    
    4. [Conditionals](#conditionals)
        
        1. [Encapsulation](#encapsulation-conditional)
        
        2. [Raw](#conditional-raw)
        
        3. [Or](#conditional-or)

        4. [Final Notes](#final-notes)

2. [Grammar](#grammar) (The actual grammar)
    
    1. [Lexical](#lexical)
    
    2. [Modules](#modules)
    
    3. [Declarations](#declarations)

    3. [Expressions](#expressions)
    
    4. [Structs](#structs)
    
    5. [Inline Assembler](#inline-assembler)

3. [Assembler](#assembler-grammar) (Grammar for the inline bytecode assembler)

&nbsp;

# Grammar Layout
## Root Definition
The root of a grammar context is defined as:
```
(name):
```

If something does not refer to a root definition it is to be seen as actual raw text.

&nbsp;

#### Example
```
ThingA:
    : ThingB

ThingB:
    ! Something 
```

In this example; ThingA would be defined as a semicolon followed by ThingB.

Thing B would be defined as exclamation mark followed by the word "Something"

&nbsp;

#### Outcome
Following syntax is valid
```
: ! Something
```

&nbsp;
#
## Comments
Comments are defined via hastag #, comments usually contains descriptions or notes about something.

&nbsp;

#
## Content

Content is indented by a tab character (or 4 spaces), content may refer to Definitions, raw UTF-8 characters and conditionals.
#### Example
```
    MeaningOfLife [(42 ! potato) class]
```
&nbsp;

Would result on the following grammar being valid
#### Example
```
    MeaningOfLife 42 class
    MeaningOfLife ! class
    MeaningOfLife potato class
```

&nbsp;

#
## Conditionals

Conditionals allow for multiple acceptable grammars

&nbsp;

#
### Encapsulation Conditional
Conditional encapsulation allows grouping multiple tokens in to one conditional, making multi-token ORs possible. Tokens in an encapsulation appear in order of appearance in the spec.

Conditional encapsulation is defined by surrounding the tokens in square brackets [].

A line is implicitly an encapsulation.

#### Example
```
    MeaningOfLife ([42 ! 99] OtherMeaning)
```

&nbsp;

#### Outcome
Following is valid grammar.
```
MeaningOfLife 42 ! 99
MeaningOfLife OtherMeaning
```

&nbsp;

#
### Conditional Raw
Conditional RAW allows for something otherwise a definition to be a raw definition.

Conditional RAW is defined via less-than and greater-than <>.

#### Example
```
MeaningOfLife:
    42

MeaningOfLifeRoot:
    <MeaningOfLife> 42

```

#### Outcome
Following is valid grammar.
```
MeaningOfLife 42
```

&nbsp;

#
### Conditional OR
Conditional OR allows multiple definitions to be valid, only one can be present at a time.

Conditional OR can be defined either using parenthesies or placing OR on seperate lines

#### Example
```
MeaningOfLife:
    (42 43)
    44
```

#### Outcome
Following is valid grammar.
```
42
43
44
```

&nbsp;

#
## Final Notes

Anything surrounded by curlybraces {} is to be interpreted as text for the reader, to convey generic things.

Anything followed by ... means an infinite range of the previous declaration.

&nbsp;
# Grammer Declaration

## Lexical
```
# A unicode character
Character:
    {Any unicode character}


# End of File
EOF:
    {No more data being left}
    \u0000
    \u001A


# End of Line
EOL:
    # General Line endings
    \u000D
    \u000A

    # Windows line endings
    [\u000D \u000A]
    \u2028
    \u2029
    EOF



# A single whitespace character
Whitespace:
    \u0020
    \u0009
    \u000B
    \u000C


# Any type of comment
Comment:
    BlockComment
    LineComment
    DocComment


# A /* block comment */
BlockComment:
    </*> Character... <*\>

# // A line comment
LineComment:
    <//> Character... EOL

# /+ A Documentation Comment +/
DocComment:
    </+> Character... <+\>

# A token
Token:
    TKIdentifier
    StringLiteral
    CharacterLiteral
    IntegerLiteral
    FloatLiteral
    Keyword
    /
    /=
    or
    or=
    and
    and=
    -
    -=
    +
    +=
    !
    !=
    (
    )
    [
    ]
    {
    }
    <
    >
    :
    ~
    ~=

# An identifier (when tokenizing)
TKIdentifier:
    IdentifierStart
    IdentifierStart IndentifierChar...


# The start of an identifier
TKIdentifierStart:
    _
    {Unicode letter}
    {Universal Alphanumeric}


# An character in the identifier
TKIdentifierChar:
    IdentifierStart
    {Any digit from 0 to 9}


Identifier:
    TKIdentifier
    TKIdentifier . Identifier
    FuncCall

Literal:
    CharacterLiteral
    StringLiteral
    IntLiteral
    FloatLiteral
    true
    false
    null

# A character literal
CharacterLiteral:
    ' (Character EscapeSeq) '


# A string literal
StringLiteral:
    " (Character EscapeSeq)... "


# An escape sequence
EscapeSeq:
    \'
    \"
    \?
    \\
    \0
    \a
    \b
    \f
    \n
    \r
    \t
    \v
    \x
    # TODO: Add hex-digits?


# TODO: more int literal types.
# An integer literal
IntegerLiteral:
    {Any digit from 0 to 9}...


# A floating point (and double precision) value
FloatLiteral:
    {Any digit from 0 to 9}...<.>
    .{Any digit from 0 to 9}...
    {Any digit from 0 to 9}...<.>{Any digit from 0 to 9}...

ArrayType:
    Type <[> <]>

# A type
Type:
    # arrays.
    ArrayType

    #normal types
    TypeX

TypeX:
    ubyte
    byte
    ushort
    short
    uint
    int
    ulong
    long
    float
    double
    char
    string
    ptr

    # For user defined types
    Identifier
    Identifier . Type

StorageClass:
    public
    protected
    private

    # alias for public
    global

    # alias for protected
    internal

    # alias for private
    local

AssignmentOp:
    =
    +=
    -=
    /=
    *=

# Keywords
Keywords:
    abstract
    asm
    as
    any
    
    bool
    break
    byte

    case
    char
    class
    continue
    constructor

    double

    else
    enum

    false
    float
    for
    foreach
    func
    fallback

    global

    if
    import
    int
    interface
    is
    internal

    long
    local

    module
    meta

    null

    override

    private
    protected
    public
    ptr

    return

    short
    struct
    super
    switch

    this
    true

    ubyte
    uint
    ulong
    ushort
    unit

    while

    # Special reserved keywords for later and compiler debugging
    PANIC
    __LINE__
    __FUNCTION__
```

&nbsp;

## Modules
```
Module:
    ModuleDeclaration DeclDef...
    DeclDef...

ModuleDeclaration:
    module ModuleFQN ;

ModuleFQN:
    Identifier
    Identifier . ModuleFQN

DeclDef:
    ImportDecl
    Unittest
    Declaration

ImportDecl:
    import ModuleFQN ;

```

&nbsp;

## Declarations

```
Declaration:
    PreDecl

PreDecl:
    StorageClass Decl
    Decl

Decl:
    FuncDecl
    VarDecl
    EnumDecl
    MetaDecl
    ConstructorDecl

VarDecl:
    Type (Identifier [Identifier Expression]) ;
```

&nbsp;

## Expressions

```
Expression:
    Assignment

Assignment:
    Identifier AssignmentOp Assignment
    Modifiers

Modifiers:
    Casting (or and) Casting
    Casting

Casting:
    Equality as Type
    Equality

Equality:
    Comparison (= !=) Comparison 
    Comparison

Comparison:
    Addition (> >= < <= != is !is) Addition
    Addition

Addition:
    Multiplication (- +) Multiplication
    Multiplication

Multiplication:
    Unary (/ *) Unary
    Unary

Unary:
    (! -) Unary
    Primary

Primary:
    (Identifier this)
    Literals
    <(> Expression <)>

FuncCall:
    # Nothing OR an parameter sequence is accepted for empty function calls
    TKIdentifier <(> ( Parameter) <)>

Parameter:
    Expression
    Expression , Parameter

```

&nbsp;

## Structs

```
StructDeclaration:
    struct Identifier (< Identifier) AggregateBody
```


&nbsp;

## Inline Assembler

```
ASM:
    asm { ASMBody }

ASMBody:
    {See Assembler Grammar}
```

# Assembler Grammar

To be written