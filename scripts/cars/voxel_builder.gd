class_name VoxelBuilder
extends RefCounted
## Хранит воксели по слоям (материалам) и строит один ArrayMesh
## только из видимых граней (face culling). Слой "glass" прозрачный.

const LAYER_ORDER: Array = ["paint", "trim", "head", "tail", "blue", "glass", "tire", "rim"]

# [нормаль, смещение угла, ось u, ось v], u x v = нормаль
const FACES: Array = [
    [Vector3i(1, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1)],
    [Vector3i(-1, 0, 0), Vector3i(0, 0, 0), Vector3i(0, 0, 1), Vector3i(0, 1, 0)],
    [Vector3i(0, 1, 0), Vector3i(0, 1, 0), Vector3i(0, 0, 1), Vector3i(1, 0, 0)],
    [Vector3i(0, -1, 0), Vector3i(0, 0, 0), Vector3i(1, 0, 0), Vector3i(0, 0, 1)],
    [Vector3i(0, 0, 1), Vector3i(0, 0, 1), Vector3i(1, 0, 0), Vector3i(0, 1, 0)],
    [Vector3i(0, 0, -1), Vector3i(0, 0, 0), Vector3i(0, 1, 0), Vector3i(1, 0, 0)],
]

var size: float = 0.1
var origin: Vector3 = Vector3.ZERO
var cells: Dictionary = {}    # Vector3i -> String (слой)
var colors: Dictionary = {}   # Vector3i -> Color
var materials: Dictionary = {}


func put(x: int, y: int, z: int, layer: String, color: Color) -> void:
    var p := Vector3i(x, y, z)
    cells[p] = layer
    colors[p] = color


func fill(a: Vector3i, b: Vector3i, layer: String, color: Color) -> void:
    for x in range(mini(a.x, b.x), maxi(a.x, b.x) + 1):
        for y in range(mini(a.y, b.y), maxi(a.y, b.y) + 1):
            for z in range(mini(a.z, b.z), maxi(a.z, b.z) + 1):
                put(x, y, z, layer, color)


func erase(x: int, y: int, z: int) -> void:
    var p := Vector3i(x, y, z)
    cells.erase(p)
    colors.erase(p)


func has_voxel(x: int, y: int, z: int) -> bool:
    return cells.has(Vector3i(x, y, z))


func build() -> ArrayMesh:
    return build_cells(cells.keys())


## Строит меш только из переданных клеток (для чанков и обломков).
## Скрытие граней учитывает ВСЕ клетки билдера.
func build_cells(list: Array) -> ArrayMesh:
    var mesh := ArrayMesh.new()
    var by_layer: Dictionary = {}
    for p in list:
        var layer: String = cells[p]
        if not by_layer.has(layer):
            by_layer[layer] = []
        (by_layer[layer] as Array).append(p)
    for layer_name in LAYER_ORDER:
        var lname: String = layer_name
        if not by_layer.has(lname):
            continue
        var st := SurfaceTool.new()
        st.begin(Mesh.PRIMITIVE_TRIANGLES)
        for p in by_layer[lname]:
            _emit(st, p, lname)
        if materials.has(lname):
            st.set_material(materials[lname])
        st.commit(mesh)
    return mesh


func _emit(st: SurfaceTool, p: Vector3i, layer: String) -> void:
    var base_col: Color = colors[p]
    var h: int = (p.x * 73856093) ^ (p.y * 19349663) ^ (p.z * 83492791)
    var k: float = float(h & 255) / 255.0 - 0.5
    var f: float = 1.0 + k * 0.10
    var col := Color(clampf(base_col.r * f, 0.0, 1.0), clampf(base_col.g * f, 0.0, 1.0), clampf(base_col.b * f, 0.0, 1.0), base_col.a)
    for face in FACES:
        var n: Vector3i = face[0]
        var q: Vector3i = p + n
        if cells.has(q):
            var ql: String = cells[q]
            if layer == "glass" or ql != "glass":
                continue
        var off: Vector3i = face[1]
        var ua: Vector3i = face[2]
        var va: Vector3i = face[3]
        var o: Vector3 = Vector3(p + off) * size + origin
        var u: Vector3 = Vector3(ua) * size
        var v: Vector3 = Vector3(va) * size
        var nn := Vector3(n)
        _vert(st, o, nn, col)
        _vert(st, o + v, nn, col)
        _vert(st, o + u + v, nn, col)
        _vert(st, o, nn, col)
        _vert(st, o + u + v, nn, col)
        _vert(st, o + u, nn, col)


func _vert(st: SurfaceTool, pos: Vector3, n: Vector3, col: Color) -> void:
    st.set_color(col)
    st.set_normal(n)
    st.add_vertex(pos)
