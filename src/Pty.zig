//! Linux PTY creation and management. This is just a thin layer on top
//! of Linux syscalls. The caller is responsible for detail-oriented handling
//! of the returned file handles.
const Pty = @This();

const std = @import("std");
const testing = std.testing;
const linux = std.os.linux;
const fd_t = std.os.fd_t;
const winsize = linux.winsize;
const c = @cImport({
    @cInclude("pty.h");
});

/// The file descriptors for the master and slave side of the pty.
master: fd_t,
slave: fd_t,

/// Open a new PTY with the given initial size.
pub fn open(size: winsize) !Pty {
    var master_fd: fd_t = undefined;
    var slave_fd: fd_t = undefined;
    if (c.openpty(
        &master_fd,
        &slave_fd,
        null,
        null,
        @ptrCast([*c]const c.struct_winsize, &size),
    ) < 0)
        return error.OpenptyFailed;

    return Pty{
        .master = master_fd,
        .slave = slave_fd,
    };
}

pub fn deinit(self: *Pty) void {
    std.os.close(self.master);
    self.* = undefined;
}

/// Return the size of the pty.
pub fn getSize(self: Pty) !winsize {
    var ws: winsize = undefined;
    if (linux.ioctl(self.master, linux.T.IOCGWINSZ, @ptrToInt(&ws)) < 0)
        return error.IoctlFailed;

    return ws;
}

/// Set the size of the pty.
pub fn setSize(self: Pty, size: winsize) !void {
    if (linux.ioctl(self.master, linux.T.IOCSWINSZ, @ptrToInt(&size)) < 0)
        return error.IoctlFailed;
}

test {
    var ws: winsize = .{
        .ws_row = 50,
        .ws_col = 80,
        .ws_xpixel = 1,
        .ws_ypixel = 1,
    };

    var pty = try open(ws);
    defer pty.deinit();

    // Initialize size should match what we gave it
    try testing.expectEqual(ws, try pty.getSize());

    // Can set and read new sizes
    ws.ws_row *= 2;
    try pty.setSize(ws);
    try testing.expectEqual(ws, try pty.getSize());
}
