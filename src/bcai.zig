const std = @import("std");
const List = std.ArrayList;

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

const Individual = struct {
    code: []u8,
    fitness: i32,
};

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
    OutOfMemory,
};

pub const State = struct {
    const Self = @This();
    allocator: std.mem.Allocator,
    rand: std.Random,
    population: []*Individual,
    best_individual: *Individual,
    max_instruction_count: usize,
    stack_size: usize,
    population_size: usize,
    code_len: usize,

    pub fn init(
        allocator: std.mem.Allocator,
        max_instruction_count: usize,
        stack_size: usize,
        population_size: usize,
        code_len: usize,
    ) !*Self {
        var prng = std.rand.DefaultPrng.init(blk: {
            var seed: u64 = undefined;
            try std.posix.getrandom(std.mem.asBytes(&seed));
            break :blk seed;
        });
        const rand = prng.random();

        var result = try allocator.create(Self);
        result.allocator = allocator;
        result.rand = rand;
        result.population = try allocator.alloc(*Individual, population_size);
        try init_population(allocator, &rand, result.population, population_size, code_len);
        result.best_individual = result.population[0];
        result.max_instruction_count = max_instruction_count;
        result.stack_size = stack_size;
        result.population_size = population_size;
        result.code_len = code_len;
        return result;
    }

    fn init_population(allocator: std.mem.Allocator, rand: *const std.Random, population: []*Individual, population_size: usize, code_size: usize) !void {
        for (0..population_size) |i| {
            var ind = try allocator.create(Individual);
            ind.code = try allocator.alloc(u8, code_size);
            for (0..code_size) |j| {
                if (j < code_size - 1) {
                    ind.code[j] = rand.int(u8) % (@intFromEnum(Instruction.MAX_INST) - 1); // Exclude HALT from random initialization
                } else {
                    ind.code[j] = @intFromEnum(Instruction.HALT); // Ensure HALT at the end for safety
                }
            }
            ind.fitness = std.math.maxInt(i32);
            population[i] = ind;
        }
    }

    pub fn execute(self: *Self, ind: *Individual, input_size: usize, inputs: []const i32, output_size: usize) ExecuteError![]i32 {
        var instruction: usize = 0;
        var stack: []i32 = try self.allocator.alloc(i32, self.stack_size);
        var sp: usize = 0;
        var outputs: []i32 = try self.allocator.alloc(i32, output_size);

        const max_inst = @intFromEnum(Instruction.MAX_INST);
        var pc: usize = 0;
        while (pc < self.code_len) {
            if (ind.code[pc] >= max_inst) {
                continue;
            }
            const current = @as(Instruction, @enumFromInt(ind.code[pc]));
            if (current == Instruction.HALT) {
                break;
            }
            var addr: usize = undefined;
            switch (@as(Instruction, @enumFromInt(ind.code[inc(&pc, 1)]))) {
                .PUSH => {
                    if (sp < self.stack_size) {
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
                            stack[sp - 2] = 0;
                        } else {
                            stack[sp - 2] = @divTrunc(stack[sp - 2], stack[sp - 1]);
                        }
                        sp -= 1;
                    }
                },
                .LOAD => {
                    addr = ind.code[inc(&pc, 1)] % input_size;
                    if (sp < self.stack_size) {
                        stack[inc(&sp, 1)] = inputs[addr];
                    }
                },
                .STORE => {
                    addr = ind.code[inc(&pc, 1)] % output_size;
                    if (sp > 0) {
                        outputs[addr] = stack[dec(&sp, 1)];
                    }
                },
                .JMP => {
                    addr = ind.code[inc(&pc, 1)] % output_size;
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
            if (instruction > self.max_instruction_count) {
                return ExecuteError.MaxInstructionsReached;
            }
        }
        return outputs;
    }
};
