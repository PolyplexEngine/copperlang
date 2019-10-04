/+
    Here will be a license comment,
    This test.cu file is mostly just a general sandbox testing environment and will change often.
    
    KEEP THIS COMMENT PRESENT.
+/
module test;
import test2;

func speedCalc(float speed, float drag) float {
    return (speed * drag) / getGravConst();
}

func getGravConst() float {
    return 12.0;
}