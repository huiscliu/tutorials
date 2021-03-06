
/* asum: sum of all entries of a vector.
 * This code only calculates one block to show the usage of shared memory and synchronization */

#include <stdio.h>
#include <cuda.h>

/* cg */
#include <cooperative_groups.h>
#include <cooperative_groups/reduce.h>

using namespace cooperative_groups;
namespace cg = cooperative_groups;

typedef double FLOAT;

__global__ void SumReduceKnl(const FLOAT *x, FLOAT *y)
{
    __shared__ FLOAT sdata[256];

    /* cg */
    thread_block g = this_thread_block();
    thread_block_tile<32> tile = tiled_partition<32>(g);
    unsigned int tid = g.thread_rank();

    /* load data */
    FLOAT beta = x[tid];

    /* reduction */
    sdata[tid] = cg::reduce(tile, beta, cg::plus<FLOAT>());

    /* sync */
    g.sync();

    /* reduction partitial results using shared mem */
    if (tid == 0) {
        *y = sdata[0] + sdata[32] + sdata[64] + sdata[96] +
            sdata[128] + sdata[160] + sdata[192] + sdata[224];
    }
}

int main()
{
    int N = 256;   /* must be 256 */
    int nbytes = N * sizeof(FLOAT);

    FLOAT *dx = NULL, *hx = NULL;
    FLOAT *dy = NULL;
    int i;
    FLOAT as = 0;

    /* allocate GPU mem */
    cudaMalloc((void **)&dx, nbytes);
    cudaMalloc((void **)&dy, sizeof(FLOAT));

    if (dx == NULL || dy == NULL) {
        printf("couldn't allocate GPU memory\n");
        return -1;
    }

    printf("allocated %e MB on GPU\n", nbytes / (1024.f * 1024.f));

    /* alllocate CPU mem */
    hx = (FLOAT *) malloc(nbytes);

    if (hx == NULL) {
        printf("couldn't allocate CPU memory\n");
        return -2;
    }
    printf("allocated %e MB on CPU\n", nbytes / (1024.f * 1024.f));

    /* init */
    for (i = 0; i < N; i++) {
        hx[i] = 1;
    }

    /* copy data to GPU */
    cudaMemcpy(dx, hx, nbytes, cudaMemcpyHostToDevice);

    /* call GPU */
    SumReduceKnl<<<1, N>>>(dx, dy);

    /* let GPU finish */
    cudaDeviceSynchronize();

    /* copy data from GPU */
    cudaMemcpy(&as, dy, sizeof(FLOAT), cudaMemcpyDeviceToHost);

    printf("SumReduceKnl, answer: 256, calculated by GPU:%g\n", as);

    cudaFree(dx);
    cudaFree(dy);
    free(hx);

    return 0;
}
