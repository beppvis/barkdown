const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const eql = std.mem.eql;
const FrontMatter = @import("front_matter.zig");
const Scanner = @import("scanner.zig");
const Section = @import("page.zig").Section;
const Page = @import("page.zig").Page;

// template
const template = @import("template.zig");
const full_width_image_format = template.full_width_image_format;
const image_format = template.image_format;
const header_format = template.header_format;

pub fn main(init: std.process.Init) !void {
    const io = init.io;
    const gpa_allocator = init.gpa;
    const posts_dir = try std.Io.Dir.openDir(std.Io.Dir.cwd(), io, "./posts", .{.iterate = true});
    var posts_iterator = posts_dir.iterate();
    while (try posts_iterator.next(io))|entry|{
        if (entry.kind == .file){
            std.debug.print("file found in posts : {s}\n", .{entry.name});
            const file_contents = try posts_dir.readFileAlloc(io, entry.name, gpa_allocator, .unlimited);
            defer gpa_allocator.free(file_contents);

            var page:Page = .decomposeToPage(file_contents, file_contents.len, gpa_allocator);
            defer page.deinit(gpa_allocator);

            const page_content = page.compile(gpa_allocator);
            defer gpa_allocator.free(page_content);

            const out_file_path = outFilePath(gpa_allocator,entry.name[0..entry.name.len-3]);
            defer gpa_allocator.free(out_file_path);
            try posts_dir.writeFile(io,.{.data = page_content,.sub_path = out_file_path,.flags = .{}});

            std.debug.print("file compiled : {s}\n", .{entry.name});
        }
    }
}


pub fn outFilePath(allocator:Allocator,file_name:[]const u8) []const u8{
    return std.fmt.allocPrint(allocator,"./out/{s}.html",.{file_name}) catch unreachable;
}


