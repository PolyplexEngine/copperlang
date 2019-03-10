/*
    Factorial Recursion
*/

func main() {
    print(factorial(32) as string);
}

func factorial(int n) int {
    int result;
    if (n == 0 or n == 1) return 1;

    result = factorial(n-1) * n;
    return result;
}