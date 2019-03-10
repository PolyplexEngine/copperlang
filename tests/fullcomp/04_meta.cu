/*
    Meta functions
*/

struct myMetaStruct {
    // Array of integers
    int[] meaningOfLives = [42, 42, 42, 42, 43];

    // Array indexing
    meta __index(int index) any {
        if (index is int) {
            return meaningOfLives[index];
        }

        fallback;
    }

    // Meta for +
    meta __opAdd(any value) myMetaStruct {
        print(value as string);
        return this;
    }

    // Meta for =
    meta __opAssign(any value) {
        print(value as string);
    }

    // Meta for +=
    meta __opAddAssign(any value) {
        print(value as string);
    }

    // Meta for string conversion
    meta __asString() string {
        return "myMetaStruct overwritten as string";
    }
}

func main() {
    myMetaStruct ms;
    ms[0];
    ms + 1;
    ms = 32;
    ms += "potato";
    print (ms as string);
}