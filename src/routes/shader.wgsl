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
    let ray_dir = normalize(in.position - uniforms.view_mat[3].xyz);
    let reflection_amt = abs(dot(ray_dir, in.normal));

    let thin_film_depth = 1e-15 + fbmNoise(in.position, 3) * 1e-16;
    const THIN_FILM_IOR: f32 = 1.5;
    // let phase_diff = 2 * THIN_FILM_DEPTH * THIN_FILM_IOR * reflection_amt;

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


    const LIGHT_POS = vec3f(1, 1, 1);
    let pos_to_light = LIGHT_POS - in.position;
    let dir_to_light = normalize(pos_to_light);
    let cos_to_light = dot(dir_to_light, in.normal);
    let diffuse = cos_to_light / dot(pos_to_light, pos_to_light);
    // return vec4f(vec3f(diffuse), 1);

    let reflection_normal = normalize(normalize(pos_to_light) - ray_dir);
    let reflection_cos_to_light = abs(dot(dir_to_light, reflection_normal));


    let internal_cos = cos(asin(sin(acos(reflection_cos_to_light) / THIN_FILM_IOR)));
    let phase_diff = 2 * thin_film_depth * THIN_FILM_IOR * internal_cos;

    const INTERFERENCE_AMPLITUDE_TERM: f32 = REFLECTED_AMT * REFLECTED_AMT + REFRACTED_AMT * REFRACTED_AMT;
    const INTERFERENCE_AMPLITUDE_COEFF: f32 = 2 * REFLECTED_AMT * REFRACTED_AMT;
    let light_power = vec3f(
        sqrt(INTERFERENCE_AMPLITUDE_TERM + INTERFERENCE_AMPLITUDE_COEFF * cos(RED_ANGULAR_VELOCITY * phase_diff)),
        sqrt(INTERFERENCE_AMPLITUDE_TERM + INTERFERENCE_AMPLITUDE_COEFF * cos(GREEN_ANGULAR_VELOCITY * phase_diff)),
        sqrt(INTERFERENCE_AMPLITUDE_TERM + INTERFERENCE_AMPLITUDE_COEFF * cos(BLUE_ANGULAR_VELOCITY * phase_diff)),
    ) * diffuse * vec3f(20, 15, 10);

    const SRGB_INV_GAMMA: f32 = 1 / 2.2;
    let light_color = pow(light_power, vec3f(SRGB_INV_GAMMA));

    let light_tonemapped = light_color / (1 + light_color);
    return vec4f(light_tonemapped, 1);
}

fn hash31(p: vec3f) -> f32 {
    var p3 = fract(p * 0.1031);
    p3 += dot(p3, p3.yzx + 33.33);
    return fract((p3.x + p3.y) * p3.z);
}

fn hash33(p: vec3f) -> vec3f {
    var p3 = fract(p * vec3f(0.1031, 0.1030, 0.0973));
    p3 += dot(p3, p3.yxz + 33.33);
    return fract((p3.xxy + p3.yxx) * p3.zyx);
}


fn gradientNoise(p: vec3f) -> f32 {
    let i = floor(p);
    let f = fract(p);
    let u = f * f * (3.0 - 2.0 * f);
    
    return mix(
        mix(
            mix(hash31(i + vec3f(0,0,0)), hash31(i + vec3f(1,0,0)), u.x),
            mix(hash31(i + vec3f(0,1,0)), hash31(i + vec3f(1,1,0)), u.x),
            u.y
        ),
        mix(
            mix(hash31(i + vec3f(0,0,1)), hash31(i + vec3f(1,0,1)), u.x),
            mix(hash31(i + vec3f(0,1,1)), hash31(i + vec3f(1,1,1)), u.x),
            u.y
        ),
        u.z
    ) * 2 - 1;
}

fn fbmNoise(p: vec3f, octaves: i32) -> f32 {
    var value = 0.0;
    var amplitude = 0.5;
    var frequency = 1.0;
    var pos = p;
    
    for (var i = 0; i < octaves; i++) {
        value += amplitude * gradientNoise(pos * frequency);
        frequency *= 2;
        amplitude *= 0.5;
    }
    return value;
}