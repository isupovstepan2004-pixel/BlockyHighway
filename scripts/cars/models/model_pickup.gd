extends CarModel
## Pickup: пикап с четырёхдверной кабиной и открытым кузовом, 5.2 м.

func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    make_body(b, paint, {
        "z0": -26, "z1": 25,
        "top": [[-26.0, 6.0], [-25.0, 8.0], [-14.0, 10.0], [-11.0, 11.0], [9.0, 11.0], [10.0, 9.0], [25.0, 9.0]],
        "wid": [[-26.0, 8.0], [-25.0, 9.0], [25.0, 9.0]],
        "arches": [-1.8, 1.7], "arch_y": 0.15, "arch_r": 0.5, "arch_x": 7, "sill": 2,
    })
    make_cabin(b, paint, {
        "z0": -11, "z1": 9,
        "cab": [[-11.0, 11.0], [-6.0, 19.0], [6.0, 19.0], [9.0, 17.0]],
        "hx": 8, "hxt": 7, "roof0": -5, "roof1": 5, "pf": -8, "pb": 7, "bp": [1],
    })
    # открытый кузов
    clear_box(b, -7, 7, 11, 7, 9, 24)
    box(b, -7, 6, 11, 7, 6, 24, "trim", DARK2)
    box(b, -7, 6, 10, 7, 9, 10, "paint", paint)
    sym(b, 8, 9, 11, 9, 9, 25, "trim", DARK)
    box(b, -8, 9, 25, 8, 9, 25, "trim", DARK)
    # передок
    box(b, -6, 3, -26, 6, 7, -26, "trim", DARK)
    for x in range(-5, 6, 2):
        box(b, x, 3, -26, x, 7, -26, "rim", STEEL)
    sym(b, 6, 7, -26, 8, 8, -26, "head", HEADC)
    box(b, -8, 2, -27, 8, 4, -27, "rim", STEEL)
    # зад
    sym(b, 7, 5, 25, 8, 7, 25, "tail", TAILC)
    box(b, -8, 2, 26, 8, 3, 26, "rim", STEEL)
    box(b, -1, 7, 25, 1, 7, 25, "rim", STEEL)
    # двери кабины
    for sx in [-9, 9]:
        for y in range(3, 11):
            for z in [-8, 0, 8]:
                b.put(sx, y, z, "trim", DARK)
        b.put(sx, 9, -4, "rim", STEEL)
        b.put(sx, 9, 4, "rim", STEEL)
    sym(b, 8, 12, -10, 9, 12, -10, "trim", DARK)
    # салон
    seat_row(b, -5, 12, 2, 6)
    seat_row(b, 2, 12, 2, 6)
    cockpit(b, -9, 12, 7, -4)
