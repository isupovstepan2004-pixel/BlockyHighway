extends CarModel
## Racing Car: гоночный GT — широкие арки, сплиттер, огромное антикрыло, ливрея с полосами и номером.

func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    make_body(b, paint, {
        "z0": -23, "z1": 22,
        "top": [[-23.0, 2.0], [-21.0, 3.5], [-10.0, 4.5], [-4.0, 5.5], [10.0, 6.0], [18.0, 6.0], [22.0, 5.0]],
        "wid": [[-23.0, 8.0], [-19.0, 9.0], [-14.0, 10.0], [-6.0, 9.0], [6.0, 9.0], [13.0, 10.0], [22.0, 10.0]],
        "arches": [-1.4, 1.35], "arch_y": 0.26, "arch_r": 0.45, "arch_x": 7,
    })
    make_cabin(b, paint, {
        "z0": -6, "z1": 10,
        "cab": [[-6.0, 6.0], [-1.0, 9.0], [5.0, 9.0], [10.0, 6.0]],
        "hx": 5, "hxt": 4, "roof0": -1, "roof1": 5, "pf": -3, "pb": 7,
    })
    # белые полосы
    for z in range(-22, 22):
        if z >= -6 and z <= 10:
            continue
        for x in [-3, -2, 2, 3]:
            b.put(x, top_at(z), z, "paint", WHITE)
    # номер на дверях
    for sx in [-9, 9]:
        for y in range(1, 6):
            for z in range(-1, 6):
                var dz: int = z - 2
                var dy: int = y - 3
                if dz * dz + dy * dy <= 9:
                    b.put(sx, y, z, "paint", WHITE)
        for y in range(2, 5):
            b.put(sx, y, 2, "trim", DARK)
        b.put(sx, 4, 1, "trim", DARK)
    # сплиттер и фары
    box(b, -8, 0, -25, 8, 1, -23, "trim", CARBON)
    sym(b, 5, 2, -23, 7, 3, -22, "head", HEADC)
    box(b, -3, 1, -23, 3, 2, -23, "trim", DARK)
    sym(b, 9, 2, -22, 9, 3, -20, "trim", CARBON)
    # зад: фонари, диффузор
    sym(b, 4, 3, 21, 8, 4, 22, "tail", TAILC)
    box(b, -8, 0, 21, 8, 1, 23, "trim", CARBON)
    sym(b, 3, 1, 22, 3, 1, 23, "rim", STEEL)
    # антикрыло
    box(b, -10, 12, 17, 10, 12, 21, "trim", CARBON)
    sym(b, 6, 7, 19, 6, 11, 19, "trim", CARBON)
    sym(b, 10, 11, 17, 10, 14, 21, "trim", CARBON)
    # воздухозаборник на крыше
    box(b, -1, 10, 0, 1, 10, 2, "trim", CARBON)
    # салон
    seat_row(b, 1, 7, 1, 3, SEAT, 2)
    box(b, -4, 7, -5, 4, 7, -4, "trim", DARK)
    b.put(-2, 8, -3, "trim", DARK)
    b.put(-3, 8, -3, "trim", DARK)
