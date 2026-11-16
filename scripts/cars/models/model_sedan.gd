extends CarModel
## Sedan: семейный седан, 4.8 м, трёхобъёмный кузов.

func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    make_body(b, paint, {
        "z0": -24, "z1": 23,
        "top": [[-24.0, 4.0], [-22.0, 5.5], [-10.0, 6.5], [-7.0, 7.5], [12.0, 7.5], [16.0, 8.0], [23.0, 6.5]],
        "wid": [[-24.0, 7.0], [-21.0, 8.0], [21.0, 8.0], [23.0, 7.0]],
        "arches": [-1.4, 1.4], "arch_y": 0.16, "arch_r": 0.42, "arch_x": 6, "sill": 1,
    })
    make_cabin(b, paint, {
        "z0": -9, "z1": 13,
        "cab": [[-9.0, 8.0], [-4.0, 14.0], [7.0, 14.0], [13.0, 8.0]],
        "hx": 7, "hxt": 6, "roof0": -3, "roof1": 6, "pf": -5, "pb": 9, "bp": [1],
    })
    # передок
    sym(b, 4, 3, -24, 7, 4, -23, "head", HEADC)
    box(b, -3, 1, -24, 3, 3, -24, "trim", DARK)
    box(b, -7, 1, -24, 7, 1, -23, "trim", DARK)
    # зад
    sym(b, 4, 5, 22, 7, 6, 23, "tail", TAILC)
    box(b, -2, 3, 23, 2, 4, 23, "trim", DARK)
    sym(b, 5, 1, 23, 6, 1, 23, "rim", STEEL)
    # двери
    for sx in [-8, 8]:
        for y in range(2, 7):
            for z in [-5, 2, 9]:
                b.put(sx, y, z, "trim", DARK)
        b.put(sx, 6, -1, "rim", STEEL)
        b.put(sx, 6, 6, "rim", STEEL)
    sym(b, 8, 9, -7, 9, 9, -7, "trim", DARK)
    # капот: линия и вентиляция
    for x in [-5, 5]:
        for z in range(-20, -10):
            b.put(x, top_at(z), z, "trim", DARK2)
    # салон
    seat_row(b, -3, 9, 2, 5)
    seat_row(b, 5, 9, 2, 6)
    cockpit(b, -8, 8, 6, -3)
