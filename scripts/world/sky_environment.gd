class_name SkyEnvironment
extends Node3D
## Небо (свой sky-шейдер: градиент, рассеяние у солнца, объёмные облака, звёзды, Млечный Путь, луна),
## солнце/луна, туман, тональная коррекция. set_time(часы) — день/ночь.

const SKY_CODE := """
shader_type sky;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec4 zenith_color : source_color = vec4(0.2, 0.4, 0.8, 1.0);
uniform vec4 horizon_color : source_color = vec4(0.7, 0.8, 0.9, 1.0);
uniform vec4 ground_color : source_color = vec4(0.2, 0.2, 0.22, 1.0);
uniform vec4 sun_color : source_color = vec4(1.0, 0.95, 0.85, 1.0);
uniform vec4 cloud_light : source_color = vec4(1.0, 1.0, 1.0, 1.0);
uniform vec4 cloud_dark : source_color = vec4(0.55, 0.6, 0.7, 1.0);
uniform float day = 1.0;
uniform float dusk = 0.0;
uniform float cloud_cover = 0.5;
uniform float cloud_offset = 0.0;
uniform float stars = 0.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float hash31(vec3 p) {
	p = fract(p * vec3(443.897, 441.423, 437.195));
	p += dot(p, p.yzx + 19.19);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, f.x), mix(c, d, f.x), f.y);
}

float fbm4(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		s += a * vnoise(p);
		p = p * 2.02 + vec2(11.7, 5.3);
		a *= 0.5;
	}
	return s;
}

float fbm3(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	for (int i = 0; i < 3; i++) {
		s += a * vnoise(p);
		p = p * 2.02 + vec2(11.7, 5.3);
		a *= 0.5;
	}
	return s;
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 sd3 = normalize(sun_dir);
	float h = dir.y;
	float up = clamp(h, 0.0, 1.0);

	vec3 col = mix(horizon_color.rgb, zenith_color.rgb, pow(up, 0.5));
	col = mix(col, ground_color.rgb, smoothstep(0.0, -0.12, h));

	float sd = max(dot(dir, sd3), 0.0);
	col += sun_color.rgb * (pow(sd, 6.0) * 0.16 + pow(sd, 80.0) * 0.45) * (0.35 + dusk * 1.1) * day;
	col += vec3(1.0, 0.42, 0.18) * dusk * pow(sd, 3.0) * pow(1.0 - up, 3.0) * 0.55;

	float disc = smoothstep(0.99955, 0.99985, sd);
	col += sun_color.rgb * disc * 7.0 * smoothstep(-0.06, 0.04, sd3.y);

	float cov = 0.0;
	if (h > 0.0) {
		vec2 uv = dir.xz / (h + 0.16) * 0.85 + vec2(cloud_offset, cloud_offset * 0.35);
		float d = fbm4(uv * 1.5);
		float dl = fbm3(uv * 1.5 + sd3.xz * 0.14);
		cov = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.26, d);
		cov *= smoothstep(0.0, 0.1, h);
		float shade = clamp(0.5 + (d - dl) * 5.5, 0.0, 1.0);
		vec3 cc = mix(cloud_dark.rgb, cloud_light.rgb, shade);
		cc += sun_color.rgb * pow(sd, 16.0) * 0.45 * day;
		col = mix(col, cc, cov * 0.93);
	}

	if (stars > 0.001 && h > -0.05) {
		vec3 sp = dir * 95.0;
		vec3 ip = floor(sp);
		vec3 fp = fract(sp) - 0.5;
		float r = hash31(ip);
		float st = step(0.962, r) * smoothstep(0.36, 0.0, length(fp));
		st *= 0.55 + 0.45 * fract(r * 91.7);
		float band = exp(-pow(dot(dir, normalize(vec3(0.3, 0.5, 0.8))) * 3.2, 2.0));
		float mw = band * fbm3(dir.xy * 6.0 + dir.z * 4.0) * 0.22;
		vec3 starcol = vec3(0.9, 0.95, 1.0) * st * 1.6 + vec3(0.35, 0.4, 0.62) * mw;
		col += starcol * stars * (1.0 - cov) * smoothstep(0.0, 0.08, h);
	}

	vec3 md3 = -sd3;
	float md = dot(dir, md3);
	float moon = smoothstep(0.99905, 0.99935, md) * smoothstep(-0.05, 0.05, md3.y);
	float crater = 0.82 + 0.18 * vnoise(dir.xy * 700.0 + dir.z * 300.0);
	col += vec3(0.86, 0.9, 1.0) * moon * crater * 1.3 * stars;
	col += vec3(0.4, 0.5, 0.8) * pow(max(md, 0.0), 300.0) * 0.4 * stars * (1.0 - cov);

	COLOR = col;
}
"""

var hours: float = 12.0
var fog_scale: float = 1.0
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var _cloud_off: float = 0.0
var _is_night: bool = false


func _ready() -> void:
    env = Environment.new()
    var sky := Sky.new()
    var shader := Shader.new()
    shader.code = SKY_CODE
    sky_mat = ShaderMaterial.new()
    sky_mat.shader = shader
    sky.sky_material = sky_mat
    sky.process_mode = Sky.PROCESS_MODE_INCREMENTAL
    sky.radiance_size = Sky.RADIANCE_SIZE_64
    env.background_mode = Environment.BG_SKY
    env.sky = sky
    env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
    env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
    env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
    env.tonemap_white = 6.0
    env.adjustment_enabled = true
    env.adjustment_contrast = 1.08
    env.adjustment_saturation = 1.18
    env.fog_enabled = true
    env.fog_density = 0.0007
    env.fog_sky_affect = 0.25
    var we := WorldEnvironment.new()
    we.environment = env
    add_child(we)
    sun = DirectionalLight3D.new()
    Game.configure_sun(sun)
    add_child(sun)
    set_time(hours)


func _process(delta: float) -> void:
    _cloud_off += delta * 0.004
    sky_mat.set_shader_parameter("cloud_offset", _cloud_off)


func is_night() -> bool:
    return _is_night


func _elevation(h: float) -> float:
    return sin((h - 6.0) / 12.0 * PI) * 70.0


func set_time(h: float) -> void:
    hours = h
    var elev: float = _elevation(h)
    _is_night = elev <= 3.0
    var day: float = clampf(elev / 20.0, 0.0, 1.0)
    var dusk: float = clampf(1.0 - absf(elev - 5.0) / 10.0, 0.0, 1.0)
    var night: float = clampf(1.0 - (elev + 8.0) / 18.0, 0.0, 1.0)
    var az: float = 40.0 if h < 12.0 else -40.0

    # направление НА солнце для неба (может быть под горизонтом)
    var sun_basis := Basis.from_euler(Vector3(deg_to_rad(-elev), deg_to_rad(az), 0.0))
    var to_sun: Vector3 = sun_basis.z

    if elev > 2.0:
        sun.rotation_degrees = Vector3(-elev, az, 0.0)
        sun.light_color = Color(1.0, 0.96, 0.88).lerp(Color(1.0, 0.62, 0.36), dusk)
        sun.light_energy = lerpf(0.25, 1.35, day)
    else:
        var moon_elev: float = clampf(-elev, 14.0, 60.0)
        sun.rotation_degrees = Vector3(-moon_elev, az + 180.0, 0.0)
        sun.light_color = Color(0.5, 0.6, 0.95)
        sun.light_energy = 0.2

    var top_day := Color(0.16, 0.38, 0.8)
    var top_night := Color(0.004, 0.008, 0.03)
    var hor_day := Color(0.62, 0.75, 0.9)
    var hor_night := Color(0.025, 0.035, 0.08)
    var top: Color = top_night.lerp(top_day, day).lerp(Color(0.22, 0.2, 0.42), dusk * 0.55)
    var hor: Color = hor_night.lerp(hor_day, day).lerp(Color(1.0, 0.5, 0.22), dusk * 0.7)
    var ground: Color = Color(0.02, 0.022, 0.03).lerp(Color(0.28, 0.3, 0.3), day).lerp(hor * 0.5, dusk * 0.5)

    sky_mat.set_shader_parameter("sun_dir", to_sun)
    sky_mat.set_shader_parameter("zenith_color", top)
    sky_mat.set_shader_parameter("horizon_color", hor)
    sky_mat.set_shader_parameter("ground_color", ground)
    sky_mat.set_shader_parameter("sun_color", Color(1.0, 0.95, 0.85).lerp(Color(1.0, 0.55, 0.28), dusk))
    sky_mat.set_shader_parameter("cloud_light", Color(0.04, 0.05, 0.09).lerp(Color(1.0, 1.0, 1.0), day).lerp(Color(1.0, 0.7, 0.5), dusk * 0.7))
    sky_mat.set_shader_parameter("cloud_dark", Color(0.015, 0.02, 0.04).lerp(Color(0.52, 0.58, 0.7), day).lerp(Color(0.5, 0.3, 0.35), dusk * 0.6))
    sky_mat.set_shader_parameter("day", day)
    sky_mat.set_shader_parameter("dusk", dusk)
    sky_mat.set_shader_parameter("cloud_cover", 0.52)
    sky_mat.set_shader_parameter("stars", night)

    env.fog_light_color = hor.lerp(Color(0.06, 0.07, 0.12), night * 0.3)
    env.fog_density = lerpf(0.0011, 0.0007, day) * fog_scale
    env.ambient_light_energy = lerpf(0.55, 1.05, day)
