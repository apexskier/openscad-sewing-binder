$fn=10;

thickness = 2;
half_thickness = thickness / 2;

modified_width = 25 + 4;
half_width = modified_width / 2;
h = 50;
step = 1 / 10;

function f_arc(z, a) =
    let (
        d = min(1/z^3 + half_thickness - 1, 100000000),
        r = max(thickness, d) / 2,
    )
    [
        r * sin(a) + half_width, // x
        r * cos(a) - r, // y
        z * h
    ];

function df_arc_da(z, a) =
    let (
        d = min(1/z^3 + half_thickness - 1, 100000000),
        r = max(thickness, d) / 2,
    )
    [r * cos(a), -r * sin(a), 0];

function df_arc_dz(z, a) =
    [sin(a) * (-3/(2*z^4)), (-3/(2*z^4)) * (cos(a) - 1), h];

function df_arc(z, a, t) =
    let (
        dfda_v = df_arc_da(z, a),
        dfdz_v = df_arc_dz(z, a),
        normal = cross(dfda_v, dfdz_v),
        len = norm(normal),
        unit_normal = len == 0 ? [0, 0, 0] : [normal[0] / len, normal[1] / len, normal[2] / len],
        original = f_arc(z, a),
    )
    [
        original[0] + unit_normal[0] * t,
        original[1] + unit_normal[1] * t,
        original[2] + unit_normal[2] * t
    ];

function f_arm(z, a) =
    let (
        d = min(1/z^3 + half_thickness - 1, 100000000),
        c = PI * d,
        arc = min(180, 360 * (modified_width / c)),
        r = max(thickness, d) / 2,
        outer_r = r + half_thickness,
        inner_r = r - half_thickness,
        arm_length = max(0, modified_width - c/2) / 2,
        tz = z * h,
    )
    [
        half_width - r - half_thickness,
        -(r + arm_length),
        tz
    ];

function df_arm() = [];

points = [ for (z = [0:step:1]) each
    let (
        d = min(1/z^3 + half_thickness - 1, 100000000),
        c = PI * d,
        arc = min(180, 360 * (modified_width / c)),
        r = max(thickness, d) / 2,
        outer_r = r + half_thickness,
        inner_r = r - half_thickness,
        arm_length = max(0, modified_width - c/2) / 2,
        tz = z * h,
    )

    [
        // outer start arm
        arm_length > 0
            ? [half_width - r - half_thickness, -(r + arm_length), tz]
            : df_arc(z+0.0001, -arc/2, -half_thickness),

        // outside of arc
        for (a = [-arc/2:arc/$fn:arc/2]) df_arc(z+0.0001, a, -half_thickness),

        // outer end arm
        arm_length > 0
            ? [half_width + r + half_thickness, -(r + arm_length), tz]
            : df_arc(z+0.0001, arc/2, -half_thickness),
        // inner end arm
        arm_length > 0
            ? [half_width + r - half_thickness, -(r + arm_length), tz]
            : df_arc(z+0.0001, arc/2, half_thickness),

        // inside of arc
        for (a = [arc/2:-arc/$fn:-arc/2]) df_arc(z+0.0001, a, half_thickness),

        // inner start arm
        arm_length > 0
            ? [half_width - r + half_thickness, -(r + arm_length), tz]
            : df_arc(z+0.0001, -arc/2, half_thickness),
    ]
];

points_per_layer = ($fn + 1) * 2 + 4;

faces = [
    for (x = [1:points_per_layer/2]) [
        points_per_layer - (x + 1),
        points_per_layer - (x + 2),
        x + 1,
        x,
    ],

    for (z = [0:step:1-step]) let (
        mz = z/step
    ) each [
        for (x = [0:points_per_layer-2]) [
            mz*points_per_layer + x,
            mz*points_per_layer + x + 1,
            (mz+1)*points_per_layer + x + 1,
            (mz+1)*points_per_layer + x
        ],
        [
            mz*points_per_layer + points_per_layer-1,
            mz*points_per_layer,
            mz*points_per_layer + points_per_layer-1 + 1,
            (mz+1)*points_per_layer + points_per_layer-1,
        ]
    ],

    for (x = [0:points_per_layer/2-2]) [
        len(points) - points_per_layer + x,
        len(points) - points_per_layer + x + 1,
        len(points) - x - 1 - 1,
        len(points) - x - 1,
    ],
];

difference() {
    // linear_extrude(h)
    //     offset(2)
    //     translate([0, -modified_width+half_thickness, 0])
    //         square([modified_width, modified_width]);

    polyhedron(points, faces);
}
