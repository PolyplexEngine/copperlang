/*
    Structs
*/

struct myStruct {

    int meaningOfLife;

    constructor() {
        meaningOfLife = 42;
    }

}

func main() {
    myStruct ms = myStruct();
    print(ms.meaningOfLife as string);
}