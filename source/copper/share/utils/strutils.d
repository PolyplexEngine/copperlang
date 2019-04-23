module copper.share.utils.strutils;
import copper.lang.token;
import std.conv;
import std.string;

string offsetBy(string text, size_t offset) {
    string offsetStr = "";
    foreach(i; 0..offset) offsetStr ~= " ";
    return offsetStr ~ text;
}

string repeat(string text, size_t times) {
    string output = "";
    foreach(i; 0..times) {
        output ~= text;
    }
    return output;
}

string offsetByLines(string text, size_t offset) {
    import std.string : splitLines;
    string outLines;
    string[] lines = splitLines(text);
    foreach(line; lines) {
        outLines ~= line.offsetBy(offset) ~ "\n";
    }
    return outLines;
}

string escape(char c) {
    switch(c) {
        case('\n'):
            return "<newline>";
        default:
            return ""~c;
    }
}

size_t getCharOfLine(string source, size_t line) {
    size_t linechar = 0;
    size_t lines = 0;
    while (lines < line) {
        if (source[linechar] == '\n') lines++;
        linechar++;
    }
    return linechar;
}

size_t getLengthOfLine(string source, size_t start) {
    size_t chars = 0;
    size_t i = start;
    while (i < source.length && source[i] != '\n') { chars++; i++; }
    return chars;
}

struct strArea {
public:
    size_t start;
    size_t end;
    bool large;
    bool endCovered;
}

strArea getAppropriateStringArea(string source, Token tk) {
    // Get line start
    immutable(size_t) start = source.getCharOfLine(tk.line);
    immutable(size_t) length = source.getLengthOfLine(start);

    size_t areaStart = start;
    size_t areaEnd = start+length;

    if (length > 80) {
        bool atEnd = false;
        areaStart = tk.start-40;
        areaEnd = tk.start+80;

        // Force to be on the right line
        if (areaStart <= start) areaStart = start;


        if (areaEnd >= start+length) { 
            areaEnd = start+length;
            atEnd = true;
        }
        return strArea(areaStart, areaEnd, true, atEnd);
    }
    return strArea(areaStart, areaEnd, false, true);
}

string getOutText(string source, Token tk, string error) {
    strArea area = getAppropriateStringArea(source, tk);
    size_t tokenOffset = tk.start-area.start;

    // Generate cursor:
    string prefix = tk.line.text ~ ": " ~ (area.large ? "..." : "");

    string cursor = "^".offsetBy(prefix.length+tokenOffset);
    string err = tk.pos.text.offsetBy(prefix.length+tokenOffset) ~ ": " ~ error;

    string sep = "=".repeat(64);

    return sep ~ "\n" ~ prefix ~ source[area.start..area.end] ~ (!area.endCovered ? "..." : "") ~ "\n" ~ cursor ~ "\n" ~ err;
}