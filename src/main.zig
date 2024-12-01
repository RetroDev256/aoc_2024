const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const alloc = std.heap.page_allocator;

    try day1(stdout, alloc);
}

fn day1(writer: anytype, gpa: Allocator) !void {
    const ids = @embedFile("day_1.txt");

    // Parsing

    var list_a: std.ArrayListUnmanaged(usize) = .empty;
    defer list_a.deinit(gpa);
    var list_b: std.ArrayListUnmanaged(usize) = .empty;
    defer list_b.deinit(gpa);

    var lines = std.mem.tokenizeScalar(u8, ids, '\n'); // Split by line
    while (lines.next()) |line| {
        var numbers = std.mem.tokenizeScalar(u8, line, ' '); // split by space

        const num_a = try std.fmt.parseInt(usize, numbers.next().?, 10);
        const num_b = try std.fmt.parseInt(usize, numbers.next().?, 10);

        assert(numbers.next() == null);

        try list_a.append(gpa, num_a);
        try list_b.append(gpa, num_b);
    }

    const lessThanFn = std.sort.asc(usize);
    std.mem.sortUnstable(usize, list_a.items, void{}, lessThanFn);
    std.mem.sortUnstable(usize, list_b.items, void{}, lessThanFn);

    // Calculating part one

    var total_error: usize = 0;
    for (list_a.items, list_b.items) |a, b| {
        const diff = @max(a, b) - @min(a, b);
        total_error += diff;
    }

    try writer.print("Day One Part One: {}\n", .{total_error});

    // Calculating part two

    var similarity_score: usize = 0;
    for (list_a.items) |a| {
        var occurances: usize = 0;
        search: for (list_b.items) |b| {
            if (b == a) occurances += 1;
            if (b > a) break :search; // both are sorted ascending
        }
        similarity_score += a * occurances;
    }

    try writer.print("Day One Part Two: {}\n", .{similarity_score});
}
