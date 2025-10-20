const std = @import("std");
const avformat = @import("avformat");

pub fn video_duration(pFormatCtx: [*c][*c]avformat.AVFormatContext, filename: [*c]const u8) f64 {
    if (avformat.avformat_open_input(pFormatCtx, filename, null, null) != 0)
        return 0;
    if (avformat.avformat_find_stream_info(pFormatCtx.*, null) < 0)
        return 0;
    const duration: f64 = @floatFromInt(pFormatCtx.*.*.duration);
    avformat.avformat_close_input(pFormatCtx);
    return duration / 1000000.0;
}

pub fn folder_duration(allocator: std.mem.Allocator, io: std.Io, pFormatCtx: [*c][*c]avformat.AVFormatContext, filename: []const u8) anyerror!f64 {
    var seconds: f64 = 0;
    var dir = try std.Io.Dir.openDir(.cwd(), io, filename, .{ .iterate = true });
    var walker = try dir.walk(allocator);
    defer walker.deinit();
    while (try walker.next(io)) |entry| {
        const path = entry.path;
        const complete_path = try std.fmt.allocPrint(allocator, "{s}/{s}", .{ filename, path });
        const data = try allocator.dupeSentinel(u8, complete_path, 0);
        defer allocator.free(complete_path);
        defer allocator.free(data);
        switch (entry.kind) {
            .file => seconds += video_duration(pFormatCtx, data),
            else => {},
        }
    }
    return seconds;
}

pub fn main(init: std.process.Init) !void {
    avformat.av_log_set_level(avformat.AV_LOG_WARNING);

    const alloc = init.gpa;
    const io = init.io;

    // Iterate over command line arguments using the new Args API
    var it = try std.process.Args.Iterator.initAllocator(init.minimal.args, alloc);
    defer it.deinit();

    var pFormatCtx = avformat.avformat_alloc_context();
    defer avformat.avformat_free_context(pFormatCtx);


    // Skip argv[0] (program name), like args[1..] did
    _ = it.skip();
    while (it.next()) |arg| {
        const stat = try std.Io.Dir.statFile(.cwd(), io, arg, .{});
        const seconds = switch (stat.kind) {
            .file => video_duration(&pFormatCtx, arg),
            .directory => try folder_duration(alloc, io, &pFormatCtx, arg),
            else => 0,
        };
        const formatted = try std.fmt.allocPrint(alloc, "{s}: {d:.0}:{d:0>2.0}:{d:0>2.0}\n", .{ arg, @divFloor(seconds, 3600), @mod(@divFloor(seconds, 60), 60), @mod(seconds, 60) });
        defer alloc.free(formatted);
        try std.Io.File.writeStreamingAll(.stdout(), io, formatted);
    }
}

test "folder duration test" {
    const expected = 0;

    const alloc = std.heap.c_allocator;

    var pFormatCtx = avformat.avformat_alloc_context();
    defer avformat.avformat_free_context(pFormatCtx);

    const len = try folder_duration(alloc, null, &pFormatCtx, ".");

    try std.testing.expectEqual(len, expected);
}
