extends CarModel
## Hatchback: компактный городской хэтчбек, 4.0 м, скошенная задняя дверь.

func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    make_body(b, paint, {
        "z0": -20, "z1": 19,
        "top": [[-20.0, 4.0], [-18.0, 6.0], [-8.0, 7.0], [-5.0, 8.0], [14.0, 8.0], [19.0, 7.0]],
        "wid": [[-20.0, 6.0], [-17.0, 8.0], [19.0, 8.0]],
        "arches": [-1.25, 1.15], "arch_y": 0.15, "arch_r": 0.4, "arch_x": 6, "sill": 1,
    })
    make_cabin(b, paint, {
        "z0": -8, "z1": 19,
        "cab": [[-8.0, 8.0], [-3.0, 13.0], [11.0, 13.0], [19.0, 9.0]],
        "hx": 7, "hxt": 6, "roof0": -2, "roof1": 10, "pf": -4, "pb": 14, "bp": [2],
    })
    # передок
    sym(b, 4, 3, -20, 6, 4, -19, "head", HEADC)
    box(b, -3, 1, -20, 3, 3, -20, "trim", DARK)
    box(b, -6, 1, -20, 6, 1, -19, "trim", DARK)
    # зад: вертикальные фонари
    sym(b, 6, 3, 19, 7, 6, 19, "tail", TAILC)
    box(b, -2, 3, 19, 2, 4, 19, "trim", DARK)
    box(b, -7, 1, 19, 7, 2, 19, "trim", DARK)
    # спойлер на крышке
    box(b, -6, 10, 17, 6, 10, 19, "trim", DARK)
    # двери
    for sx in [-8, 8]:
        for y in range(2, 7):
            for z in [-4, 3]:
                b.put(sx, y, z, "trim", DARK)
        b.put(sx, 6, -1, "rim", STEEL)
        b.put(sx, 6, 6, "rim", STEEL)
    sym(b, 8, 9, -6, 9, 9, -6, "trim", DARK)
    # рейлинги
    sym(b, 6, 14, -1, 6, 14, 10, "trim", DARK)
    # салон
    seat_row(b, -3, 9, 2, 5)
    seat_row(b, 6, 9, 2, 6)
    cockpit(b, -7, 8, 6, -3)
