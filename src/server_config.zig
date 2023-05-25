///The root directory of the server
root_dir: []const u8 = ".",
///Allow plain directory listings in these dirs (recursive)
allow_listing_in_dirs: []const []const u8 = &.{},
///The template file to base all selectors on
template_file: ?[]const u8 = null,
///The port for the server to run on, overridden by the `-p` CLI flag
port: u16 = 70,
