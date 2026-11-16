class_name WorldKit
extends RefCounted
## Общие помощники для карт: материалы, текстуры, деревья, шейдер окон, кольцо гор.

const BUILDING_SHADER := """
shader_type spatial;
uniform float night = 0.0;
varying vec3 wp;
varying vec3 wn;
varying vec4 icol;

float h21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	icol = COLOR;
}

void fragment() {
	vec3 base = icol.rgb;
	float vert = step(abs(wn.y), 0.5);
	float u = abs(wn.x) > 0.5 ? wp.z : wp.x;
	vec2 g = vec2(u / 3.0, wp.y / 3.6);
	vec2 cell = floor(g);
	vec2 f = fract(g);
	float win = step(0.16, f.x) * step(f.x, 0.84) * step(0.22, f.y) * step(f.y, 0.82) * vert * step(1.4, wp.y);
	float seed = icol.a * 91.7;
	float lit = step(0.5, h21(cell + seed));
	vec3 glass = mix(vec3(0.16, 0.24, 0.32), vec3(0.42, 0.52, 0.62), h21(cell + seed * 1.7));
	float roof = step(0.5, wn.y);
	ALBEDO = mix(base, glass, win) * mix(1.0, 0.7, roof);
	ROUGHNESS = mix(0.85, 0.12, win);
	METALLIC = win * 0.4;
	EMISSION = win * lit * night * vec3(1.0, 0.82, 0.5) * 1.7;
}
"""


static func flat_mat(c: Color, rough: float = 0.9) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.albedo_color = c
    m.roughness = rough
    return m


static func vc_mat(rough: float = 1.0) -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.vertex_color_is_srgb = true
    m.roughness = rough
    return m


static func unshaded_vc_mat() -> StandardMaterial3D:
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
    return m


static func building_material() -> ShaderMaterial:
    var sh := Shader.new()
    sh.code = BUILDING_SHADER
    var m := ShaderMaterial.new()
    m.shader = sh
    return m


static func noise_tex(n: int, base: Color, var_amt: float, seed_v: int, speck: float) -> ImageTexture:
    var img := Image.create(n, n, false, Image.FORMAT_RGB8)
    var rng := RandomNumberGenerator.new()
    rng.seed = seed_v
    for y in n:
        for x in n:
            var k: float = 1.0 + (rng.randf() - 0.5) * var_amt
            var c := Color(base.r * k, base.g * k, base.b * k)
            if rng.randf() < speck:
                c = c.lightened(0.25)
            img.set_pixel(x, y, c)
    img.generate_mipmaps()
    return ImageTexture.create_from_image(img)


## Воксельное дерево. vs — размер вокселя (больше = грубее и легче). pine — ель.
static func tree_mesh(pine: bool, rng: RandomNumberGenerator, vs: float = 0.3) -> ArrayMesh:
    return tree_builder(pine, rng, vs).build()


## Билдер дерева (физический размер не зависит от vs, пока vs >= 0.3).
static func tree_builder(pine: bool, rng: RandomNumberGenerator, vs: float = 0.3, mat_override: Dictionary = {}) -> VoxelBuilder:
    var k: float = 0.3 / vs
    var b := VoxelBuilder.new()
    b.size = vs
    var mat: StandardMaterial3D = vc_mat()
    b.materials = mat_override if not mat_override.is_empty() else {"paint": mat, "trim": mat}
    var trunk := Color(0.32, 0.2, 0.1)
    var h: int = maxi(2, int((9.0 if pine else 7.0) * k))
    var tw: int = 2 if k >= 0.9 else 1
    for y in h:
        for tx in range(-tw, 1):
            b.put(tx, y, 0, "trim", trunk)
    var rr: int = maxi(2, int(6.0 * k))
    var hh: int = maxi(4, int(16.0 * k))
    for x in range(-rr, rr + 1):
        for y in range(0, hh):
            for z in range(-rr, rr + 1):
                var inside: bool = false
                var col := Color(0.16, 0.42, 0.14).lerp(Color(0.3, 0.55, 0.16), rng.randf())
                if pine:
                    var layer_r: float = float(rr) * (1.0 - float(y) / float(hh))
                    inside = y >= int(3.0 * k) and sqrt(float(x * x + z * z)) <= layer_r
                    col = Color(0.08, 0.3, 0.14).lerp(Color(0.14, 0.42, 0.2), rng.randf())
                else:
                    var dy: float = float(y) - 10.0 * k
                    inside = y >= int(6.0 * k) and float(x * x + z * z) / float(rr * rr) + dy * dy / (20.0 * k * k) <= 1.0 and rng.randf() > 0.06
                if inside:
                    b.put(x, y, z, "paint", col)
    return b


static func scatter_multimesh(parent: Node3D, mesh: Mesh, xforms: Array, mat: Material, shadows: bool = false) -> MultiMeshInstance3D:
    var mm := MultiMesh.new()
    mm.transform_format = MultiMesh.TRANSFORM_3D
    mm.mesh = mesh
    mm.instance_count = xforms.size()
    for i in xforms.size():
        mm.set_instance_transform(i, xforms[i])
    var mmi := MultiMeshInstance3D.new()
    mmi.multimesh = mm
    mmi.material_override = mat
    if not shadows:
        mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mmi)
    return mmi


## Кольцо далёких гор вокруг карты.
static func mountain_ring(parent: Node3D, rng: RandomNumberGenerator, radius: float, height: float, low: Color, high: Color, seed_v: float, center: Vector3 = Vector3.ZERO) -> void:
    var seg: int = 128
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var tops: Array = []
    for i in seg + 1:
        var a: float = float(i) / float(seg) * TAU
        var k: float = 0.55 + 0.25 * sin(a * 3.0 + seed_v) + 0.15 * sin(a * 7.0 + seed_v * 2.0) + 0.08 * sin(a * 17.0 + seed_v * 5.0)
        if i == seg:
            k = float(tops[0])
        else:
            k = clampf(k + (rng.randf() - 0.5) * 0.12, 0.15, 1.1)
        tops.append(k)
    for i in seg:
        var a0: float = float(i) / float(seg) * TAU
        var a1: float = float(i + 1) / float(seg) * TAU
        var h0: float = height * float(tops[i])
        var h1: float = height * float(tops[i + 1])
        var p0 := Vector3(cos(a0) * radius, -10.0, sin(a0) * radius)
        var p1 := Vector3(cos(a1) * radius, -10.0, sin(a1) * radius)
        var t0 := Vector3(cos(a0) * radius * 0.93, h0, sin(a0) * radius * 0.93)
        var t1 := Vector3(cos(a1) * radius * 0.93, h1, sin(a1) * radius * 0.93)
        var nrm: Vector3 = Vector3(-cos((a0 + a1) * 0.5), 0.5, -sin((a0 + a1) * 0.5)).normalized()
        var verts: Array = [p0, t0, t1, p0, t1, p1]
        var top_c: Color = high.lerp(low, 0.25)
        var cols: Array = [low, top_c, top_c, low, top_c, low]
        for j in 6:
            st.set_normal(nrm)
            st.set_color(cols[j])
            st.add_vertex(verts[j])
    var mi := MeshInstance3D.new()
    mi.mesh = st.commit()
    var m := StandardMaterial3D.new()
    m.vertex_color_use_as_albedo = true
    m.roughness = 1.0
    m.cull_mode = BaseMaterial3D.CULL_DISABLED
    m.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX
    mi.material_override = m
    mi.position = center
    mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
    parent.add_child(mi)


static var _roof: ArrayMesh


## Единичная двускатная крыша (конёк вдоль X, основание y=0, высота 1).
static func roof_mesh() -> ArrayMesh:
    if _roof != null:
        return _roof
    var st := SurfaceTool.new()
    st.begin(Mesh.PRIMITIVE_TRIANGLES)
    var a := Vector3(-0.5, 0.0, -0.5)
    var b := Vector3(0.5, 0.0, -0.5)
    var c := Vector3(0.5, 0.0, 0.5)
    var d := Vector3(-0.5, 0.0, 0.5)
    var r0 := Vector3(-0.5, 1.0, 0.0)
    var r1 := Vector3(0.5, 1.0, 0.0)
    for tri in [[a, b, r1], [a, r1, r0], [d, r0, r1], [d, r1, c], [a, r0, d], [b, c, r1]]:
        for v in tri:
            st.add_vertex(v)
    st.generate_normals()
    _roof = st.commit()
    return _roof


## Дешёвая «заглушка» дома (коробка + крыша + коллизия) для разрушаемого мира.
static func house_proxy(parent: Node3D, w: float, d: float, wall_h: float, wall_col: Color, roof_col: Color) -> void:
    var wm := MeshInstance3D.new()
    var bm := BoxMesh.new()
    bm.size = Vector3(w, wall_h, d)
    wm.mesh = bm
    wm.material_override = flat_mat(wall_col, 0.9)
    wm.position = Vector3(0.0, wall_h * 0.5, 0.0)
    parent.add_child(wm)
    var rm := MeshInstance3D.new()
    rm.mesh = roof_mesh()
    var rmat: StandardMaterial3D = flat_mat(roof_col, 0.9)
    rmat.cull_mode = BaseMaterial3D.CULL_DISABLED
    rm.material_override = rmat
    rm.transform = Transform3D(Basis.from_scale(Vector3(w + 0.6, 3.6, d + 0.6)), Vector3(0.0, wall_h, 0.0))
    parent.add_child(rm)
    var body := StaticBody3D.new()
    var cs := CollisionShape3D.new()
    var sh := BoxShape3D.new()
    sh.size = Vector3(w, wall_h + 3.0, d)
    cs.shape = sh
    cs.position = Vector3(0.0, (wall_h + 3.0) * 0.5, 0.0)
    body.add_child(cs)
    parent.add_child(body)
