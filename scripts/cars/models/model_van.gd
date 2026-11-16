extends CarModel
## Van: цельнометаллический фургон с высоким грузовым отсеком, 5.6 м.

func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    make_body(b, paint, {
        "z0": -28, "z1": 27,
        "top": [[-28.0, 7.0], [-26.0, 11.0], [-12.0, 14.0], [-11.0, 22.0], [26.0, 22.0], [27.0, 21.0]],
        "wid": [[-28.0, 8.0], [-26.0, 9.0], [27.0, 9.0]],
        "arches": [-1.9, 1.6], "arch_y": 0.14, "arch_r": 0.46, "arch_x": 7, "sill": 2,
    })
    make_cabin(b, paint, {
        "z0": -19, "z1": -12,
        "cab": [[-19.0, 14.0], [-13.0, 22.0], [-12.0, 22.0]],
        "hx": 8, "hxt": 8, "roof0": -13, "roof1": -12, "pf": -17, "pb": -12, "back_solid": true,
    })
    # решётка, фары, бампер
    box(b, -6, 3, -28, 6, 7, -28, "trim", DARK)
    for x in range(-5, 6, 2):
        box(b, x, 3, -28, x, 7, -28, "rim", STEEL)
    sym(b, 6, 7, -28, 8, 8, -28, "head", HEADC)
    box(b, -8, 2, -29, 8, 4, -29, "rim", STEEL)
    # грузовой отсек: панели, двери, окна
    for sx in [-9, 9]:
        for z in range(-10, 27):
            b.put(sx, 12, z, "trim", DARK2)
            if z > 10 or z < -2:
                b.put(sx, 4, z, "trim", DARK2)
        for y in range(5, 21):
            b.put(sx, y, 2, "trim", DARK2)
    box(b, 0, 3, 27, 0, 20, 27, "trim", DARK2)
    sym(b, 3, 14, 27, 7, 19, 27, "glass", GLASS)
    sym(b, 8, 6, 26, 9, 12, 27, "tail", TAILC)
    box(b, -8, 2, 28, 8, 3, 28, "rim", STEEL)
    # зеркала и люк на крыше
    sym(b, 9, 17, -17, 10, 19, -17, "trim", DARK)
    box(b, -3, 23, 5, 3, 23, 12, "trim", DARK2)
    # салон
    seat_row(b, -17, 15, 2, 6)
    cockpit(b, -19, 15, 7, -4)
