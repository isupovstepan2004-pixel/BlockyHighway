extends CarModel
## SUV: высокий внедорожник-универсал с багажником на крыше, 4.9 м.

func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    make_body(b, paint, {
        "z0": -25, "z1": 24,
        "top": [[-25.0, 6.0], [-24.0, 8.0], [-14.0, 10.0], [-10.0, 11.0], [22.0, 11.0], [24.0, 10.0]],
        "wid": [[-25.0, 8.0], [-24.0, 9.0], [24.0, 9.0]],
        "arches": [-1.5, 1.4], "arch_y": 0.13, "arch_r": 0.5, "arch_x": 7, "sill": 2,
    })
    make_cabin(b, paint, {
        "z0": -10, "z1": 23,
        "cab": [[-10.0, 11.0], [-5.0, 19.0], [19.0, 19.0], [23.0, 12.0]],
        "hx": 8, "hxt": 7, "roof0": -4, "roof1": 18, "pf": -7, "pb": 17, "bp": [2, 9],
    })
    # решётка и фары
    box(b, -5, 3, -25, 5, 7, -25, "trim", DARK)
    for x in range(-4, 5, 2):
        box(b, x, 3, -25, x, 7, -25, "rim", STEEL)
    sym(b, 6, 7, -25, 8, 8, -25, "head", HEADC)
    sym(b, 6, 3, -25, 7, 4, -25, "head", HEADC)
    box(b, -8, 2, -26, 8, 4, -26, "rim", STEEL)
    # зад
    sym(b, 7, 6, 24, 8, 9, 24, "tail", TAILC)
    box(b, -8, 2, 25, 8, 4, 25, "rim", STEEL)
    box(b, -2, 5, 24, 2, 6, 24, "trim", DARK)
    # багажник на крыше
    sym(b, 5, 20, -3, 5, 20, 14, "trim", DARK)
    for z in [-3, 2, 7, 12, 14]:
        box(b, -5, 20, z, 5, 20, z, "trim", DARK)
    # двери
    for sx in [-9, 9]:
        for y in range(3, 10):
            for z in [-6, 3, 8]:
                b.put(sx, y, z, "trim", DARK)
        b.put(sx, 8, -2, "rim", STEEL)
        b.put(sx, 8, 5, "rim", STEEL)
    sym(b, 8, 12, -9, 9, 12, -9, "trim", DARK)
    # салон
    seat_row(b, -3, 12, 2, 6)
    seat_row(b, 6, 12, 2, 6)
    cockpit(b, -8, 12, 7, -4)
