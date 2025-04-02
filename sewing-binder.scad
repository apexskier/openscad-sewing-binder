$fn=10;

thickness = 2;
half_thickness = thickness / 2;

modified_width = 25 + 4;
half_width = modified_width / 2;
h = 50;
step = 1 / 20;

// Function to calculate normal vector between three points
function calculate_normal(p1, p2, p3) =
    let(
        v1 = p2 - p1,
        v2 = p3 - p1,
        normal = cross(v1, v2)
    )
    normalize(normal);

function f(z, a) =
    let(
        d = min(1/z^3 + half_thickness - 1, 100000000),
        c = PI * d,
        arc = min(180, 360 * (modified_width / c)),
        r = max(thickness, d) / 2,
        arm_length = max(0, modified_width - c/2) / 2
    )
    [
        r * sin(a) + half_width, // x
        r * cos(a) - r, // y
        z * h
    ];

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
            : [
                outer_r * sin(-arc/2) + half_width, // x
                outer_r * cos(-arc/2) - r, // y
                tz
            ],

        // outside of arc
        for (a = [-arc/2:arc/$fn:arc/2]) [
            outer_r * sin(a) + half_width, // x
            outer_r * cos(a) - r, // y
            tz
        ],

        // outer end arm
        arm_length > 0
            ? [half_width + r + half_thickness, -(r + arm_length), tz]
            : [
                outer_r * sin(arc/2) + half_width, // x
                outer_r * cos(arc/2) - r, // y
                tz
            ],
        // inner end arm
        arm_length > 0
            ? [half_width + r - half_thickness, -(r + arm_length), tz]
            : [
                inner_r * sin(arc/2) + half_width, // x
                inner_r * cos(arc/2) - r, // y
                tz
            ],

        // inside of arc
        for (a = [arc/2:-arc/$fn:-arc/2]) [
            inner_r * sin(a) + half_width, // x
            inner_r * cos(a) - r, // y
            tz
        ],

        // inner start arm
        arm_length > 0
            ? [half_width - r + half_thickness, -(r + arm_length), tz]
            : [
                inner_r * sin(-arc/2) + half_width, // x
                inner_r * cos(-arc/2) - r, // y
                tz
            ],
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
