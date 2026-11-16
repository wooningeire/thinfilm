<script lang="ts">
    import { onMount } from "svelte";
import { GpuRunner } from "./GpuRunner.svelte";

let canvas: HTMLCanvasElement;
let runner = $state<GpuRunner | null>();

let clientWidth = $state(0);
let clientHeight = $state(0);
let dpr = $state(1);

const width = $derived(Math.floor(clientWidth * dpr));
const height = $derived(Math.floor(clientHeight * dpr));

onMount(async () => {
    const runnerResult = await GpuRunner.create({canvas});
    if (runnerResult === null) return;

    runner = runnerResult;
    runner.draw();
});


const onResize = () => {
    dpr = devicePixelRatio;
};

onMount(onResize);
</script>

<svelte:window
    onresize={onResize}
/>

<main>
    <canvas
        bind:this={canvas}
        bind:clientWidth={null, newWidth => clientWidth = newWidth!}
        bind:clientHeight={null, newHeight => clientHeight = newHeight!}
        {width}
        {height}
    ></canvas>
</main>

<style lang="scss">
main {
    width: 100vw;
    height: 100vh;

    display: grid;
    place-items: center;
}

canvas {
    width: 50rem;
    height: 50rem;
}
</style>