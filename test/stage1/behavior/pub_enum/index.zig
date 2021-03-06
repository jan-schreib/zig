const other = @import("other.zig");
const expect = @import("std").testing.expect;

test "pub enum" {
    pubEnumTest(other.APubEnum.Two);
}
fn pubEnumTest(foo: other.APubEnum) void {
    expect(foo == other.APubEnum.Two);
}

test "cast with imported symbol" {
    expect(other.size_t(42) == 42);
}
