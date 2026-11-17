struct Uniforms {
    view_proj_mat: mat4x4f,
    view_inv_mat: mat4x4f,
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
    let ray_dir = normalize(in.position - uniforms.view_inv_mat[3].xyz);

    let normal_preturbation = 0.2 * fbmNoise(in.position * 20 + 100, 4);
    let normal = normalize(in.normal + normal_preturbation);
    let reflection_amt = abs(dot(ray_dir, normal));

    let thin_film_depth = 1e-6 + fbmNoise(in.position, 3) * 5e-8;
    const THIN_FILM_IOR: f32 = 1.5;
    // let phase_diff = 2 * THIN_FILM_DEPTH * THIN_FILM_IOR * reflection_amt;


    let reflectance = fresnel_schlick(normal, ray_dir, 1, THIN_FILM_IOR);
    let transmittance = 1 - reflectance;
    let interference_amplitude_term = reflectance * reflectance + transmittance * transmittance;
    let interference_amplitude_coeff = 2 * reflectance * transmittance;


    const RED_WAVELENGTH: f32 = 610e-9;
    const GREEN_WAVELENGTH: f32 = 550e-9;
    const BLUE_WAVELENGTH: f32 = 465e-9;

    const TWO_PI: f32 = 6.28318531;
    const RED_ANGULAR_VELOCITY: f32 = TWO_PI / RED_WAVELENGTH;
    const GREEN_ANGULAR_VELOCITY: f32 = TWO_PI / GREEN_WAVELENGTH;
    const BLUE_ANGULAR_VELOCITY: f32 = TWO_PI / BLUE_WAVELENGTH;


    const LIGHTS = array(
        Light(vec3f(1, 1, 1), vec3f(0.125, 0.125, 0.5)),
        Light(vec3f(0.5, -0.5, 0.5), vec3f(0.125, 0.5, 0.125)),
        Light(vec3f(-2, 0, -2), vec3f(0.125, 0.05, 0.25)),
    );

    var light_power = vec3f(0.3, 0.4, 0.5);
    for (var i = 0u; i < 3; i++) {
        let pos_to_light = LIGHTS[i].position - in.position;
        let dir_to_light = normalize(pos_to_light + normal_preturbation);
        let cos_to_light = max(0, dot(dir_to_light, normal));
        let diffuse = cos_to_light / dot(pos_to_light, pos_to_light);
        // return vec4f(vec3f(diffuse), 1);

        let reflection_normal = normalize(normalize(pos_to_light) - ray_dir);
        let reflection_cos_to_light = abs(dot(dir_to_light, reflection_normal));


        let internal_cos = sqrt(1 - (1 - reflection_cos_to_light * reflection_cos_to_light) / (THIN_FILM_IOR * THIN_FILM_IOR));
        let phase_diff = 2 * thin_film_depth * THIN_FILM_IOR * internal_cos;
        light_power += vec3f(
            // energy = amplitude^2
            interference_amplitude_term + interference_amplitude_coeff * -cos(RED_ANGULAR_VELOCITY * phase_diff),
            interference_amplitude_term + interference_amplitude_coeff * -cos(GREEN_ANGULAR_VELOCITY * phase_diff),
            interference_amplitude_term + interference_amplitude_coeff * -cos(BLUE_ANGULAR_VELOCITY * phase_diff),
        ) * diffuse * LIGHTS[i].color;
    }

    let light_tonemapped = light_power / (1 + light_power);

    const SRGB_INV_GAMMA: f32 = 1 / 2.2;
    let light_color = pow(light_tonemapped, vec3f(SRGB_INV_GAMMA));

    return vec4f(light_color, 1);
}

struct Light {
    position: vec3f,
    color: vec3f,
}

struct Wavelength {
    angular_velocity: vec3f,
    color: vec3f,
}

fn fresnel_schlick(normal: vec3f, dir: vec3f, ior_1: f32, ior_2: f32) -> f32 {
    let sqrt_r0 = (ior_1 - ior_2) / (ior_1 + ior_2);
    let r0 = sqrt_r0 * sqrt_r0;

    let one_cos = 1 - dot(normal, dir);
    let one_cos_2 = one_cos * one_cos;

    return r0 + (1 - r0) * one_cos_2 * one_cos_2 * one_cos;
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