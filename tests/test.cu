/+
    Here will be a license comment,
    This test.cu file is mostly just a general sandbox testing environment and will change often.
    
    KEEP THIS COMMENT PRESENT.
+/
module myModule.thing;
import otherModule;

string myString = "Hello, world!";

public class MyClass : OtherClass {
    int MeaningOfLife;

    public this() {
        MeaningOfLife = 42;
    }

    public meta __asString() {
        if (MeaningOfLife == 42) {
            return "A";
        } else if (MeaningOfLife == 43) {
            return "B";
        } else {
            return "C";
        }
        return MeaningOfLife as string;
    }
}