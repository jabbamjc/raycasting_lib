
float* C_create_mat(int rows, int cols) {
    return malloc(rows * cols * sizeof(float*));
}

void c_free_mat(float* mat) {
    free(mat);
}

float* C_mat_mul(float* m1, int r1, int c1, float* m2, int r2, int c2) {
    float* output = malloc(r1 * c2 * sizeof(float));

    for (int i = 0; i < r1; i++) {
        for (int j = 0; j < c2; j++) {
            float total = 0;
            for (int k = 0; k < c1; k++) {
                total += *(m1 + i * c1 + k) * *(m2 + k * c2 + j);
            }
            *(output + i * c2 + j) = total;
        }
    }
    return output;
}
