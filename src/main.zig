const std = @import("std");
const avformat = @cImport({
    @cInclude("libavformat/avformat.h");
});

pub fn video_duration(pFormatCtx: [*c][*c]avformat.AVFormatContext, filename: [*c]const u8) f64 {
    if (avformat.avformat_open_input(pFormatCtx, filename, null, null) != 0)
        return 0;
    if (avformat.avformat_find_stream_info(pFormatCtx.*,null) < 0)
        return 0;
    const duration: f64 = @floatFromInt(pFormatCtx.*.*.duration);
    avformat.avformat_close_input(pFormatCtx);
    return duration / 1000000.0;
}
pub fn folder_duration(allocator: std.mem.Allocator, pFormatCtx: [*c][*c]avformat.AVFormatContext, filename: []const u8) anyerror!f64 {
    var seconds: f64 = 0;
    var dir = try std.fs.cwd().openDir(filename, .{ .iterate = true });
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next()) |entry| {
        const path = entry.path;
        const complete_path = try std.fmt.allocPrintZ(allocator, "{s}/{s}", .{ filename, path });
        defer allocator.free(complete_path);
        switch (entry.kind) {
            .file => seconds += video_duration(pFormatCtx, complete_path),
            else => {},
        }
    }
    return seconds;
}
pub fn main() anyerror!void {
    const alloc = std.heap.c_allocator;

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    var pFormatCtx = avformat.avformat_alloc_context();
    defer avformat.avformat_free_context(pFormatCtx);

    const stdout = std.io.getStdOut().writer();

    for (args[1..]) |arg| {
        const stat = try std.fs.cwd().statFile(arg);
        const seconds = switch (stat.kind) {
            .file => video_duration(&pFormatCtx, arg),
            .directory => try folder_duration(alloc, &pFormatCtx, arg),
            else => 0,
        };
        try stdout.print("{s}: {d:.0}:{d:0>2.0}:{d:0>2.0}\n", .{ arg, @divFloor(seconds, 3600), @mod(@divFloor(seconds, 60), 60), @mod(seconds, 60) });
    }
}
test "folder duration test" {
    const expected = 0;

    const alloc = std.heap.c_allocator;

    var pFormatCtx = avformat.avformat_alloc_context();
    defer avformat.avformat_free_context(pFormatCtx);

    const len = try folder_duration(alloc, &pFormatCtx, ".");

    try std.testing.expectEqual(len, expected);
}
