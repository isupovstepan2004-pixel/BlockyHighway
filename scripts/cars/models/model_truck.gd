extends CarModel
## Truck: седельный тягач с капотной кабиной и прицепом-фурой, 14 м (5 осей).

func build(b: VoxelBuilder, paint: Color) -> void:
    b.size = 0.1
    b.origin = Vector3(-0.05, 0.0, 0.0)
    # --- тягач: капот, кабина, рама
    make_body(b, paint, {
        "z0": -70, "z1": -15, "y0": 2,
        "top": [[-70.0, 10.0], [-69.0, 17.0], [-59.0, 18.0], [-58.0, 20.0], [-44.0, 20.0], [-43.0, 8.0], [-15.0, 8.0]],
        "wid": [[-70.0, 10.0], [-67.0, 12.0], [-44.0, 12.0], [-43.0, 7.0], [-15.0, 7.0]],
        "arches": [-5.2], "arch_y": 0.15, "arch_r": 0.62, "arch_x": 9,
    })
    make_cabin(b, paint, {
        "z0": -57, "z1": -44,
        "cab": [[-57.0, 20.0], [-55.0, 29.0], [-46.0, 29.0], [-44.0, 26.0]],
        "hx": 11, "hxt": 10, "roof0": -54, "roof1": -46, "pf": -56, "pb": -45, "back_solid": true,
    })
    # решётка радиатора, фары, бампер
    box(b, -8, 4, -70, 8, 14, -70, "trim", DARK)
    for x in range(-7, 8, 2):
        box(b, x, 4, -70, x, 14, -70, "rim", STEEL)
    sym(b, 8, 10, -70, 10, 12, -69, "head", HEADC)
    box(b, -11, 2, -72, 11, 5, -71, "rim", STEEL)
    # капот: вентиляция
    for z in range(-66, -60):
        for x in [-4, -3, 3, 4]:
            b.put(x, top_at(z), z, "trim", DARK)
    # выхлопные трубы, баки, зеркала
    sym(b, 13, 20, -43, 13, 38, -43, "rim", STEEL)
    sym(b, 13, 38, -43, 13, 38, -43, "trim", DARK)
    sym(b, 12, 3, -52, 14, 9, -46, "rim", STEEL)
    sym(b, 13, 22, -57, 14, 27, -57, "trim", DARK)
    box(b, -9, 30, -56, 9, 30, -54, "trim", DARK)
    # рама, мосты, седло
    sym(b, 4, 4, -62, 5, 6, -15, "trim", DARK)
    for z in [-34, -22]:
        box(b, -10, 1, z, 10, 2, z, "trim", DARK)
    box(b, -8, 8, -42, 8, 9, -36, "trim", DARK2)
    # салон
    seat_row(b, -53, 21, 2, 8)
    cockpit(b, -56, 21, 9, -5)

    # --- прицеп
    var gray := Color(0.62, 0.63, 0.66)
    make_body(b, gray, {
        "z0": -38, "z1": 69, "y0": 9, "cham": false,
        "top": [[-38.0, 38.0], [69.0, 38.0]],
        "wid": [[-38.0, 12.0], [69.0, 12.0]],
    })
    var rib := Color(0.50, 0.51, 0.54)
    for z in range(-36, 69, 6):
        for y in range(11, 38):
            b.put(12, y, z, "paint", rib)
            b.put(-12, y, z, "paint", rib)
    box(b, -12, 9, -38, 12, 9, 69, "trim", DARK2)
    sym(b, 9, 11, 69, 11, 14, 70, "tail", TAILC)
    box(b, -11, 8, 70, 11, 9, 70, "rim", STEEL)
    box(b, 0, 10, 69, 0, 37, 69, "trim", DARK2)
    sym(b, 4, 6, -38, 5, 8, 69, "trim", DARK)
    for z in [48, 60]:
        box(b, -10, 1, z, 10, 2, z, "trim", DARK)
