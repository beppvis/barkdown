const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const header_format = @import("template.zig").header_format;

const Field = struct {
    name: []const u8,
    content: []const u8,
    pub fn parseFieldLine(field_line: []const u8) Field {
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
const FrontMatter = @This();

//Front matter
//title: An Example Using the Tufte Style
//author: beppvis
//description: aksdjakdjskasj
//image: xxx.png
//created: 2026-06-16
//read_time: 25 mins
//slug: an-example-using-the-tufte-style
//style: static/tufte.css
title: []const u8 = "",
author: []const u8 = "",
description: []const u8 ="",
image: []const u8 ="",
created: []const u8="",
read_time: []const u8="",
slug: []const u8="",
style: []const u8="",
pub fn parseFrontMatter(front_matter_block: []const u8) FrontMatter {
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
        if (eql(u8,field.name, "title")) {
            front_matter.title = field.content;
        } else if (eql(u8,field.name, "author")) {
            front_matter.author = field.content;
        } else if (eql(u8,field.name, "description")) {
            front_matter.description = field.content;
        } else if (eql(u8,field.name, "image")) {
            front_matter.image = field.content;
        } else if (eql(u8,field.name, "read_time")) {
            front_matter.read_time = field.content;
        } else if (eql(u8,field.name, "slug")) {
            front_matter.slug = field.content;
        } else if (eql(u8,field.name, "style")) {
            front_matter.style = field.content;
        } else if (eql(u8,field.name, "created")) {
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
