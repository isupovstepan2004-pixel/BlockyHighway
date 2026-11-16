extends CarModel
## Taxi: классический американский седан с шашечками и плафоном на крыше, 5.0 м.

func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    make_body(b, paint, {
        "z0": -25, "z1": 24,
        "top": [[-25.0, 4.0], [-23.0, 6.0], [-12.0, 7.0], [-9.0, 8.0], [17.0, 8.0], [22.0, 8.0], [24.0, 6.0]],
        "wid": [[-25.0, 8.0], [-23.0, 9.0], [24.0, 9.0]],
        "arches": [-1.55, 1.45], "arch_y": 0.16, "arch_r": 0.43, "arch_x": 7, "sill": 1,
    })
    make_cabin(b, paint, {
        "z0": -10, "z1": 15,
        "cab": [[-10.0, 8.0], [-5.0, 14.0], [10.0, 14.0], [15.0, 9.0]],
        "hx": 8, "hxt": 7, "roof0": -4, "roof1": 10, "pf": -7, "pb": 11, "bp": [2],
    })
    # шашечки по бокам
    for sx in [-9, 9]:
        for z in range(-8, 10):
            if z % 2 == 0:
                b.put(sx, 3, z, "trim", DARK)
                b.put(sx, 4, z, "paint", WHITE)
            else:
                b.put(sx, 3, z, "paint", WHITE)
                b.put(sx, 4, z, "trim", DARK)
    # плафон
    box(b, -3, 15, 0, 3, 15, 5, "trim", DARK)
    box(b, -3, 16, 0, 3, 17, 5, "head", Color(1.0, 0.95, 0.7))
    box(b, -2, 17, 2, 2, 17, 3, "trim", DARK)
    # передок, зад
    sym(b, 5, 3, -25, 8, 4, -24, "head", HEADC)
    box(b, -4, 1, -25, 4, 3, -25, "trim", DARK)
    box(b, -9, 1, -26, 9, 2, -26, "rim", STEEL)
    sym(b, 5, 5, 23, 8, 6, 24, "tail", TAILC)
    box(b, -9, 1, 25, 9, 2, 25, "rim", STEEL)
    box(b, -2, 3, 24, 2, 4, 24, "trim", DARK)
    # двери
    for sx in [-9, 9]:
        for y in range(5, 8):
            for z in [-5, 3, 11]:
                b.put(sx, y, z, "trim", DARK)
        b.put(sx, 7, -1, "rim", STEEL)
        b.put(sx, 7, 7, "rim", STEEL)
    sym(b, 9, 9, -8, 10, 9, -8, "trim", DARK)
    # салон
    seat_row(b, -4, 9, 2, 6)
    seat_row(b, 5, 9, 2, 7)
    cockpit(b, -9, 9, 7, -4)
