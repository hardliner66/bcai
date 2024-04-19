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

export fn init() *anyopaque {
    const allocator = std.heap.c_allocator;
    const state = bcai.State.init(
        allocator,
        C_MAX_INSTRUCTION_COUNT,
        C_STACK_SIZE,
        C_POP_SIZE,
        C_CODE_LEN,
    );
    return @ptrCast(state catch null);
}
