/*
    Experimental Feature - Injection
*/

struct Person {
    string name;
}

struct Managment < Person {
    int role;

    meta __asString() {
        return name ~ " " ~ (role as string);
    }
}

struct Boss < Managment {
    func takeDecision(string decision) {
        print("Buissness logic would be here");
    }

    meta __asString() {
        return name ~ " (Boss) " ~ (role as string);
    }
}

struct Coworker < Person {
    string department;

    meta __asString() {
        return name ~ " " ~ department;
    }
}

func main() {
    Boss theBoss;
    theBoss.name = "Peter";
    theBoss.role = 0;
    
    Managment cto;
    cto.name = "Alice";
    cto.role = 1;

    Coworker jenny;
    jenny.name = "Jenny";
    jenny.department = "Backend Development";

    Coworker james;
    james.name = "James";
    james.department = "Frontend Development";

    Person[] peopleAtCompany = [theBoss, cto, jenny, james];

    print(peopleAtCompany as string);
}