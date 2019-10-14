module test;

/**
    D print function
*/
exdecl func print(string value);

/**
    int-to-string conversion
*/
exdecl func int_to_string(int value) string;

/**
    string-to-int conversion
*/
exdecl func string_to_int(string value) int;

/**
    Main function
*/
func main(string a, string b) {
    print(a);
    print(b);
    int ai = string_to_int(a);
    int bi = string_to_int(b);

    if (ai == 1) {
        print("A is 1");
    } else if (ai == 2) {
        print("A is 2");
    } else if (ai == 3) {
        print("A is 3");
    } else if (ai == 4) {
        print("A is 4");
    } else if (ai == 5) {
        print("A is 5");
    } else {
        print("A is some other value.");
    }
}