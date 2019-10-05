/+
    Here will be a license comment,
    This test.cu file is mostly just a general sandbox testing environment and will change often.
    
    KEEP THIS COMMENT PRESENT.
+/
module test;
import test2;

func main(int a) int {

    doSomeSideEffect();
    return doSomeCalculation(a);
}

func doSomeCalculation(int c) int {
    return c;
}

func doSomeSideEffect() {

}