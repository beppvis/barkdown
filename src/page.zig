const FrontMatter = @import("front_matter.zig");
const std = @import("std");
const Allocator = std.mem.Allocator;
const Scanner = @import("scanner.zig");
const eql = std.mem.eql;
const assert = std.debug.assert;

const template = @import("template.zig");
const full_width_image_format = template.full_width_image_format;
const image_format = template.image_format;
const header_format = template.header_format;
const side_note_format = template.side_note_format;
const code_block_format = template.code_block_format;


// this assumes that a is heap allocated
pub fn concatAndFree(allocator:Allocator,a:[]const u8,b:[]const u8) ![]u8{
    const out = try std.mem.concat(allocator, u8, &.{a,b}) ;
    errdefer allocator.free(out);
    allocator.free(a);
    return out;
}


pub const Section = struct {
    type: enum {
        heading,
        section,
    },
    head: []const u8,
    content: []const u8,

    pub fn compileSection(block: Section, allocator: Allocator) []u8 {
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
                                out = concatAndFree(allocator, out, self.source[start..self.pos]) catch unreachable;
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
                        defer allocator.free(link);

                        out = concatAndFree(allocator, out, link) catch unreachable;
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

                    const side_note = std.fmt.allocPrint(allocator,side_note_format, .{side_note_label,side_note_label,self.source[side_note_start..side_note_stop]}) catch unreachable;

                    defer allocator.free(side_note);
                    out = concatAndFree(allocator, out, side_note) catch unreachable;
                },
                '#'=> {
                    var count: u8 = 1;
                    while (self.peek() != '\n' and !self.isAtEnd()) {
                        if (self.advance() != '#') {
                            break;
                        } else {
                            count += 1;
                        }
                    }
                    const start = self.pos;
                    while (self.peek() != '\n' and !self.isAtEnd()) _ = self.advance();
                    if (count > 2){ // h2 is already used to make a section 
                        const heading = std.fmt.allocPrint(allocator, "<h{d}>{s}</h{d}>",.{count,self.source[start .. self.pos],count}) catch unreachable;
                        defer allocator.free(heading);
                        out = concatAndFree(allocator,out,heading) catch unreachable; // ignoring the new line
                    }
                    else {
                        assert(start-(count+1) > 0); // there is space before the #
                        out = concatAndFree(allocator,out,self.source[start-(count+1) .. self.pos]) catch unreachable; // ignoring the new line

                    }

                },
                else => {
                    out = concatAndFree(allocator, out, &.{char} ) catch unreachable;
                },

            }
        }



        const out_with_para:[] u8= compileWithParagraphTag(out,allocator);
        defer allocator.free(out_with_para);

        self = .{
            .pos = 0,
            .size = out_with_para.len,
            .source = out_with_para,
        };
        allocator.free(out);
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
                        out = concatAndFree(allocator, out, self.source[start..self.pos] ) catch unreachable;
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
                        out = concatAndFree(allocator,  out, self.source[start..self.pos]) catch unreachable;
                        continue;
                    }

                    const end = self.pos - 4;
                    const code_block = std.fmt.allocPrint(allocator,code_block_format, .{self.source[start..end]}) catch unreachable;
                    defer allocator.free(code_block);
                    out = concatAndFree(allocator,  out, code_block ) catch unreachable;
                },
                '!' => {
                    if (self.peek() != '[') {
                        out = concatAndFree(allocator,  out, &.{char} ) catch unreachable;
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


                    if ((alt_text_end - alt_text_start + 1) > 4 and eql(u8,"full", self.source[alt_text_start .. alt_text_start + 4])) {
                        const image = std.fmt.allocPrint(allocator, full_width_image_format, 
                                .{ self.source[alt_text_start..alt_text_end], 
                                self.source[image_source_start..image_source_end] }) catch @panic("Format Error: image alloc print failed");
                        defer allocator.free(image);
                        out = concatAndFree(allocator, out, image ) catch unreachable;
                    } else {
                        const image = std.fmt.allocPrint(allocator, image_format, 
                        .{ self.source[alt_text_start..alt_text_end], self.source[image_source_start..image_source_end] }) catch @panic("Format Error: image alloc print failed");
                        defer allocator.free(image);
                        out = concatAndFree(allocator,  out, image ) catch unreachable;
                    }

                },
                else => {
                    out = concatAndFree(allocator, out, &.{char}) catch unreachable;
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
                            out_with_para = concatAndFree(allocator,out_with_para,scanner.source[para_start..scanner.pos]) catch unreachable;
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
                                out_with_para = concatAndFree(allocator, out_with_para,scanner.source[para_start+1..scanner.pos]) catch unreachable;
                                is_para = false;
                                break;
                            } 
                        }
                    }
                }
                if (!is_para) continue;
                if (scanner.peek() == '\n'){
                    if (scanner.pos-para_start+1 <= 2 ){
                        out_with_para = concatAndFree(allocator, out_with_para,scanner.source[para_start..scanner.pos]) catch unreachable;
                        continue;
                    }
                    out_with_para = concatAndFree(allocator, out_with_para,"<p>\n") catch unreachable;
                    out_with_para = concatAndFree(allocator, out_with_para,scanner.source[para_start..scanner.pos]) catch unreachable;
                    out_with_para = concatAndFree(allocator, out_with_para,"\n</p>\n") catch unreachable;
                }
            }
            else {
                out_with_para= concatAndFree(allocator, out_with_para, &.{character} ) catch unreachable;
            }
        }

        return out_with_para;

    }


    };
pub const Page = struct {
    front_matter: FrontMatter,
    contents: std.ArrayList(Section),
    pub fn deinit(page:*Page,allocator:Allocator) void{
        page.contents.deinit(allocator);
    }

    // Split markdown into front matter
    // and blocks
    pub fn decomposeToPage(file_content: []const u8, content_size: usize, allocator: Allocator) Page {
        var self: Scanner = .{
            .pos = 0,
            .source = file_content,
            .size = content_size,
        };
        var page:Page = .{
            .front_matter = undefined,
            .contents =  .empty,
        };
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
                        page.front_matter = FrontMatter.parseFrontMatter(self.getFrontMatter());
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
                        page.contents.append(allocator, .{
                            .content = "",
                            .head = self.source[start .. self.pos], // ignoring the new line
                            .type = .heading,
                        }) catch unreachable;
                    } else if (count == 2) { // H2 -> section
                        if (page.contents.getLastOrNull()) |block| {
                            if (block.type == .section)
                                page.contents.items[page.contents.items.len - 1].content = self.source[block_start .. start - 3];
                        }
                        block_start = self.pos + 1;
                        page.contents.append(allocator, .{
                            .content = self.source[self.pos..],
                            .head = self.source[start .. self.pos ], //ignoring the new line
                            .type = .section,
                        }) catch unreachable;
                    }
                },
                else => {},
            }
        }
        return page;
    }

    pub fn compile(page: Page,allocator: Allocator) []const u8 {

        var out: []const u8 = "";
        for (page.contents.items) |section| {
            switch (section.type) {
                .heading => {
                    const header = std.fmt.allocPrint(allocator, "<h1>{s}</h1>\n", .{section.head}) catch unreachable;
                    defer allocator.free(header);

                    out = concatAndFree(allocator, out, header ) catch unreachable;
                },
                .section => {
                    const compiled_content = section.compileSection(allocator);
                    defer allocator.free(compiled_content);
                    out = concatAndFree(allocator,  out, "<section>\n") catch unreachable;
                    const header = std.fmt.allocPrint(allocator, "<h2>{s}</h2>\n", .{section.head}) catch unreachable;
                    defer allocator.free(header);

                    out = concatAndFree(allocator,  out, header) catch unreachable;
                    out = concatAndFree(allocator, out, compiled_content ) catch unreachable;
                    out = concatAndFree(allocator, out, "</section>\n") catch unreachable;
                },
            }
        }
        const compiled_front_matter:[]u8 = page.front_matter.compile(allocator) ;
        const old  = out;
        out = concatAndFree(allocator, compiled_front_matter,out) catch unreachable;
        allocator.free(old);
        out = concatAndFree(allocator, out,"</article></body>") catch unreachable;

        return out;
    }
};


