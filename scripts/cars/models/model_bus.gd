extends CarModel
## Bus: городской автобус, 11 м, большие окна, салон с сиденьями.

func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    make_body(b, paint, {
        "z0": -55, "z1": 54, "y0": 2, "cham": false,
        "top": [[-55.0, 12.0], [54.0, 12.0]],
        "wid": [[-55.0, 11.0], [-52.0, 12.0], [54.0, 12.0]],
        "arches": [-3.3, 2.7], "arch_y": 0.2, "arch_r": 0.62, "arch_x": 9,
    })
    make_cabin(b, paint, {
        "z0": -54, "z1": 53,
        "cab": [[-54.0, 28.0], [53.0, 28.0]],
        "hx": 11, "hxt": 11, "roof0": -54, "roof1": 53, "pf": -53, "pb": 52,
        "bp": [-42, -30, -18, -6, 6, 18, 30, 42], "back_solid": true,
    })
    # пояс, двери
    for sx in [-12, 12]:
        for z in range(-54, 54):
            b.put(sx, 12, z, "trim", DARK)
            b.put(sx, 7, z, "trim", DARK2)
    box(b, 11, 3, -50, 12, 11, -45, "glass", GLASS)
    for z in [-51, -44]:
        box(b, 11, 3, z, 12, 11, z, "trim", DARK)
    box(b, 11, 3, -48, 12, 11, -48, "trim", DARK)
    # передок: фары, бампер, табло маршрута
    sym(b, 8, 4, -55, 10, 6, -55, "head", HEADC)
    box(b, -11, 2, -56, 11, 4, -56, "rim", STEEL)
    box(b, -8, 26, -54, 8, 27, -54, "trim", DARK)
    for x in range(-7, 8, 2):
        b.put(x, 26, -54, "head", Color(1.0, 0.7, 0.1))
    sym(b, 12, 18, -52, 14, 18, -52, "trim", DARK)
    sym(b, 14, 19, -52, 14, 24, -52, "trim", DARK)
    # корма
    sym(b, 9, 5, 54, 11, 9, 54, "tail", TAILC)
    box(b, -11, 2, 55, 11, 4, 55, "rim", STEEL)
    box(b, -8, 16, 53, 8, 23, 53, "glass", GLASS)
    # крыша: люки, кондиционер
    box(b, -3, 29, -10, 3, 29, -4, "trim", DARK2)
    box(b, -6, 29, 10, 6, 30, 22, "trim", DARK2)
    # салон
    var bus_seat := Color(0.12, 0.16, 0.35)
    for zr in range(-38, 40, 8):
        seat_row(b, zr, 13, 3, 9, bus_seat, 3)
    box(b, -7, 13, -50, -5, 13, -48, "trim", DARK2)
    cockpit(b, -53, 13, 9, -6)
