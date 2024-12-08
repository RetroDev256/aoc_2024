const std = @import("std");
const Allocator = std.mem.Allocator;
const assert = std.debug.assert;

const List = std.ArrayListUnmanaged;

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const gpa = std.heap.page_allocator;

    try day1(stdout, gpa);
    try day2(stdout, gpa);
    try day3(stdout, gpa);
}

fn day1(writer: anytype, gpa: Allocator) !void {
    const ids = @embedFile("day_1.txt");

    // Parsing

    var list_a: List(usize) = .empty;
    defer list_a.deinit(gpa);
    var list_b: List(usize) = .empty;
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

fn day2(writer: anytype, gpa: Allocator) !void {
    const report_file = @embedFile("day_2.txt");

    // Parsing
    var reports: List([]const usize) = .empty;
    defer {
        for (reports.items) |report| {
            gpa.free(report);
        }
        reports.deinit(gpa);
    }

    var report_toker = std.mem.tokenizeScalar(u8, report_file, '\n'); // split by line
    while (report_toker.next()) |report_str| {
        var report: List(usize) = .empty;
        defer report.deinit(gpa);

        var level_toker = std.mem.tokenizeScalar(u8, report_str, ' '); // split by space
        while (level_toker.next()) |level_str| {
            const num = try std.fmt.parseInt(usize, level_str, 10);
            try report.append(gpa, num);
        }

        try reports.append(gpa, try report.toOwnedSlice(gpa));
    }

    // Calculating part one
    var safe_1: usize = 0;
    for (reports.items) |levels| {
        safe_1 += @intFromBool(safeLevelsDay2(levels));
    }
    try writer.print("Day Two Part One: {}\n", .{safe_1});

    // Calculating part two
    var safe_2: usize = 0;
    level_scan: for (reports.items) |levels| {
        if (safeLevelsDay2(levels)) {
            safe_2 += 1;
            continue :level_scan;
        }
        for (0..levels.len) |removed| {
            var report: List(usize) = .empty;
            defer report.deinit(gpa);

            try report.appendSlice(gpa, levels[0..removed]);
            try report.appendSlice(gpa, levels[removed + 1 ..]);

            if (safeLevelsDay2(report.items)) {
                safe_2 += 1;
                continue :level_scan;
            }
        }
    }
    try writer.print("Day Two Part Two: {}\n", .{safe_2});
}

fn safeLevelsDay2(levels: []const usize) bool {
    for (levels[1..], 0..) |level, idx| {
        const level_a: isize = @intCast(levels[idx]);
        const level_b: isize = @intCast(level);
        const diff =
            if (levels[1] > levels[0]) // Increasing
            level_b - level_a
        else
            level_a - level_b; // Decreasing
        if (diff < 1 or diff > 3) {
            return false;
        }
    }
    return true;
}

fn day3(writer: anytype, _: Allocator) !void {
    const memory = @embedFile("day_3.txt");

    var enabled: bool = true;

    // Part One
    var num_1: usize = undefined;
    var num_2: usize = undefined;
    var total: usize = 0;

    // Part Two
    var filtered_total: usize = 0;

    // Parsing
    var idx: usize = 0;
    const State = enum { search, mul, d_word, n1, n2 };
    state: switch (State.search) {
        .search => {
            scan: while (true) switch (memory[idx]) {
                0 => break :state, // end of file
                'm' => continue :state .mul,
                'd' => continue :state .d_word,
                else => {
                    idx += 1; // skip the unknown letter
                    continue :scan;
                },
            };
        },
        .mul => {
            if (std.mem.startsWith(u8, memory[idx..], "mul(")) {
                idx += 4; // skip the mul(
                continue :state .n1;
            } else {
                idx += 1; // skip the m
                continue :state .search;
            }
        },
        .d_word => {
            if (std.mem.startsWith(u8, memory[idx..], "do()")) {
                enabled = true;
                idx += 4; // skip the do()
            } else if (std.mem.startsWith(u8, memory[idx..], "don't()")) {
                enabled = false;
                idx += 7; // skip the don't()
            } else {
                idx += 1; // skip the d
            }
            continue :state .search;
        },
        .n1 => {
            const start = idx;
            if (memory[idx] < '0' or memory[idx] > '9') {
                continue :state .search; // There wasn't a number
            }
            while (memory[idx] >= '0' and memory[idx] <= '9') {
                idx += 1; // skip the digit
            }
            if (memory[idx] == ',') {
                num_1 = try std.fmt.parseInt(usize, memory[start..idx], 10);
                idx += 1; // skip the ,
                continue :state .n2;
            } else continue :state .search;
        },
        .n2 => {
            const start = idx;
            if (memory[idx] < '0' or memory[idx] > '9') {
                continue :state .search; // There wasn't a number
            }
            while (memory[idx] >= '0' and memory[idx] <= '9') {
                idx += 1; // skip the digit
            }
            if (memory[idx] == ')') {
                num_2 = try std.fmt.parseInt(usize, memory[start..idx], 10);
                idx += 1; // skip the )
                total += num_1 * num_2;
                if (enabled) {
                    filtered_total += num_1 * num_2;
                }
            }
            continue :state .search;
        },
    }

    try writer.print("Day Three Part One: {}\n", .{total});
    try writer.print("Day Three Part Two: {}\n", .{filtered_total});
}
