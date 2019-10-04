module cucore.list;

/**
    dynamically resized array which resizes in chunks to save memory reallocations
*/
public class ArrList(T, size_t chunkSize = 10, size_t chunkTolerance = 1) {
private:
    T[] elements;
    size_t usedLength;

    size_t find(T item) {
        foreach(i; 0..usedLength) {
            if (elements[i] == item) return i;
        }
        return -1;
    }

    void shiftElements(size_t start) {
        foreach(i; start+1..usedLength) {
            elements[i-1] = elements[i];
        }
        usedLength--;
    }

    void resize() {
        import std.stdio;

        // Figure out suitable size...
        immutable size_t usedChunks = usedLength/chunkSize;
        immutable size_t availableChunks = elements.length/chunkSize;
        size_t reasonableChunks = usedChunks+chunkTolerance;

        // Skip if size is OK.
        if (availableChunks > 0 && reasonableChunks > 0 && reasonableChunks <= chunkTolerance) {
            // chunks are by configuration a reasonable size, skip resizing.
            return;
        }
        elements.length = reasonableChunks*chunkSize;
    }

public:
    /// Get length of list
    size_t count() {
        return usedLength;
    }

    /// Gets the raw length of the list.
    size_t length() {
        return elements.length;
    }

    /// Gets the amount of chunks managed.
    size_t chunks() {
        return elements.length/chunkSize;
    }

    /// Adds an element to the back of the list.
    void add(T item) {
        resize();
        elements[usedLength++] = item;
    }

    /// Removes element at index.
    void removeAt(size_t index) {
        shiftElements(index);
    }

    /// Removes an element.
    void remove(T item) {
        size_t pos = find(item);
        if (pos == -1) return;
        removeAt(pos);
    }

    /// Get element at index.
    T opIndex()(size_t index) if (is(T == class)) {
        return index < usedLength ? elements[index] : null;
    }

    /// Get element at index.
    T opIndex()(size_t index) {
        return index < usedLength ? elements[index] : T.init;
    }

    /// foreach impl
    int opApply(int delegate(ref T) dg) {
        int result;
        foreach(i; 0..usedLength) {
            result = dg(elements[i]);
            if (result) break;
        }
        return result;
    }

    T[] toArray() {
        return elements[0..usedLength];
    }

}

/*
    This is an experimental doubly linked list.
    Will probably move to the std.containers list at some point or use arrays.
*/
public class List(T) {
private:
    size_t length_;
    ListElement* first;
    ListElement* last;

    void addEnd(T item, bool back = true) {
        ListElement* elm = new ListElement(item, null, null);
        if (length_ == 0) {
            length_ = 1;
            first = elm;
            last = elm;
            return;
        }
        if (length_ == 1) {
            length_ = 2;
            last = elm;
            last.previous = first;
            first.next = last;
            return;
        }
        length_++;
        if (back) {
            elm.previous = last;
            last.next = elm;
            last = elm;
            return;
        } 
        elm.next = first;
        first.previous = elm;
        first = elm;
        return;
    }

    void addAtPosition(T item, size_t position) {
        if (length_ < 3 || position <= 0 || position >= length_) {
            addEnd(item);
            return;
        }
        ListElement!(T)* elm = getIndex(position);
        ListElement!(T)* elmNew = new ListElement(item, null, null);
        // failsafe
        if (elm is null) return;

        if (elm.next !is null) {
            elm.next.previous = elmNew;
        }
        elm.next = elmNew;
        length_++;
    }

    void removeAtPosition(size_t position) {
        ListElement!(T)* elm = getIndex(position);
        if (elm is null) return;
        if (elm.previous !is null) {
            elm.previous.next = elm.next !is null ? elm.next : null;
        }
        if (elm.next !is null) {
            elm.next.previous = elm.previous !is null ? elm.previous : null;
        }
        length_--;
    }


    /// Get element at index.
    ListElement!T getIndex(size_t index) {
        ListElement!T* elm = first;
        foreach(i; 0..index) {
            elm = elm.next;
        }
        return elm;
    }
public:
    size_t length() {
        return length_;
    }

    void add(T item) {
        addAt(item, true);
    }

    void addFront(T item) {
        addAt(item, false);
    }

    void addAt(T item, size_t position) {
        addAtPosition(item, position);
    }

    void remove(T item) {
        size_t itemIndex = 0;
        ListElement!T* elm = first;
        foreach(i; 0..length_) {
            if (item == elm.item) break;
            elm = elm.next;
            itemIndex++;
        }
        removeAt(itemIndex);
    }

    void removeAt(size_t index) {
        removeAtPosition(itemIndex);
    }

    /// Get element at index.
    T opIndex(size_t index) {
        ListElement!T* elm = first;
        foreach(i; 0..index) {
            elm = elm.next;
        }
        return elm.item;
    }

    T opApply(int delegate(ref size_t) dg) {
        return this[dg];
    }
}

private struct ListElement(T) {
    T item;
    ListElement* next;
    ListElement* previous;
}