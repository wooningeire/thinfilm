<script lang="ts">
import { onMount } from "svelte";
import { Draggable } from "@vaie/hui";
import { GpuRunner } from "./GpuRunner.svelte";
import { CameraOrbit } from "./CameraOrbit.svelte";
import { Camera } from "./Camera.svelte";

let canvas: HTMLCanvasElement;
let runner = $state<GpuRunner | null>();

let clientWidth = $state(0);
let clientHeight = $state(0);
let dpr = $state(1);

const width = $derived(Math.floor(clientWidth * dpr));
const height = $derived(Math.floor(clientHeight * dpr));

const orbit = new CameraOrbit();
const camera = new Camera({
    controlScheme: orbit,
    screenDims: {
        width: () => width,
        height: () => height,
    }
});

onMount(async () => {
    const runnerResult = await GpuRunner.create({canvas});
    if (runnerResult === null) return;

    runner = runnerResult;
});

$effect(() => {
    runner?.draw({
        camera,
    });
})


const onResize = () => {
    dpr = devicePixelRatio;
};

onMount(onResize);
</script>

<svelte:window
    onresize={onResize}
/>

<main>
    <Draggable
        onDown={({ pointerEvent }) => {
            canvas?.requestPointerLock();
        }}

        onDrag={async ({ movement, button, pointerEvent }) => {
            switch (button) {
                case 0:
                    orbit.turn(movement);
                    break;

                case 1:
                    orbit.pan(movement);
                    break;
            }

            pointerEvent.preventDefault();
        }}

        onUp={({ pointerEvent }) => {
            document.exitPointerLock();
        }}
    >
        {#snippet dragTarget({ onpointerdown })}
            <canvas
                bind:this={canvas}
                
                bind:clientWidth={null, newWidth => clientWidth = newWidth!}
                bind:clientHeight={null, newHeight => clientHeight = newHeight!}
                {width}
                {height}

                {onpointerdown}
                onwheel={event => {
                    orbit.radius *= 2 ** (event.deltaY * 0.001);
                }}
            ></canvas>
        {/snippet}
    </Draggable>
</main>

<style lang="scss">
main {
    width: 100vw;
    height: 100vh;

    display: grid;
    place-items: center;

    background: oklch(0.96 0.01 190);
}

canvas {
    width: 50rem;
    height: 50rem;

    background: oklch(1 0 0);
}
</style>