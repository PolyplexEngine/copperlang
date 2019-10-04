/*
    Experiemental Feature - Classes
*/

class myClass {
    func myFinalFunction() string {
        return "test";
    }

    abstract func myAbstractFunction() string;
    abstract func myOtherAbstractFunction() string;

    virtual func myVirtualFunction() {
        print("Hello, everyone!");
    }
}

class mySubClass : myClass {
    int meaningOfSomethingElse = 43;

    override
    func myAbstractFunction() string {
        return "A";
    }

    override
    func myOtherAbstractFunction() string {
        return "B";
    }

    override
    func myVirtualFunction() {
        super.myVirtualFunction();

        print("And goodbye!");
    }
}

func main() {
    myClass mc = myClass();
    myClass sc = mySubClass();
    
    // Is the type of mc the same as sc?
    // Should be true as they are compatible.
    if (mc is sc) {
        print("Yes!");
    } else {
        print("No! :c");
    }

    // Is mc the EXACT type as sc?
    // Should be false since it's different classes
    if (mc is exact sc) {
        print("Yes??");
    } else {
        print("No!");
    }

    // Test virtual functions
    mc.myVirtualFunction();
    sc.myVirtualFunction();

    // Test overriden functions
    print (sc.myAbstractFunction());
    print (sc.myOtherAbstractFunction());
}