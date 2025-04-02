$fn=20;

module binder(width, thickness, height, cutout=true, $fn=$fn) {
    assert(thickness > 0, "thickness must be greater than 0");
    assert(width > 0, "width must be greater than 0");
    assert(width > thickness, "width must be greater than thickness");

    half_thickness = (thickness * 1.2) / 2;
    modified_width = width * 1.2;
    modified_height = height + 1;
    half_width = modified_width / 2;
    step = 1 / $fn;

    // we calculate the shape as if it's a flat surface with zero thickness,
    // then offset along the normal of the surface to ensure thickness is
    // maintained
    // normals are calculated using the partial derivatives of the surface
    // equation
    // if we offset along the z plane, as I originally did, thickness is reduced
    // when rate of change is higher

    function calculate_r(z) =
        ((min(1/z^3, 100000000) - 1) / 2) + half_thickness;

    function f_arc(z, a) =
        let (
            r = calculate_r(z)
        )
        [
            r * sin(a) + half_width, // x
            r * cos(a) - r, // y
            z * modified_height
        ];

    function df_arc_da(z, a) =
        let (
            r = calculate_r(z)
        )
        [
            r * cos(a),
            -r * sin(a),
            0
        ];

    function df_arc_dz(z, a) =
        z == 0
            ? [sin(a), (cos(a) - 1), modified_height]
            : [
                sin(a) * (-3/(2*z^4)),
                (-3/(2*z^4)) * (cos(a) - 1),
                modified_height
            ];

    function df_arc(z, a, t) =
        let (
            dfda_v = df_arc_da(z, a),
            dfdz_v = df_arc_dz(z, a),
            normal = cross(dfda_v, dfdz_v),
            len = norm(normal),
            unit_normal =
                // at top, ensure points are on the z = 1 plane so they all connect
                // without this we get precision errors that prevent a real solid
                z == 1
                    ? [-sin(a), -cos(a), 0]
                    : (len == 0
                        ? [0, 0, 0]
                        : [normal[0] / len, normal[1] / len, normal[2] / len]),
            original = f_arc(z, a),
        )
        [
            original[0] + unit_normal[0] * t,
            original[1] + unit_normal[1] * t,
            original[2] + unit_normal[2] * t
        ];

    function f_arm(z, start) =
        let (
            r = calculate_r(z),
            c = PI * 2 * r,
            arm_length = max(0, modified_width - c/2) / 2,
        )
        [
            half_width + (start ? -1 : 1) * r,
            -(r + arm_length),
            z * modified_height
        ];

    function df_arm_dz(z, start) =
        [
            (start ? 1 : -1) * (3/(2*z^4)),
            (3 - 3*PI/2)/(2*z^4),
            modified_height
        ];

    function df_arm(z, start, t) =
        let (
            dfdz_v = df_arm_dz(z, start),
            normal = cross(dfdz_v, [0, start ? -1 : 1, 0]),
            len = norm(dfdz_v),
            unit_normal =
            z == 1
                // at top, ensure points are on the z = 1 plane so they all connect
                // without this we get precision errors that prevent a real solid
                ? [start ? 1 : -1, 0, 0]
                : (len == 0
                    ? [0, 0, 0]
                    : [normal[0] / len, normal[1] / len, normal[2] / len]),
            original = f_arm(z, start),
        )
        [
            original[0] + unit_normal[0] * t,
            original[1] + unit_normal[1] * t,
            original[2] + unit_normal[2] * t
        ];

    points = [ for (z = [0:step:1]) each
        let (
            r = calculate_r(z),
            c = PI * 2 * r,
            arc = min(180, 360 * (modified_width / c)),
            arm_length = min(1, max(0, modified_width - c/2)) / 2,
        )

        [
            // outer start arm
            arm_length > 0
                ? df_arm(z, true, -half_thickness)
                : df_arc(z, -arc/2, -half_thickness),

            // outside of arc
            for (a = [-arc/2:arc/$fn:arc/2]) df_arc(z, a, -half_thickness),

            // outer end arm
            arm_length > 0
                ? df_arm(z, false, -half_thickness)
                : df_arc(z, arc/2, -half_thickness),
            // inner end arm
            arm_length > 0
                ? df_arm(z, false, half_thickness)
                : df_arc(z, arc/2, half_thickness),

            // inside of arc
            for (a = [arc/2:-arc/$fn:-arc/2]) df_arc(z, a, half_thickness),

            // inner start arm
            arm_length > 0
                ? df_arm(z, true, half_thickness)
                : df_arc(z, -arc/2, half_thickness),
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

        for (z = [0:len(points)/points_per_layer - 2]) each
            [
                for (x = [0:points_per_layer-2]) [
                    z * points_per_layer + x,
                    z * points_per_layer + x + 1,
                    (z + 1) * points_per_layer + x + 1,
                    (z + 1) * points_per_layer + x
                ],
                [
                    (z + 1) * points_per_layer - 1,
                    z * points_per_layer,
                    (z + 1) * points_per_layer,
                    (z + 2) * points_per_layer - 1,
                ],
            ],

        // flat cap over arms
        [
            len(points) - points_per_layer,
            len(points) - points_per_layer + 1,
            len(points) - points_per_layer + (points_per_layer/2-2),
            len(points) - points_per_layer + (points_per_layer/2-2) + 1,
        ],

        // flat cap over arc
        for (x = [1:points_per_layer/2-3]) [
            len(points) - points_per_layer + x,
            len(points) - points_per_layer + x + 1,
            len(points) - points_per_layer + (points_per_layer/2-2),
        ],
    ];

    difference() {
        if (cutout) {
            linear_extrude(height)
                offset(2)
                    translate([0, -modified_width+half_thickness])
                        square([modified_width, modified_width]);
        }

        translate([0, 0, -0.5])
            polyhedron(points, faces);
    }
}

binder(25, 2, 50, cutout=false);
