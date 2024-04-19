const std = @import("std");
const bcai = @import("bcai");

const C_MAX_INSTRUCTION_COUNT = 1000;
const C_POP_SIZE = 100;
const C_CODE_LEN = 100;
const C_MAX_GEN = 100;
const C_MUTATION_RATE = 20;
const C_STACK_SIZE = 100;
const C_INPUT_SIZE = 5;
const C_OUTPUT_SIZE = 5;

fn print(comptime format: []const u8, args: anytype) void {
    const stdout_file = std.io.getStdOut().writer();
    var bw = std.io.bufferedWriter(stdout_file);
    const stdout = bw.writer();

    stdout.print(format, args) catch {};

    bw.flush() catch {};
}

fn println(comptime format: []const u8, args: anytype) void {
    print(format ++ "\n", args);
}

fn eprint(comptime format: []const u8, args: anytype) void {
    const stderr_file = std.io.getStdErr().writer();
    var bw = std.io.bufferedWriter(stderr_file);
    const stdout = bw.writer();

    stdout.print(format, args) catch {};

    bw.flush() catch {};
}

fn eprintln(comptime format: []const u8, args: anytype) void {
    eprint(format ++ "\n", args);
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const allocator = gpa.allocator();
    var state = try bcai.State.init(
        allocator,
        C_MAX_INSTRUCTION_COUNT,
        C_STACK_SIZE,
        C_POP_SIZE,
        C_CODE_LEN,
    );
    const inputs = [_]i32{ 1, 2, 3, 4, 5 };
    const outputs = try state.execute(state.best_individual, C_INPUT_SIZE, &inputs, C_OUTPUT_SIZE);

    println("{any}", .{outputs});
}
