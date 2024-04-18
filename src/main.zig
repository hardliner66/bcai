// [RUN] zig run-exe %

const std = @import("std");

const C_MAX_INSTRUCTION_COUNT = 1000;
const C_POP_SIZE = 100;
const C_CODE_LEN = 100;
const C_MAX_GEN = 100;
const C_MUTATION_RATE = 20;
const C_STACK_SIZE = 100;
const C_INPUT_SIZE = 5;
const C_OUTPUT_SIZE = 5;

const Instruction = enum {
    PUSH,
    ADD,
    SUB,
    MUL,
    DIV,
    LOAD,
    STORE,
    JMP,
    JZ,
    JNZ,
    CMP_EQ,
    CMP_NE,
    CMP_GT,
    CMP_LT,
    WRITE,
    HALT,
    MAX_INST,
};

fn Individual(comptime CODE_LEN: usize) type {
    return struct {
        code: [CODE_LEN]u8,
        fitness: i32,
    };
}

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

fn inc(v: *usize, by: usize) usize {
    const old = v.*;
    v.* += by;
    return old;
}

fn dec(v: *usize, by: usize) usize {
    const old = v.*;
    v.* -= by;
    return old;
}

const ExecuteError = error{
    DivisionByZero,
    MaxInstructionsReached,
};

fn State(
    comptime INPUT_SIZE: usize,
    comptime OUTPUT_SIZE: usize,
    comptime MAX_INSTRUCTION_COUNT: usize,
    comptime STACK_SIZE: usize,
    comptime POPULATION_SIZE: usize,
    comptime CODE_LEN: usize,
) type {
    return struct {
        const Self = @This();
        rand: std.Random,
        population: [POPULATION_SIZE]Individual(CODE_LEN),
        best_individual: *Individual(CODE_LEN),
        inputs: [INPUT_SIZE]i32,

        pub fn init(inputs: [INPUT_SIZE]i32) !Self {
            var prng = std.rand.DefaultPrng.init(blk: {
                var seed: u64 = undefined;
                try std.posix.getrandom(std.mem.asBytes(&seed));
                break :blk seed;
            });
            const rand = prng.random();

            var population: [POPULATION_SIZE]Individual(CODE_LEN) = .{Individual(CODE_LEN){ .code = .{0} ** CODE_LEN, .fitness = 1.0 }} ** POPULATION_SIZE;
            init_population(&rand, &population);

            const best_individual = &population[0];

            return .{
                .rand = rand,
                .population = population,
                .best_individual = best_individual,
                .inputs = inputs,
            };
        }

        fn init_population(rand: *const std.Random, population: *[POPULATION_SIZE]Individual(CODE_LEN)) void {
            for (0..POPULATION_SIZE) |i| {
                for (0..CODE_LEN) |j| {
                    if (j < CODE_LEN - 1) {
                        population[i].code[j] = rand.int(u8) % (@intFromEnum(Instruction.MAX_INST) - 1); // Exclude HALT from random initialization
                    } else {
                        population[i].code[j] = @intFromEnum(Instruction.HALT); // Ensure HALT at the end for safety
                    }
                }
                population[i].fitness = std.math.maxInt(i32);
            }
        }

        pub fn execute(self: *Self, ind: *Individual(CODE_LEN)) ExecuteError![OUTPUT_SIZE]i32 {
            var instruction: usize = 0;
            var stack: [STACK_SIZE]i32 = .{0} ** STACK_SIZE;
            var sp: usize = 0;
            var outputs: [OUTPUT_SIZE]i32 = .{0} ** OUTPUT_SIZE;

            var pc: usize = 0;
            while (pc < CODE_LEN and @as(Instruction, @enumFromInt(ind.code[pc])) != Instruction.HALT) {
                var addr: usize = undefined;
                switch (@as(Instruction, @enumFromInt(ind.code[inc(&pc, 1)]))) {
                    .PUSH => {
                        if (sp < STACK_SIZE) {
                            stack[inc(&sp, 1)] = ind.code[inc(&pc, 1)];
                        }
                    },
                    .ADD => {
                        if (sp > 1) {
                            stack[sp - 2] = @addWithOverflow(stack[sp - 2], stack[sp - 1])[0];
                            sp -= 1;
                        }
                    },
                    .SUB => {
                        if (sp > 1) {
                            stack[sp - 2] = @subWithOverflow(stack[sp - 2], stack[sp - 1])[0];
                            sp -= 1;
                        }
                    },
                    .MUL => {
                        if (sp > 1) {
                            stack[sp - 2] = @mulWithOverflow(stack[sp - 2], stack[sp - 1])[0];
                            sp -= 1;
                        }
                    },
                    .DIV => {
                        if (sp > 1) {
                            if (stack[sp - 1] == 0) {
                                return ExecuteError.DivisionByZero;
                            }
                            stack[sp - 2] = @divTrunc(stack[sp - 2], stack[sp - 1]);
                            sp -= 1;
                        }
                    },
                    .LOAD => {
                        addr = ind.code[inc(&pc, 1)] % INPUT_SIZE;
                        if (sp < STACK_SIZE) {
                            stack[inc(&sp, 1)] = self.inputs[addr];
                        }
                    },
                    .STORE => {
                        addr = ind.code[inc(&pc, 1)] % OUTPUT_SIZE;
                        if (sp > 0) {
                            outputs[addr] = stack[dec(&sp, 1)];
                        }
                    },
                    .JMP => {
                        addr = ind.code[inc(&pc, 1)] % OUTPUT_SIZE;
                        pc += addr;
                    },
                    .JZ => {
                        if (sp > 0 and stack[sp - 1] == 0) {
                            sp -= 1;
                            pc += ind.code[inc(&pc, 1)];
                        } else {
                            pc += 1;
                        }
                    },
                    .JNZ => {
                        if (sp > 0 and stack[sp - 1] != 0) {
                            sp -= 1;
                            pc += ind.code[inc(&pc, 1)];
                        } else {
                            pc += 1;
                        }
                    },
                    .CMP_EQ => {
                        if (sp > 1) {
                            stack[sp - 2] = if (stack[sp - 2] == stack[sp - 1]) 1 else 0;
                            sp -= 1;
                        }
                    },
                    .CMP_NE => {
                        if (sp > 1) {
                            stack[sp - 2] = if (stack[sp - 2] != stack[sp - 1]) 1 else 0;
                            sp -= 1;
                        }
                    },
                    .CMP_GT => {
                        if (sp > 1) {
                            stack[sp - 2] = if (stack[sp - 2] > stack[sp - 1]) 1 else 0;
                            sp -= 1;
                        }
                    },
                    .CMP_LT => {
                        if (sp > 1) {
                            stack[sp - 2] = if (stack[sp - 2] < stack[sp - 1]) 1 else 0;
                            sp -= 1;
                        }
                    },
                    else => {},
                }
                instruction += 1;
                if (instruction > MAX_INSTRUCTION_COUNT) {
                    return ExecuteError.MaxInstructionsReached;
                }
            }
            return outputs;
        }
    };
}

pub fn main() !void {
    const inputs: [C_INPUT_SIZE]i32 = .{ 1, 2, 3, 4, 5 };
    var state = try State(
        C_INPUT_SIZE,
        C_OUTPUT_SIZE,
        C_MAX_INSTRUCTION_COUNT,
        C_STACK_SIZE,
        C_POP_SIZE,
        C_CODE_LEN,
    ).init(inputs);
    const outputs = state.execute(state.best_individual) catch .{0} ** C_OUTPUT_SIZE;

    println("{any}", .{outputs});
}
