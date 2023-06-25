const std = @import("std");
const assert = std.debug.assert;
const Allocator = std.mem.Allocator;
const foundation = @import("../foundation.zig");
const graphics = @import("../graphics.zig");
const text = @import("../text.zig");
const c = @import("c.zig");

pub const Line = opaque {
    pub fn createWithAttributedString(str: *foundation.AttributedString) Allocator.Error!*Line {
        return @ptrFromInt(
            ?*Line,
            @intFromPtr(c.CTLineCreateWithAttributedString(
                @ptrCast(c.CFAttributedStringRef, str),
            )),
        ) orelse Allocator.Error.OutOfMemory;
    }

    pub fn release(self: *Line) void {
        foundation.CFRelease(self);
    }

    pub fn getGlyphCount(self: *Line) usize {
        return @intCast(usize, c.CTLineGetGlyphCount(
            @ptrCast(c.CTLineRef, self),
        ));
    }

    pub fn getBoundsWithOptions(
        self: *Line,
        opts: LineBoundsOptions,
    ) graphics.Rect {
        // return @bitCast(c.CGRect, c.CTLineGetBoundsWithOptions(
        //     @ptrCast(c.CTLineRef, self),
        //     opts.cval(),
        // ));

        // We have to use a custom C wrapper here because there is some
        // C ABI issue happening.
        var result: graphics.Rect = undefined;
        zig_cabi_CTLineGetBoundsWithOptions(
            @ptrCast(c.CTLineRef, self),
            opts.cval(),
            @ptrCast(*c.CGRect, &result),
        );

        return result;
    }

    // See getBoundsWithOptions
    extern "c" fn zig_cabi_CTLineGetBoundsWithOptions(
        c.CTLineRef,
        c.CTLineBoundsOptions,
        *c.CGRect,
    ) void;

    pub fn getTypographicBounds(
        self: *Line,
        ascent: ?*f64,
        descent: ?*f64,
        leading: ?*f64,
    ) f64 {
        return c.CTLineGetTypographicBounds(
            @ptrCast(c.CTLineRef, self),
            ascent,
            descent,
            leading,
        );
    }
};

pub const LineBoundsOptions = packed struct {
    exclude_leading: bool = false,
    exclude_shifts: bool = false,
    hanging_punctuation: bool = false,
    glyph_path_bounds: bool = false,
    use_optical_bounds: bool = false,
    language_extents: bool = false,
    _padding: u58 = 0,

    pub fn cval(self: LineBoundsOptions) c.CTLineBoundsOptions {
        return @bitCast(c.CTLineBoundsOptions, self);
    }

    test {
        try std.testing.expectEqual(
            @bitSizeOf(c.CTLineBoundsOptions),
            @bitSizeOf(LineBoundsOptions),
        );
    }

    test "bitcast" {
        const actual: c.CTLineBoundsOptions = c.kCTLineBoundsExcludeTypographicShifts |
            c.kCTLineBoundsUseOpticalBounds;
        const expected: LineBoundsOptions = .{
            .exclude_shifts = true,
            .use_optical_bounds = true,
        };

        try std.testing.expectEqual(actual, @bitCast(c.CTLineBoundsOptions, expected));
    }
};

test {
    @import("std").testing.refAllDecls(@This());
}

test "line" {
    const testing = std.testing;

    const font = font: {
        const name = try foundation.String.createWithBytes("Monaco", .utf8, false);
        defer name.release();
        const desc = try text.FontDescriptor.createWithNameAndSize(name, 12);
        defer desc.release();

        break :font try text.Font.createWithFontDescriptor(desc, 12);
    };
    defer font.release();

    const rep = try foundation.String.createWithBytes("hello", .utf8, false);
    defer rep.release();
    const str = try foundation.MutableAttributedString.create(rep.getLength());
    defer str.release();
    str.replaceString(foundation.Range.init(0, 0), rep);
    str.setAttribute(
        foundation.Range.init(0, rep.getLength()),
        text.StringAttribute.font,
        font,
    );

    const line = try Line.createWithAttributedString(@ptrCast(*foundation.AttributedString, str));
    defer line.release();

    try testing.expectEqual(@as(usize, 5), line.getGlyphCount());

    // TODO: this is a garbage value but should work...
    const bounds = line.getBoundsWithOptions(.{});
    _ = bounds;
    //std.log.warn("bounds={}", .{bounds});
}
