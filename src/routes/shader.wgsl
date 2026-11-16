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
    let reflection_amt = abs(dot(normalize(in.position - uniforms.view_mat[3].xyz), in.normal));

    const THIN_FILM_DEPTH: f32 = 1e-15;
    const THIN_FILM_IOR: f32 = 1.5;
    let phase_diff = 2 * THIN_FILM_DEPTH * THIN_FILM_IOR * reflection_amt;

    const REFLECTED_AMT: f32 = 0.5;
    const REFRACTED_AMT: f32 = 1 - REFLECTED_AMT;

    const RED_WAVELENGTH: f32 = 610e-9;
    const GREEN_WAVELENGTH: f32 = 550e-9;
    const BLUE_WAVELENGTH: f32 = 465e-9;


    const SPEED_OF_LIGHT: f32 = 299792458;
    const RED_FREQ: f32 = SPEED_OF_LIGHT / RED_WAVELENGTH;
    const GREEN_FREQ: f32 = SPEED_OF_LIGHT / GREEN_WAVELENGTH;
    const BLUE_FREQ: f32 = SPEED_OF_LIGHT / BLUE_WAVELENGTH;

    const TWO_PI: f32 = 6.28318531;
    const RED_ANGULAR_VELOCITY: f32 = RED_FREQ * TWO_PI;
    const GREEN_ANGULAR_VELOCITY: f32 = GREEN_FREQ * TWO_PI;
    const BLUE_ANGULAR_VELOCITY: f32 = BLUE_FREQ * TWO_PI;




    const INTERFERENCE_AMPLITUDE_TERM: f32 = REFLECTED_AMT * REFLECTED_AMT + REFRACTED_AMT * REFRACTED_AMT;
    const INTERFERENCE_AMPLITUDE_COEFF: f32 = 2 * REFLECTED_AMT * REFRACTED_AMT;
    let light_power = vec3f(
        sqrt(INTERFERENCE_AMPLITUDE_TERM + INTERFERENCE_AMPLITUDE_COEFF * cos(RED_ANGULAR_VELOCITY * phase_diff)),
        sqrt(INTERFERENCE_AMPLITUDE_TERM + INTERFERENCE_AMPLITUDE_COEFF * cos(GREEN_ANGULAR_VELOCITY * phase_diff)),
        sqrt(INTERFERENCE_AMPLITUDE_TERM + INTERFERENCE_AMPLITUDE_COEFF * cos(BLUE_ANGULAR_VELOCITY * phase_diff)),
    );

    const SRGB_INV_GAMMA: f32 = 1 / 2.2;
    let light_color = pow(light_power, vec3f(SRGB_INV_GAMMA));

    // let light_tonemapped = light_color / (1 + light_color);
    return vec4f(light_color * vec3f(0.4, 0.5, 0.2) + vec3f(0.6, 0.5, 0.8), 1);
}