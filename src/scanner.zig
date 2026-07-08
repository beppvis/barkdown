const Scanner = @This();
pos: usize,
source: []const u8,
size: usize,
pub fn isAtEnd(self: *Scanner) bool {
    return self.pos >= self.size;
}
pub fn peek(self: *Scanner) u8 {
    if (self.isAtEnd()) {
        return '\x00';
    } else {
        return self.source[self.pos];
    }
}
pub fn advance(self: *Scanner) u8 {
    const c = self.source[self.pos];
    self.pos += 1;
    return c;
}
pub fn getFrontMatter(self: *Scanner) []const u8 {
    const start: usize = self.pos; // start of the frontMatter
    var end: usize = self.pos;
    var count: u8 = 1;
    while (!self.isAtEnd()) {
        if (self.advance() == '-') {
            count += 1;
        } else {
            count = 0;
        }
        if (count == 3) {
            end = self.pos - 3;
            break;
        }
    }
    return self.source[start..end];
}

