extends CarModel
## Police: патрульный седан, бело-чёрная раскраска, мигалка, push-bar, 5.0 м.

func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    make_body(b, paint, {
        "z0": -25, "z1": 24,
        "top": [[-25.0, 4.0], [-23.0, 6.0], [-10.0, 7.0], [-7.0, 8.0], [16.0, 8.0], [22.0, 8.0], [24.0, 7.0]],
        "wid": [[-25.0, 8.0], [-23.0, 9.0], [24.0, 9.0]],
        "arches": [-1.55, 1.45], "arch_y": 0.17, "arch_r": 0.44, "arch_x": 7, "sill": 1,
    })
    make_cabin(b, paint, {
        "z0": -9, "z1": 15,
        "cab": [[-9.0, 8.0], [-3.0, 13.0], [8.0, 13.0], [15.0, 8.0]],
        "hx": 7, "hxt": 6, "roof0": -2, "roof1": 7, "pf": -5, "pb": 10, "bp": [2],
    })
    # белые двери
    for z in range(-4, 10):
        for y in range(1, top_at(z)):
            b.put(9, y, z, "paint", WHITE)
            b.put(-9, y, z, "paint", WHITE)
    for sx in [-9, 9]:
        for y in range(2, 7):
            for z in [-5, 3]:
                b.put(sx, y, z, "trim", DARK)
        b.put(sx, 6, -1, "rim", STEEL)
        b.put(sx, 6, 6, "rim", STEEL)
        for z in range(-3, 3):
            b.put(sx, 3, z, "paint", BLUEC.darkened(0.4))
    # мигалка
    box(b, -6, 14, -1, 6, 14, 4, "trim", DARK)
    box(b, -5, 15, 0, -1, 15, 3, "tail", TAILC)
    box(b, 1, 15, 0, 5, 15, 3, "blue", BLUEC)
    box(b, 0, 15, 0, 0, 15, 3, "trim", DARK)
    # передок: фары, push-bar
    sym(b, 5, 3, -25, 7, 4, -24, "head", HEADC)
    box(b, -4, 1, -25, 4, 3, -25, "trim", DARK)
    box(b, -6, 2, -27, 6, 4, -27, "trim", DARK)
    sym(b, 6, 2, -26, 6, 4, -26, "trim", DARK)
    sym(b, 3, 3, -28, 5, 3, -27, "blue", BLUEC)
    # зад
    sym(b, 4, 5, 22, 8, 6, 23, "tail", TAILC)
    box(b, -9, 1, 24, 9, 2, 24, "trim", DARK)
    sym(b, 7, 7, 24, 8, 7, 24, "blue", BLUEC)
    # прожектор у левой стойки
    b.put(-8, 9, -6, "rim", STEEL)
    sym(b, 8, 9, -8, 9, 9, -8, "trim", DARK)
    # салон: решётка между рядами
    seat_row(b, -3, 9, 2, 5)
    seat_row(b, 6, 9, 2, 6)
    box(b, -6, 9, 4, 6, 12, 4, "trim", DARK2)
    cockpit(b, -8, 8, 6, -3)
