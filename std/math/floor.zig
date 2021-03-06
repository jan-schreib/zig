// Special Cases:
//
// - floor(+-0)   = +-0
// - floor(+-inf) = +-inf
// - floor(nan)   = nan

const builtin = @import("builtin");
const expect = std.testing.expect;
const std = @import("../index.zig");
const math = std.math;

pub fn floor(x: var) @typeOf(x) {
    const T = @typeOf(x);
    return switch (T) {
        f16 => floor16(x),
        f32 => floor32(x),
        f64 => floor64(x),
        else => @compileError("floor not implemented for " ++ @typeName(T)),
    };
}

fn floor16(x: f16) f16 {
    var u = @bitCast(u16, x);
    const e = @intCast(i16, (u >> 10) & 31) - 15;
    var m: u16 = undefined;

    // TODO: Shouldn't need this explicit check.
    if (x == 0.0) {
        return x;
    }

    if (e >= 10) {
        return x;
    }

    if (e >= 0) {
        m = u16(1023) >> @intCast(u4, e);
        if (u & m == 0) {
            return x;
        }
        math.forceEval(x + 0x1.0p120);
        if (u >> 15 != 0) {
            u += m;
        }
        return @bitCast(f16, u & ~m);
    } else {
        math.forceEval(x + 0x1.0p120);
        if (u >> 15 == 0) {
            return 0.0;
        } else {
            return -1.0;
        }
    }
}

fn floor32(x: f32) f32 {
    var u = @bitCast(u32, x);
    const e = @intCast(i32, (u >> 23) & 0xFF) - 0x7F;
    var m: u32 = undefined;

    // TODO: Shouldn't need this explicit check.
    if (x == 0.0) {
        return x;
    }

    if (e >= 23) {
        return x;
    }

    if (e >= 0) {
        m = u32(0x007FFFFF) >> @intCast(u5, e);
        if (u & m == 0) {
            return x;
        }
        math.forceEval(x + 0x1.0p120);
        if (u >> 31 != 0) {
            u += m;
        }
        return @bitCast(f32, u & ~m);
    } else {
        math.forceEval(x + 0x1.0p120);
        if (u >> 31 == 0) {
            return 0.0;
        } else {
            return -1.0;
        }
    }
}

fn floor64(x: f64) f64 {
    const u = @bitCast(u64, x);
    const e = (u >> 52) & 0x7FF;
    var y: f64 = undefined;

    if (e >= 0x3FF + 52 or x == 0) {
        return x;
    }

    if (u >> 63 != 0) {
        y = x - math.f64_toint + math.f64_toint - x;
    } else {
        y = x + math.f64_toint - math.f64_toint - x;
    }

    if (e <= 0x3FF - 1) {
        math.forceEval(y);
        if (u >> 63 != 0) {
            return -1.0;
        } else {
            return 0.0;
        }
    } else if (y > 0) {
        return x + y - 1;
    } else {
        return x + y;
    }
}

test "math.floor" {
    expect(floor(f16(1.3)) == floor16(1.3));
    expect(floor(f32(1.3)) == floor32(1.3));
    expect(floor(f64(1.3)) == floor64(1.3));
}

test "math.floor16" {
    expect(floor16(1.3) == 1.0);
    expect(floor16(-1.3) == -2.0);
    expect(floor16(0.2) == 0.0);
}

test "math.floor32" {
    expect(floor32(1.3) == 1.0);
    expect(floor32(-1.3) == -2.0);
    expect(floor32(0.2) == 0.0);
}

test "math.floor64" {
    expect(floor64(1.3) == 1.0);
    expect(floor64(-1.3) == -2.0);
    expect(floor64(0.2) == 0.0);
}

test "math.floor16.special" {
    expect(floor16(0.0) == 0.0);
    expect(floor16(-0.0) == -0.0);
    expect(math.isPositiveInf(floor16(math.inf(f16))));
    expect(math.isNegativeInf(floor16(-math.inf(f16))));
    expect(math.isNan(floor16(math.nan(f16))));
}

test "math.floor32.special" {
    expect(floor32(0.0) == 0.0);
    expect(floor32(-0.0) == -0.0);
    expect(math.isPositiveInf(floor32(math.inf(f32))));
    expect(math.isNegativeInf(floor32(-math.inf(f32))));
    expect(math.isNan(floor32(math.nan(f32))));
}

test "math.floor64.special" {
    expect(floor64(0.0) == 0.0);
    expect(floor64(-0.0) == -0.0);
    expect(math.isPositiveInf(floor64(math.inf(f64))));
    expect(math.isNegativeInf(floor64(-math.inf(f64))));
    expect(math.isNan(floor64(math.nan(f64))));
}
