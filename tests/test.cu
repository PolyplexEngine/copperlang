/+
    Here will be a license comment,
    This test.cu file is mostly just a general sandbox testing environment and will change often.
    
    KEEP THIS COMMENT PRESENT.
+/
module myModule.thing;

/// External D declaration for d_print.
exdecl func d_print(string text);

/// Test add function
func test_add(int x, int y) int {
    return x + y;
}

/// Test subtract function
func test_sub(int x, int y) int {
    return x - y;
}

/// Test division function
func test_div(int x, int y) int {
    return x / y;
}

/// Test multiplication function
func test_mul(int x, int y) int {
    return x * y;
}

/// Final test; Hello, World!
func test_helloWorld() {
    d_print("Hello, world!");
}