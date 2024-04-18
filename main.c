#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <limits.h>

#define POP_SIZE 100
#define CODE_LEN 100
#define MAX_GEN 100
#define MUTATION_RATE 20
#define STACK_SIZE 100
#define INPUT_SIZE 5
#define OUTPUT_SIZE 5

enum Instructions {
    PUSH, ADD, SUB, MUL, DIV,
    LOAD, STORE, JMP, JZ, JNZ,
    CMP_EQ, CMP_NE, CMP_GT, CMP_LT,
    WRITE, HALT, MAX_INST
};

typedef struct {
    unsigned char code[CODE_LEN];
    int fitness;
} Individual;

Individual population[POP_SIZE];
Individual best_individual;
int inputs[INPUT_SIZE] = {1, 2, 3, 4, 5};
int outputs[OUTPUT_SIZE];

// Function prototypes
void init_population();
void execute(Individual *ind);
void calculate_fitness(Individual *ind, int target);
void evolve_population(int target);
void mutate(Individual *ind);
int tournament_selection();
void crossover(Individual *parent1, Individual *parent2, Individual *child);

int main() {
    srand(time(NULL));
    int target = 15; // The target is the sum of the inputs

    init_population();
    for (int generation = 0; generation < MAX_GEN; generation++) {
        evolve_population(target);
        printf("Generation %d: Best Fitness = %d, Output = %d\n", generation, best_individual.fitness, outputs[0]);
        if (best_individual.fitness == 0) {
            printf("Solution found in generation %d\n", generation);
            break;
        }
    }

    printf("Best byte code sequence that achieved the target:\n");
    for (int i = 0; i < CODE_LEN && best_individual.code[i] != HALT; i++) {
        printf("%d ", best_individual.code[i]);
    }
    printf("\n");

    return 0;
}

void init_population() {
    for (int i = 0; i < POP_SIZE; i++) {
        for (int j = 0; j < CODE_LEN; j++) {
            if (j < CODE_LEN - 1) {
                population[i].code[j] = rand() % (MAX_INST - 1); // Exclude HALT from random initialization
            } else {
                population[i].code[j] = HALT; // Ensure HALT at the end for safety
            }
        }
        population[i].fitness = INT_MAX;
    }
}

void execute(Individual *ind) {
    int stack[STACK_SIZE], sp = 0;
    memset(stack, 0, sizeof(stack));
    memset(outputs, 0, sizeof(outputs));

    int pc = 0;
    while (pc < CODE_LEN && ind->code[pc] != HALT) {
        unsigned char inst = ind->code[pc++];
        int a, b, addr;
        switch (inst) {
            case PUSH:
                if (sp < STACK_SIZE) stack[sp++] = rand() % 10;
                break;
            case ADD:
                if (sp > 1) stack[sp-2] = stack[sp-2] + stack[sp-1], sp--;
                break;
            case SUB:
                if (sp > 1) stack[sp-2] = stack[sp-2] - stack[sp-1], sp--;
                break;
            case MUL:
                if (sp > 1) stack[sp-2] = stack[sp-2] * stack[sp-1], sp--;
                break;
            case DIV:
                if (sp > 1 && stack[sp-1] != 0) stack[sp-2] = stack[sp-2] / stack[sp-1], sp--;
                break;
            case LOAD:
                addr = ind->code[pc++] % INPUT_SIZE;
                if (sp < STACK_SIZE) stack[sp++] = inputs[addr];
                break;
            case STORE:
                addr = ind->code[pc++] % INPUT_SIZE;
                if (sp > 0) inputs[addr] = stack[--sp];
                break;
            case JMP:
                addr = ind->code[pc++];
                pc += addr;
                break;
            case JZ:
                if (sp > 0 && stack[--sp] == 0) pc += ind->code[pc++];
                else pc++;
                break;
            case JNZ:
                if (sp > 0 && stack[--sp] != 0) pc += ind->code[pc++];
                else pc++;
                break;
            case CMP_EQ:
                if (sp > 1) stack[sp-2] = (stack[sp-2] == stack[sp-1]), sp--;
                break;
            case CMP_NE:
                if (sp > 1) stack[sp-2] = (stack[sp-2] != stack[sp-1]), sp--;
                break;
            case CMP_GT:
                if (sp > 1) stack[sp-2] = (stack[sp-2] > stack[sp-1]), sp--;
                break;
            case CMP_LT:
                if (sp > 1) stack[sp-2] = (stack[sp-2] < stack[sp-1]), sp--;
                break;
            case WRITE:
                addr = ind->code[pc++] % OUTPUT_SIZE;
                if (sp > 0) outputs[addr] = stack[--sp];
                break;
            default:
                break;
        }
    }
}

void calculate_fitness(Individual *ind, int target) {
    execute(ind);
    ind->fitness = abs(outputs[0] - target);
}

void evolve_population(int target) {
    Individual new_population[POP_SIZE];
    for (int i = 0; i < POP_SIZE; i++) {
        int p1 = tournament_selection();
        int p2 = tournament_selection();
        crossover(&population[p1], &population[p2], &new_population[i]);
        mutate(&new_population[i]);
        calculate_fitness(&new_population[i], target);
    }
    memcpy(population, new_population, sizeof(new_population));

    for (int i = 0; i < POP_SIZE; i++) {
        if (population[i].fitness < best_individual.fitness) {
            best_individual = population[i];
        }
    }
}

void mutate(Individual *ind) {
    for (int i = 0; i < CODE_LEN; i++) {
        if (rand() % 100 < MUTATION_RATE) {
            ind->code[i] = rand() % MAX_INST;
        }
    }
}

int tournament_selection() {
    int best = rand() % POP_SIZE;
    for (int i = 1; i < 5; i++) {
        int other = rand() % POP_SIZE;
        if (population[other].fitness < population[best].fitness) {
            best = other;
        }
    }
    return best;
}

void crossover(Individual *parent1, Individual *parent2, Individual *child) {
    int crossover_point = rand() % CODE_LEN;
    for (int i = 0; i < crossover_point; i++) {
        child->code[i] = parent1->code[i];
    }
    for (int i = crossover_point; i < CODE_LEN; i++) {
        child->code[i] = parent2->code[i];
    }
}

