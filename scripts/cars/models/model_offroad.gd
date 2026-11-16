extends CarModel
## Off-road Truck: поднятый внедорожный пикап — рама, бросающийся в глаза кенгурятник, лебёдка, фары на крыше, шноркель.

func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    make_body(b, paint, {
        "z0": -25, "z1": 24, "y0": 3,
        "top": [[-25.0, 9.0], [-24.0, 11.0], [-14.0, 13.0], [-10.0, 14.0], [4.0, 14.0], [6.0, 12.0], [24.0, 12.0]],
        "wid": [[-25.0, 9.0], [-24.0, 10.0], [24.0, 10.0]],
        "arches": [-1.7, 1.6], "arch_y": 0.11, "arch_r": 0.7, "arch_x": 8,
    })
    make_cabin(b, paint, {
        "z0": -10, "z1": 5,
        "cab": [[-10.0, 14.0], [-6.0, 21.0], [1.0, 21.0], [5.0, 18.0]],
        "hx": 8, "hxt": 7, "roof0": -5, "roof1": 1, "pf": -8, "pb": 3,
    })
    # кузов-платформа
    clear_box(b, -8, 9, 7, 8, 12, 23)
    box(b, -8, 8, 7, 8, 8, 23, "trim", DARK2)
    box(b, -8, 8, 6, 8, 12, 6, "paint", paint)
    sym(b, 9, 12, 7, 10, 12, 24, "trim", DARK)
    box(b, -9, 12, 24, 9, 12, 24, "trim", DARK)
    # рама и мосты
    sym(b, 3, 1, -23, 4, 2, 22, "trim", DARK)
    for z in [-17, 16]:
        box(b, -10, 1, z, 10, 2, z, "trim", DARK)
    # арки-расширители
    for zc in [-17, 16]:
        sym(b, 10, 8, zc - 6, 11, 9, zc + 6, "trim", DARK)
    # передок: решётка, фары, кенгурятник, лебёдка
    box(b, -5, 5, -25, 5, 8, -25, "trim", DARK)
    for x in range(-4, 5, 2):
        box(b, x, 5, -25, x, 8, -25, "rim", STEEL)
    sym(b, 7, 8, -25, 8, 9, -25, "head", HEADC)
    box(b, -9, 3, -26, 9, 5, -26, "trim", DARK)
    sym(b, 6, 6, -26, 6, 9, -26, "trim", DARK)
    box(b, -6, 9, -26, 6, 9, -26, "trim", DARK)
    box(b, -2, 3, -27, 2, 4, -27, "rim", STEEL)
    # зад
    sym(b, 8, 8, 24, 9, 10, 24, "tail", TAILC)
    box(b, -9, 3, 25, 9, 4, 25, "trim", DARK)
    # крыша: световая балка, шноркель
    box(b, -7, 22, -5, 7, 22, -5, "trim", DARK)
    for x in [-6, -2, 2, 6]:
        box(b, x, 23, -5, x, 24, -5, "head", HEADC)
    box(b, 9, 14, -9, 9, 23, -9, "trim", DARK)
    box(b, 9, 23, -10, 9, 23, -9, "trim", DARK)
    # двери
    for sx in [-10, 10]:
        for y in range(5, 14):
            for z in [-7, 1]:
                b.put(sx, y, z, "trim", DARK)
        b.put(sx, 11, -3, "rim", STEEL)
    sym(b, 9, 17, -9, 10, 17, -9, "trim", DARK)
    # салон
    seat_row(b, -5, 15, 2, 6)
    cockpit(b, -9, 15, 7, -4)
