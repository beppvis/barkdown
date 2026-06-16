const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena_allocator = init.arena.allocator();
    const file_contents = try std.Io.Dir.cwd().readFileAlloc(io, "example.md", arena_allocator, .unlimited);
    defer arena_allocator.free(file_contents)   ;
    std.debug.print("{s}", .{file_contents});
    blockSplitter(file_contents, file_contents.len);

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
    day:u8,
    month:u8,
    year:u32,
};
pub fn areStringsEqual(str_a : []const u8, str_b: []const u8 ) bool{
    if (str_a.len != str_b.len) return false;
    for (0..str_a.len) |i|{
        if (str_a[i] != str_b[i]) {
            return false;
        }
    }
    return true;
}
const FrontMatter = struct{
    title:[] const u8,
    author:[]const u8,
    description:[]const u8,
    image:[]const u8,
    created:Date,
    read_time : []const u8,
    slug:[]const u8,
    style:[]const u8,
    pub fn parseFieldLine(field_line:[]u8) []u8 {
        var pos:usize = 0;
        while (pos < field_line.len and field_line[pos] != ':'):(pos+=1){
        }
        return field_line[0..pos];
    }
    pub fn parseFrontMatter(front_matter_block:[]u8) FrontMatter{
        var start_field:usize = 0;
        var end_field:usize = 0;
        var pos:usize = 0;
        var front_matter:FrontMatter = .{ .title= "An Example Using the Tufte Style", .author= "beppvis", .description= "aksdjakdjskasj", .image="xxx.png", .created= .{ .year= 2026, .month = 6, .day = 16}, .read_time= "25 mins", .slug= "an-example-using-the-tufte-style", .style= "static/tufte.css", };
        while (pos < front_matter_block.len) : (pos += 1){
            start_field = pos;
            while (pos < front_matter_block.len and front_matter_block[pos] != '\n' ){ 
                pos += 1;
            }
            end_field = pos;
            const field_line = front_matter_block[start_field..end_field];
            const field = parseFieldLine(field_line);
            if (field.len >= field_line.len) {
                std.debug.print("Format error: {s} \n", .{field_line});
                continue;
            }
            if (areStringsEqual(field, "title")){
                front_matter.title = field_line[field.len..];
            }
            else if (areStringsEqual(field, "author")){
                front_matter.author= field_line[field.len..];
            }
            else if (areStringsEqual(field, "description")){
                front_matter.description= field_line[field.len..];
            }
            else if (areStringsEqual(field, "image")){
                front_matter.image = field_line[field.len..];
            }
            else if (areStringsEqual(field, "read_time")){
                front_matter.read_time= field_line[field.len..];
            }
            else if (areStringsEqual(field, "slug")){
                front_matter.slug= field_line[field.len..];
            }
            else if (areStringsEqual(field, "style")){
                front_matter.style= field_line[field.len..];
            }
            else if (areStringsEqual(field, "created")){
                std.debug.print("TODO: date parsing\n", .{});
            }
            else {
                std.debug.print("Unrecognized field : {s}\n", .{field});
            }

        } 
        std.debug.print("Front matter captured: {s}\n", .{front_matter.title});
        return front_matter; 
    }

};

const Scanner = struct{
    pos: usize,
    souce: []u8,
    size: usize,
    pub fn isAtEnd(self:*Scanner) bool{
        return self.pos >= self.size;
    }
    pub fn peek(self:*Scanner) u8{
        if (self.isAtEnd()) {
         return '\x00';
        }
       else {
            return self.souce[self.pos];
        }
    }
    pub fn advance(self:*Scanner) u8{
        const c = self.souce[self.pos];
        self.pos += 1;
        return c;
    }
    pub fn getFrontMatter(self:*Scanner) []u8{
        const start:usize = self.pos; // start of the frontMatter
        var end:usize= self.pos;
        while (!self.isAtEnd()){
            switch (self.advance()){
               '-'  => {
                    // check for end
                    var count:u8 = 1;
                    while (!self.isAtEnd()){
                        if (self.advance() == '-') count += 1;
                        if (count == 3) {
                            end = self.pos - 3;
                            break; // end of front matter
                        }
                    }
                },
                else =>{
                    // pass
                } 

            }
        }
        return self.souce[start..end];
    }

};

pub fn blockSplitter(file_content: []u8, content_size:usize) void {
    var self:Scanner = .{
        .pos = 0,
        .souce =  file_content,
        .size  = content_size,
    };
    var front_matter:FrontMatter = undefined;
    while (!self.isAtEnd()){
        switch (self.advance()) { 
            '-' => {
                for (0..2)|_| {
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        if (self.advance() != '-') break;
                    }
                }
                // inside the front matter 
                front_matter = FrontMatter.parseFrontMatter(self.getFrontMatter());
            },
            else => {
            }
        }
    }
}
