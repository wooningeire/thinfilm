struct Uniforms {
    view_proj_mat: mat4x4f,
    view_mat: mat4x4f,
}

@group(0) @binding(0) var<uniform> uniforms: Uniforms;

struct VertOut {
    @builtin(position) pos_builtin: vec4f,
    @location(0) position: vec3f,
    @location(1) normal: vec3f,
    @location(2) uv: vec2f,
}

@vertex
fn vert(
    @location(0) pos: vec3f,
    @location(1) normal: vec3f,
) -> VertOut {
    var out: VertOut;

    let frustum_pos: vec4f = uniforms.view_proj_mat * vec4f(pos, 1);

    out.pos_builtin = frustum_pos;

    out.position = pos;
    out.normal = normal;
    out.uv = frustum_pos.xy / frustum_pos.w;

    return out;
}

@fragment
fn frag(
    in: VertOut,
) -> @location(0) vec4f {
    let normal = uniforms.view_mat * vec4f(in.normal, 0);

    return vec4f(vec3f(normal.z), 1);
}