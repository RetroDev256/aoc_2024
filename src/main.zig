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
    try day4(stdout, gpa);
    try day5(stdout, gpa);
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

fn day4(writer: anytype, _: Allocator) !void {
    const search = @embedFile("day_4.txt");

    // Parsing
    const width = comptime std.mem.indexOfScalar(u8, search, '\n').?;
    const height = search.len / (width + 1);
    assert(search.len == (width + 1) * height); // Include one for newline

    // Part one
    var part_1: usize = 0;
    const word = "XMAS";

    // Evaluating
    for (0..height) |y| {
        for (0..width) |x| {
            // Check all 8 directions
            for (0..3) |sub_y| {
                for (0..3) |sub_x| {
                    const dx = @as(isize, @intCast(sub_x)) - 1;
                    const dy = @as(isize, @intCast(sub_y)) - 1;
                    // skip iterating over the same index
                    if (dx == 0 and dy == 0) continue;
                    // Skip directions that would run into a wall
                    if (dx == -1 and x < (word.len - 1)) continue;
                    if (dy == -1 and y < (word.len - 1)) continue;
                    if (dx == 1 and x > width - word.len) continue;
                    if (dy == 1 and y > height - word.len) continue;
                    // Collect the letters
                    var letters: [word.len]u8 = undefined;
                    for (0..word.len) |i| {
                        const mult: isize = @intCast(i);
                        const x_off: isize = @as(isize, @intCast(x)) + dx * mult;
                        const y_off: isize = @as(isize, @intCast(y)) + dy * mult;
                        // Include 1 extra symbol per line for newline
                        const index = x_off + y_off * @as(isize, @intCast(width + 1));
                        letters[i] = search[@intCast(index)];
                    }
                    // Evaluate & add
                    part_1 += @intFromBool(std.mem.eql(u8, &letters, word));
                }
            }
        }
    }
    try writer.print("Day Four Part One: {}\n", .{part_1});

    // Part two (I kinda gave up on big brain here)
    var part_2: usize = 0;

    for (0..height - 2) |y| {
        // Multiply by y and add x to get the index
        const y_mul: usize = width + 1; // account for newline
        for (0..width - 2) |x| {
            const center = (x + 1) + (y + 1) * y_mul;
            const top_left = (x + 0) + (y + 0) * y_mul;
            const top_right = (x + 2) + (y + 0) * y_mul;
            const bot_left = (x + 0) + (y + 2) * y_mul;
            const bot_right = (x + 2) + (y + 2) * y_mul;

            // The A is always center
            if (search[center] != 'A') continue;

            // Select the right cross shape
            if (search[top_left] == 'M') {
                if (search[top_right] == 'M') {
                    // M.M (checked)
                    // .A. (checked)
                    // S.S
                    if (search[bot_left] != 'S') continue;
                    if (search[bot_right] != 'S') continue;
                    part_2 += 1;
                } else if (search[top_right] == 'S') {
                    // M.S (checked)
                    // .A. (checked)
                    // M.S
                    if (search[bot_left] != 'M') continue;
                    if (search[bot_right] != 'S') continue;
                    part_2 += 1;
                }
            } else if (search[top_left] == 'S') {
                if (search[top_right] == 'M') {
                    // S.M (checked)
                    // .A. (checked)
                    // S.M
                    if (search[bot_left] != 'S') continue;
                    if (search[bot_right] != 'M') continue;
                    part_2 += 1;
                } else if (search[top_right] == 'S') {
                    // S.S (checked)
                    // .A. (checked)
                    // M.M
                    if (search[bot_left] != 'M') continue;
                    if (search[bot_right] != 'M') continue;
                    part_2 += 1;
                }
            }
        }
    }
    try writer.print("Day Four Part Two: {}\n", .{part_2});
}

fn day5(writer: anytype, gpa: Allocator) !void {
    const day5_input = @embedFile("day_5.txt");

    var splitter = std.mem.tokenizeSequence(u8, day5_input, "\n\n");
    const first = splitter.next().?; // contains the first part
    const second = splitter.next().?; // contains the second part
    assert(splitter.next() == null);

    var ordering: List(struct { u8, u8 }) = .empty;
    defer ordering.deinit(gpa);

    // parse the input into each ordering of pages
    var first_lines = std.mem.tokenizeScalar(u8, first, '\n'); // split by line
    while (first_lines.next()) |order| {
        var pages = std.mem.tokenizeScalar(u8, order, '|');
        const first_page = try std.fmt.parseInt(u8, pages.next().?, 10);
        const second_page = try std.fmt.parseInt(u8, pages.next().?, 10);
        assert(pages.next() == null);

        try ordering.append(gpa, .{ first_page, second_page });
    }

    var correct_updates: List(List(u8)) = .empty;
    defer correct_updates.deinit(gpa);
    defer for (correct_updates.items) |*pages| pages.deinit(gpa);

    var incorrect_updates: List(List(u8)) = .empty;
    defer incorrect_updates.deinit(gpa);
    defer for (incorrect_updates.items) |*pages| pages.deinit(gpa);

    var second_lines = std.mem.tokenizeScalar(u8, second, '\n');
    while (second_lines.next()) |update| {
        var pages: List(u8) = .empty;

        // load each page into memory
        var page_toker = std.mem.tokenizeScalar(u8, update, ',');
        while (page_toker.next()) |page_str| {
            const page = try std.fmt.parseInt(u8, page_str, 10);
            try pages.append(gpa, page);
        }

        var correct: bool = true;

        // see if the update follows the rules
        rule_check: for (pages.items, 0..) |page, i| {
            for (ordering.items) |order| {
                if (page == order[0]) {
                    // verify there are none of order[1] before page
                    for (0..i) |check_i| {
                        if (pages.items[check_i] == order[1]) {
                            // incorrect ordering
                            correct = false;
                            break :rule_check;
                        }
                    }
                }
            }
        }

        if (correct) {
            try correct_updates.append(gpa, pages);
        } else {
            try incorrect_updates.append(gpa, pages);
        }
    }

    var p1: u32 = 0;
    for (correct_updates.items) |update| {
        p1 += update.items[update.items.len / 2];
    }
    try writer.print("Day Five Part One: {}\n", .{p1});

    // correct the updating of the pages & print out the sum of the middle pages again
    var p2: u32 = 0;
    for (incorrect_updates.items) |update| {
        var corrected: List(u8) = try update.clone(gpa);
        defer corrected.deinit(gpa);

        std.mem.sortUnstable(u8, corrected.items, ordering, lessThanDay5);

        p2 += corrected.items[corrected.items.len / 2];
    }
    try writer.print("Day Five Part Two: {}\n", .{p2});
}

fn lessThanDay5(ordering: List(struct { u8, u8 }), lhs: u8, rhs: u8) bool {
    for (ordering.items) |order| {
        if (order[0] == lhs and order[1] == rhs) {
            return true;
        }
    }
    return false;
}
