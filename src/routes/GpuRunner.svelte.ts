import type { Camera } from "./Camera.svelte";
import {load} from "@loaders.gl/core";
import { GLTFLoader, postProcessGLTF } from "@loaders.gl/gltf";
import shaderCode from "./shader.wgsl?raw";
import rockGlb from "#lib/assets/rock.glb?url";
import { mat4 } from "wgpu-matrix";

export class GpuRunner {
    private readonly device: GPUDevice;
    private readonly context: GPUCanvasContext;

    private readonly bindGroup: GPUBindGroup;
    private readonly verts: GPUBuffer;
    private readonly normals: GPUBuffer;
    private readonly uniforms: GPUBuffer;
    private readonly renderPipeline: GPURenderPipeline;
    private readonly depthTextureView: GPUTextureView;

    private constructor({
        device,
        context,

        bindGroup,
        verts,
        normals,
        uniforms,
        renderPipeline,
        depthTextureView,
    }: {
        device: GPUDevice,
        context: GPUCanvasContext,

        bindGroup: GPUBindGroup,
        verts: GPUBuffer,
        normals: GPUBuffer,
        uniforms: GPUBuffer,
        renderPipeline: GPURenderPipeline,
        depthTextureView: GPUTextureView,
    }) {
        this.device = device;
        this.context = context;

        this.bindGroup = bindGroup;
        this.verts = verts;
        this.normals = normals;
        this.uniforms = uniforms;
        this.renderPipeline = renderPipeline;
        this.depthTextureView = depthTextureView;
    }

    static async create({
        canvas,
    }: {
        canvas: HTMLCanvasElement,
    }) {
        const adapter = await navigator.gpu.requestAdapter();
        if (adapter === null) return null;


        const context = canvas.getContext("webgpu");
        if (context === null) return null;

        const device = await adapter.requestDevice({});
        const format = navigator.gpu.getPreferredCanvasFormat();
        context.configure({
            device,
            format,
            alphaMode: "premultiplied",
        });


        const bindGroupLayout = device.createBindGroupLayout({
            label: "bind group layout",
            entries: [
                {
                    binding: 0,
                    visibility: GPUShaderStage.VERTEX | GPUShaderStage.FRAGMENT,
                    buffer: {
                        type: "uniform",
                    },
                },
            ],
        });

        const gltfResult = await load(rockGlb, GLTFLoader);
        const gltf = postProcessGLTF(gltfResult);
        // console.log(gltf.meshes[0].primitives[0].attributes.POSITION);

        const primitive = gltf.meshes[0].primitives[0];
        const posBuffer = new Float32Array(primitive.indices!.value.length * 3);
        const norBuffer = new Float32Array(primitive.indices!.value.length * 3);
        for (let i = 0; i < primitive.indices!.value.length; i++) {
            const index = primitive.indices!.value[i];

            posBuffer[i * 3] = primitive.attributes.POSITION.value[index * 3];
            posBuffer[i * 3 + 1] = primitive.attributes.POSITION.value[index * 3 + 1];
            posBuffer[i * 3 + 2] = primitive.attributes.POSITION.value[index * 3 + 2];

            norBuffer[i * 3] = primitive.attributes.NORMAL.value[index * 3];
            norBuffer[i * 3 + 1] = primitive.attributes.NORMAL.value[index * 3 + 1];
            norBuffer[i * 3 + 2] = primitive.attributes.NORMAL.value[index * 3 + 2];
        }

        const verts = device.createBuffer({
            label: "verts buffer",
            size: posBuffer.byteLength,
            usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
        });
        device.queue.writeBuffer(verts, 0, posBuffer);

        const normals = device.createBuffer({
            label: "normals buffer",
            size: norBuffer.byteLength,
            usage: GPUBufferUsage.VERTEX | GPUBufferUsage.COPY_DST,
        });
        device.queue.writeBuffer(normals, 0, norBuffer);
        

        const uniforms = device.createBuffer({
            label: "uniforms buffer",
            size: 64 + 64,
            usage: GPUBufferUsage.UNIFORM | GPUBufferUsage.COPY_DST,
        });

        const bindGroup = device.createBindGroup({
            label: "bind group",
            layout: bindGroupLayout,
            entries: [
                {
                    binding: 0,
                    resource: uniforms,
                },
            ],
        });


        const module = device.createShaderModule({
            label: "vertex module",
            code: shaderCode,
        });

        const renderPipelineLayout = device.createPipelineLayout({
            label: "render pipeline layout",
            bindGroupLayouts: [bindGroupLayout],
        });

        const renderPipeline = device.createRenderPipeline({
            label: "render pipeline",
            layout: renderPipelineLayout,
            vertex: {
                module,
                entryPoint: "vert",
                buffers: [
                    {
                        attributes: [
                            {
                                shaderLocation: 0,
                                offset: 0,
                                format: "float32x3",
                            },
                        ],
                        arrayStride: 12,
                        stepMode: "vertex",
                    },

                    {
                        attributes: [
                            {
                                shaderLocation: 1,
                                offset: 0,
                                format: "float32x3",
                            },
                        ],
                        arrayStride: 12,
                        stepMode: "vertex",
                    },
                ],
            },
            
            fragment: {
                module,
                entryPoint: "frag",
                targets: [
                    {
                        format,
                    },
                ],
            },

            primitive: {
                topology: "triangle-list",
            },

            depthStencil: {
                depthWriteEnabled: true,
                depthCompare: "less",
                format: "depth32float",
            },
        });

        return new GpuRunner({
            device,
            context,

            bindGroup,
            verts,
            normals,
            uniforms,
            renderPipeline,
            depthTextureView: device.createTexture({
                size: [canvas.width, canvas.height],
                format: "depth32float",
                usage: GPUTextureUsage.RENDER_ATTACHMENT | GPUTextureUsage.TEXTURE_BINDING,
            }).createView(),
        });
    }

    draw({
        camera,
    }: {
        camera: Camera,
    }) {
        const commandEncoder = this.device.createCommandEncoder({
            label: "command encoder",
        });

        const view = this.context.getCurrentTexture().createView({
            label: "view",
        });

        this.device.queue.writeBuffer(this.uniforms, 0, camera.viewProjMat);
        this.device.queue.writeBuffer(this.uniforms, 64, camera.viewMat);

        const renderPassEncoder = commandEncoder.beginRenderPass({
            label: "render pass",
            colorAttachments: [
                {
                    clearValue: {r: 0, g: 0, b: 0, a: 0},
                    loadOp: "clear",
                    storeOp: "store",
                    view,
                }
            ],
            depthStencilAttachment: {
                depthClearValue: 1,
                depthLoadOp: "clear",
                depthStoreOp: "store",
                view: this.depthTextureView,
            },
        });
        renderPassEncoder.setBindGroup(0, this.bindGroup);
        renderPassEncoder.setVertexBuffer(0, this.verts);
        renderPassEncoder.setVertexBuffer(1, this.normals);
        renderPassEncoder.setPipeline(this.renderPipeline);
        renderPassEncoder.draw(this.verts.size / 12);
        renderPassEncoder.end();

        this.device.queue.submit([commandEncoder.finish()]);
    }
}