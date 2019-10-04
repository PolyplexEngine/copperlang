/*
    D pointer manipulation
*/

func main() {

    ptr myPointer = __TEST_OBJECT_ARRAY__;
    // Would crash here if not array.
    // D print prints contents of d pointer in Ds perspective (toString or stringof)
    dPrint(myPointer[1]);


    myPointer = __TEST_OBJECT_D_FUNC__;
    // Would crash here if invalid call.
    myPointer("This is a test with an UTF-8 string æøå");


    myPointer = __TEST_OBJECT_D_INT__;
    // Would crash here if types are not compatible.
    int myCuInt = myPointer as int;
}