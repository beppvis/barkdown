const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena_allocator = init.arena.allocator();
    const file_contents = try std.Io.Dir.cwd().readFileAlloc(io, "example.md", arena_allocator, .unlimited);
    defer arena_allocator.free(file_contents);
    blockSplitter(file_contents, file_contents.len,arena_allocator);
}
//Front matter
//title: An Example Using the Tufte Style
//author: beppvis
//description: aksdjakdjskasj
//image: xxx.png
//created: 2026-06-16
//read_time: 25 mins
//slug: an-example-using-the-tufte-style
//style: static/tufte.css
const Date = struct {
    day: u8,
    month: u8,
    year: u32,
};
pub fn areStringsEqual(str_a: []const u8, str_b: []const u8) bool {
    if (str_a.len != str_b.len) return false;
    for (0..str_a.len) |i| {
        if (str_a[i] != str_b[i]) {
            return false;
        }
    }
    return true;
}
const Field = struct{
    name: []u8,
    content: []u8,
    pub fn parseFieldLine(field_line: []u8) Field {
        var pos: usize = 0;
        var field:Field = undefined;
        while (pos < field_line.len and field_line[pos] != ':') : (pos += 1) {}
        field.name = field_line[0..pos];
        pos += 1;
        while (pos < field_line.len and field_line[pos] == ' ') : (pos += 1) {}
        const start = pos;
        field.content= field_line[start..];
        return field;
    }

};
const FrontMatter = struct {
    title: []const u8,
    author: []const u8,
    description: []const u8,
    image: []const u8,
    created: Date,
    read_time: []const u8,
    slug: []const u8,
    style: []const u8,
    pub fn parseFrontMatter(front_matter_block: []u8) FrontMatter {
        var start_field: usize = 0;
        var end_field: usize = 0;
        var pos: usize = 0;
        var front_matter: FrontMatter = undefined;
        while (pos < front_matter_block.len) : (pos += 1) {
            start_field = pos;
            while (pos < front_matter_block.len and front_matter_block[pos] != '\n') {
                pos += 1;
            }
            end_field = pos;
            const field_line = front_matter_block[start_field..end_field];
            if (field_line.len == 0) continue;
            const field = Field.parseFieldLine(field_line);
            if (field.name.len >= field_line.len) {
                std.debug.print("Format error: {s} \n", .{field_line});
                continue;
            }
            if (areStringsEqual(field.name, "title")) {
                front_matter.title = field.content;
            } else if (areStringsEqual(field.name, "author")) {
                front_matter.author = field.content;
            } else if (areStringsEqual(field.name, "description")) {
                front_matter.description = field.content;
            } else if (areStringsEqual(field.name, "image")) {
                front_matter.image = field.content;
            } else if (areStringsEqual(field.name, "read_time")) {
                front_matter.read_time = field.content;
            } else if (areStringsEqual(field.name, "slug")) {
                front_matter.slug = field.content;
            } else if (areStringsEqual(field.name, "style")) {
                front_matter.style = field.content;
            } else if (areStringsEqual(field.name, "created")) {
                // yyyy-mm-dd
                front_matter.created.year = std.fmt.parseInt(u32, field.content[0..4],0) catch 0;
                front_matter.created.month = std.fmt.parseInt(u8, field.content[5..7],0) catch 0;
                front_matter.created.day= std.fmt.parseInt(u8, field.content[8..],0) catch 0;
                if (front_matter.created.year == 0 or front_matter.created.month == 0 or front_matter.created.day == 0){
                    @panic("Wrong format for created field, use yyyy-mm-dd");
                }
            } else {
                std.debug.print("Unrecognized field.name : {s}\n", .{field.name});
            }
            //std.debug.print("field: {s} - {s}\n", .{field.name,field.content});
        }
        //std.debug.print("Front matter captured: {}\n", .{front_matter.created});
        return front_matter;
    }
};

const Scanner = struct {
    pos: usize,
    source: []u8,
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
    pub fn getFrontMatter(self: *Scanner) []u8 {
        const start: usize = self.pos; // start of the frontMatter
        var end: usize = self.pos;
        var count: u8 = 1;
        while (!self.isAtEnd()) {
            if (self.advance() == '-'){
                count += 1;
            }
            else {
                count = 0;
            }
            if (count == 3) {
                end = self.pos - 3;
                break;
            }
        }
        return self.source[start..end];
    }
};

pub const Block = struct{
    type: enum {
        heading,
        section,
    },
    head:[]u8,
    content: [] u8,
};

pub fn blockSplitter(file_content: []u8, content_size: usize,allocator:std.mem.Allocator) void {
    var self: Scanner = .{
        .pos = 0,
        .source = file_content,
        .size = content_size,
    };
    var page:std.ArrayList(Block) = .empty;
    var front_matter: FrontMatter = undefined;
    var front_matter_captured = false;
    var block_start:usize = 0;

    while (!self.isAtEnd()) {
        switch (self.advance()) {
            '-' => {
                if (!front_matter_captured) {
                    // front_matter
                    for (0..2) |_| {
                        while (self.peek() != '\n' and !self.isAtEnd()) {
                            if (self.advance() != '-') break;
                        }
                    }
                    // inside the front matter
                    front_matter = FrontMatter.parseFrontMatter(self.getFrontMatter());
                    front_matter_captured = true;
                }
            },
            '#'=> { //heading checking
                var count:u8 = 1;
                while (self.peek() != '\n' and !self.isAtEnd()) {
                    if (self.advance() != '#'){
                        break;
                    }
                    else {
                        count += 1;
                    }
                }
                const start = self.pos;
                while (self.advance() != '\n'){
                }
                if (count == 1){ // H1
                    page.append(allocator, .{
                        .content= "",
                        .head = self.source[start..self.pos],
                        .type = .heading,
                    }) catch unreachable;
                }
                else if (count == 2){ // H2 -> section
                    if (page.getLastOrNull()) |block|{
                        if (block.type == .section)
                            page.items[page.items.len-1].content = self.source[block_start..start-3];
                    }
                    block_start = self.pos+1;
                    page.append(allocator, .{
                        .content= self.source[self.pos..],
                        .head = self.source[start..self.pos],
                        .type = .section,
                    }) catch unreachable;

                }
            },
            else => {},
        }
    }



    for (0..page.items.len) |i|{
        std.debug.print("block : {s} \n", .{page.items[i].head});
        if (page.items[i].type  != .heading)
            std.debug.print("content : {s} \n", .{page.items[i].content});
    }

    defer page.deinit(allocator);
}
