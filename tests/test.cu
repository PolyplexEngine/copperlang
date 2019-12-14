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
func main(string[] args) int {
    print(int_to_string(args.length));
    print(args[0]);
    print(args[1]);
    print(args[2]);
    print(args[3]);
    print(int_to_string(args[3].length));
    return 0;
}