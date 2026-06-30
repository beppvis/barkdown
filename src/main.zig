const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const full_width_image_format = 
 \\<figure class="fullwidth">
 \\ <img alt="{s}" src="{s}">
 \\</figure>
;
const image_format = "<figure><img alt=\"{s}\" src=\"{s}\"></figure>\n";
const header_format = "<head>\n<title>{s}</title>\n<meta property=\"og:type\" content=\"website\">\n<meta property=\"og:url\" content=\"https://beppvis.works/blogs/{s}\">\n<meta property=\"og:title\" content=\"{s}\">\n<meta property=\"og:description\" content=\"{s}\">\n<meta property=\"og:image\" content=\"{s}\">\n<meta property=\"twitter:title\" content=\"{s}\">\n<meta property=\"twitter:description\" content=\"{s}\">\n<meta property=\"twitter:image\" content=\"{s}\">\n<meta property=\"twitter:url\" content=\"https://beppvis.works/blogs/{s}\">\n</head>\n<body>\n<article>\n<h1>{s}</h1>\n<div class=\"header-info\"> \n<subtitle>{s} ◦ {s} </subtitle> \n<subtitle>by {s}</subtitle>\n</div>\n";

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const arena_allocator = init.arena.allocator();
    const posts_dir = try std.Io.Dir.openDir(std.Io.Dir.cwd(), io, "./posts", .{.iterate = true});
    var posts_iterator = posts_dir.iterate();
    while (try posts_iterator.next(io))|entry|{
        if (entry.kind == .file){
            std.debug.print("file found in posts : {s}\n", .{entry.name});
            const file_contents = try posts_dir.readFileAlloc(io, entry.name, arena_allocator, .unlimited);
            defer arena_allocator.free(file_contents);
            const blocks = blockSplitter(file_contents, file_contents.len, arena_allocator);
            var page = blocks.page;
            const front_matter = blocks.front_matter;
            defer page.deinit(arena_allocator);
            const page_content = pageCompiler(page, front_matter, arena_allocator);
            defer arena_allocator.free(page_content);
            try posts_dir.writeFile(io,.{.data = page_content,.sub_path = try std.fmt.allocPrint(arena_allocator,"./out/{s}.html",.{entry.name[0..entry.name.len-3]}),.flags = .{}});
            std.debug.print("file compiled : {s}\n", .{entry.name});
        }
    }
}

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
const Field = struct {
    name: []u8,
    content: []u8,
    pub fn parseFieldLine(field_line: []u8) Field {
        var pos: usize = 0;
        var field: Field = undefined;
        while (pos < field_line.len and field_line[pos] != ':') : (pos += 1) {}
        field.name = field_line[0..pos];
        pos += 1;
        while (pos < field_line.len and field_line[pos] == ' ') : (pos += 1) {}
        const start = pos;
        field.content = field_line[start..];
        return field;
    }
};

//Front matter
//title: An Example Using the Tufte Style
//author: beppvis
//description: aksdjakdjskasj
//image: xxx.png
//created: 2026-06-16
//read_time: 25 mins
//slug: an-example-using-the-tufte-style
//style: static/tufte.css
const FrontMatter = struct {
    title: []const u8 = "",
    author: []const u8 = "",
    description: []const u8 ="",
    image: []const u8 ="",
    created: []const u8="",
    read_time: []const u8="",
    slug: []const u8="",
    style: []const u8="",
    pub fn parseFrontMatter(front_matter_block: []u8) FrontMatter {
        assert(front_matter_block.len > 0); 
        var start_field: usize = 0;
        var end_field: usize = 0;
        var pos: usize = 0;
        var front_matter: FrontMatter=.{};
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
                front_matter.created = field.content;
            } else {
                std.debug.print("Unrecognized field.name : {s}\n", .{field.name});
            }
        }
        if (front_matter.author.len == 0 or front_matter.created.len == 0 or front_matter.description.len == 0 or front_matter.read_time.len == 0 or front_matter.image.len == 0 or front_matter.style.len == 0 or front_matter.title.len == 0 ) @panic("Front matter is missing a field");

        return front_matter;
    }
    pub fn compile(self:*const FrontMatter,allocator:Allocator) []u8{
        return std.fmt.allocPrint(allocator, header_format,.{self.title,self.slug,self.title,self.description,self.image,self.title,self.description,self.image,self.slug,self.title,self.created,self.read_time,self.author}) catch @panic("Allocation Error: Front Matter compilation allocation failed");
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
};

pub const ContentBlock = struct {
    type: enum {
        heading,
        section,
    },
    head: []u8,
    content: []u8,
};
pub const Block = struct {
    front_matter: FrontMatter,
    page: std.ArrayList(ContentBlock),
};

pub fn blockSplitter(file_content: []u8, content_size: usize, allocator: Allocator) Block{
    var self: Scanner = .{
        .pos = 0,
        .source = file_content,
        .size = content_size,
    };
    var page: std.ArrayList(ContentBlock) = .empty;
    var front_matter: FrontMatter = undefined;
    var front_matter_captured = false;
    var block_start: usize = 0;

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
            '#' => { //heading checking
                var count: u8 = 1;
                while (self.peek() != '\n' and !self.isAtEnd()) {
                    if (self.advance() != '#') {
                        break;
                    } else {
                        count += 1;
                    }
                }
                const start = self.pos;
                while (self.peek() != '\n') {_=self.advance();}
                if (count == 1) { // H1
                    page.append(allocator, .{
                        .content = "",
                        .head = self.source[start .. self.pos], // ignoring the new line
                        .type = .heading,
                    }) catch unreachable;
                } else if (count == 2) { // H2 -> section
                    if (page.getLastOrNull()) |block| {
                        if (block.type == .section)
                            page.items[page.items.len - 1].content = self.source[block_start .. start - 3];
                    }
                    block_start = self.pos + 1;
                    page.append(allocator, .{
                        .content = self.source[self.pos..],
                        .head = self.source[start .. self.pos ], //ignoring the new line
                        .type = .section,
                    }) catch unreachable;
                }
            },
            else => {},
        }
    }
    return .{.front_matter=front_matter,.page=page};
}



pub fn compileSection(block: ContentBlock, allocator: Allocator) []u8 {
    var self: Scanner = .{
        .pos = 0,
        .source = block.content,
        .size = block.content.len,
    };
    var out: []u8 = "";



    while (!self.isAtEnd()) {
        const char = self.advance();
        switch (char) {
            '[' => {
                const start = self.pos-2;
                if (self.pos > 0 and self.source[self.pos-2]=='!'){
                    while (!self.isAtEnd() ){
                        const c = self.advance();
                        if (c == '\n' or c == ')'){
                            out = std.mem.concat(allocator, u8, &.{out ,self.source[start..self.pos]}) catch unreachable;
                            break;
                        } 
                    }
                    continue;
                }

                if (self.peek() != '^' ) {
                    // its a link 
                    const link_title_start = self.pos;
                    var link_title_stop= self.pos;
                    var link_source_start= self.pos;
                    var link_source_end = self.pos;
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        const c = self.advance();
                        if (c == ']') {
                            link_title_stop= self.pos - 1;
                        } else if (c == '(') {
                            link_source_start = self.pos;
                        } else if (c == ')') {
                            link_source_end= self.pos - 1;
                        }
                    }
                    if (link_source_start > link_source_end or link_title_start > link_title_stop or link_source_end > self.pos) @panic("Fomat Error: Link format is wrong");
                    const link = std.fmt.allocPrint(allocator, "<a href=\"{s}\">{s}</a>", 
                            .{self.source[link_source_start..link_source_end], self.source[link_title_start..link_title_stop]}) catch @panic("Format Error : Link alloc print failed");

                    out = std.mem.concat(allocator, u8, &.{ out, link}) catch unreachable;
                    continue;
                }
                // It is a side note
                const side_note_start = self.pos+1;
                if (side_note_start >= self.size) @panic("Format Error: Side note started, but no end was found");
                // walking back to get a label for the side note 
                const side_note_label_stop = self.pos-1;
                var  i = self.pos-1;
                while (i > 0):(i-=1){
                    if (self.source[i] == ' ') break;
                }
                const side_note_label = self.source[i+1..side_note_label_stop];

                var side_note_stop = side_note_start;

                while (self.peek() != '\n' and !self.isAtEnd()){
                    if (self.advance() == ']'){
                        side_note_stop = self.pos-1;
                    }
                }

                const side_note = std.fmt.allocPrint(allocator, "<label for=\"{s}\" class=\"margin-toggle sidenote-number\"> </label> <input type=\"checkbox\" id=\"{s}\" class=\"margin-toggle\"/> <span class=\"sidenote\"> {s} </span>", .{side_note_label,side_note_label,self.source[side_note_start..side_note_stop]}) catch unreachable;

                out = std.mem.concat(allocator, u8, &.{ out, side_note}) catch unreachable;
            },
            else => {
                out = std.mem.concat(allocator, u8, &.{ out, &.{char} }) catch unreachable;
            },

        }
    }



    const out_with_para:[] u8= compileWithParagraphTag(out,allocator);

    self = .{
        .pos = 0,
        .size = out_with_para.len,
        .source = out_with_para,
    };
    out = "";

    while (!self.isAtEnd()) {
        const char = self.advance();
        switch (char) {
            '`' => {
                var count: u8 = 1;
                var start = self.pos - 1;
                while (self.peek() != '\n' and !self.isAtEnd()) {
                    if (self.advance() == '`') {
                        count += 1;
                    } else {
                        count = 0;
                    }
                    if (count == 3) break;
                }
                if (count != 3) {
                    out = std.mem.concat(allocator, u8, &.{ out, self.source[start..self.pos] }) catch unreachable;
                    continue;
                }
                // it is a code block
                start = self.pos + 1;

                while (!self.isAtEnd()) {
                    if (self.advance() == '`') {
                        count += 1;
                    } else {
                        count = 0;
                    }
                    if (count == 3) break;
                }
                if (count != 3) {
                    out = std.mem.concat(allocator, u8, &.{ out, self.source[start..self.pos] }) catch unreachable;
                    continue;
                }

                const end = self.pos - 4;
                const code_block = std.fmt.allocPrint(allocator, "<pre><code>{s}</code></pre>", .{self.source[start..end]}) catch unreachable;
                out = std.mem.concat(allocator, u8, &.{ out, code_block }) catch unreachable;
            },
            '!' => {
                if (self.peek() != '[') {
                    out = std.mem.concat(allocator, u8, &.{ out, &.{char} }) catch unreachable;
                    continue;
                }
                const alt_text_start = self.pos + 1;
                var alt_text_end = self.pos;
                var image_source_start = self.pos;
                var image_source_end = self.pos;
                while (self.peek() != '\n' and !self.isAtEnd()) {
                    const c = self.advance();
                    if (c == ']') {
                        alt_text_end = self.pos - 1;
                    } else if (c == '(') {
                        image_source_start = self.pos;
                    } else if (c == ')') {
                        image_source_end = self.pos - 1;
                        break;
                    }
                }
                if (alt_text_start > alt_text_end or image_source_start > image_source_end or image_source_end > self.pos){
                    @panic("Format Error: Image link format is wrong");
                }
                if ((alt_text_end - alt_text_start + 1) > 4 and areStringsEqual("full", self.source[alt_text_start .. alt_text_start + 4])) {
                    const image = std.fmt.allocPrint(allocator, full_width_image_format, 
                            .{ self.source[alt_text_start..alt_text_end], 
                            self.source[image_source_start..image_source_end] }) catch @panic("Format Error: image alloc print failed");
                    out = std.mem.concat(allocator, u8, &.{ out, image }) catch unreachable;
                } else {
                    const image = std.fmt.allocPrint(allocator, image_format, 
                    .{ self.source[alt_text_start..alt_text_end], self.source[image_source_start..image_source_end] }) catch @panic("Format Error: image alloc print failed");
                    out = std.mem.concat(allocator, u8, &.{ out, image }) catch unreachable;
                }
            },
            else => {
                out = std.mem.concat(allocator, u8, &.{ out, &.{char} }) catch unreachable;
            },
        }
    }


    return out;
}
pub fn isCodeBlock(scanner: *Scanner) bool{
    var count:u8 = 0;
    while (!scanner.isAtEnd()) {
        if (scanner.advance() == '`') {
            count += 1;
        } else {
            count = 0;
        }
        if (count == 3) break;
    }
    if (count != 3) {
        return false;
    }
    return true;
}
pub fn compileWithParagraphTag(content:[]u8,allocator:Allocator) []u8{
    var scanner:Scanner = .{
        .pos = 0,
        .size = content.len,
        .source = content,
    };
    var out_with_para:[] u8= "";
    var para_start = scanner.pos;
    var character:u8 =' ';
    while (!scanner.isAtEnd()) {
        character = scanner.advance();
        if (character == '\n'){
            para_start = scanner.pos;
            var is_para = true; 
            while (scanner.peek() != '\n' and !scanner.isAtEnd()){
                const char = scanner.advance();
                if (char == '`'){
                    const pos = scanner.pos;
                    if(isCodeBlock(&scanner)){
                        out_with_para = std.mem.concat(allocator, u8, &.{out_with_para,scanner.source[para_start..scanner.pos]}) catch unreachable;
                        is_para = false;
                        break;
                    }
                    else{
                        scanner.pos = pos;
                    }
                }
                else if (char == '!' and scanner.peek() == '['){
                    //const start = scanner.pos;
                    std.debug.print("Found an image in middle of para\n", .{});
                    while (!scanner.isAtEnd() ){
                        const c = scanner.advance();
                        if (c == '\n' or c == ')'){
                            out_with_para = std.mem.concat(allocator, u8, &.{out_with_para,scanner.source[para_start+1..scanner.pos]}) catch unreachable;
                            is_para = false;
                            break;
                        } 
                    }
                }
            }
            if (!is_para) continue;
            if (scanner.peek() == '\n'){
                if (scanner.pos-para_start+1 <= 2 ){
                    out_with_para = std.mem.concat(allocator, u8, &.{out_with_para,scanner.source[para_start..scanner.pos]}) catch unreachable;
                    continue;
                }
                out_with_para = std.mem.concat(allocator, u8, &.{out_with_para,"<p>\n"}) catch unreachable;
                out_with_para = std.mem.concat(allocator, u8, &.{out_with_para,scanner.source[para_start..scanner.pos]}) catch unreachable;
                out_with_para = std.mem.concat(allocator, u8, &.{out_with_para,"\n</p>\n"}) catch unreachable;
            }
        }
        else {
            out_with_para= std.mem.concat(allocator, u8, &.{ out_with_para, &.{character} }) catch unreachable;
        }
    }

    return out_with_para;

}


pub fn pageCompiler(page: std.ArrayList(ContentBlock), front_matter:FrontMatter,allocator: Allocator) []u8 {

    var out: []u8 = "";
    for (page.items) |block| {
        switch (block.type) {
            .heading => {
                const header = std.fmt.allocPrint(allocator, "<h1>{s}</h1>\n", .{block.head}) catch unreachable;
                out = std.mem.concat(allocator, u8, &.{ out, header }) catch unreachable;
            },
            .section => {
                const compiled_content = compileSection(block, allocator);
                out = std.mem.concat(allocator, u8, &.{ out, "<section>\n"}) catch unreachable;
                const header = std.fmt.allocPrint(allocator, "<h2>{s}</h2>\n", .{block.head}) catch unreachable;
                out = std.mem.concat(allocator, u8, &.{ out, header}) catch unreachable;

                out = std.mem.concat(allocator, u8, &.{ out, compiled_content }) catch unreachable;
                out = std.mem.concat(allocator, u8, &.{ out, "</section>\n"}) catch unreachable;
            },
        }
    }
    const compiled_front_matter = front_matter.compile(allocator) ;
    defer allocator.free(compiled_front_matter);
    out = std.mem.concat(allocator, u8, &.{compiled_front_matter,out}) catch unreachable;
    out = std.mem.concat(allocator, u8, &.{out,"</article></body>"}) catch unreachable;

    return out;
}
