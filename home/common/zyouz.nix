{ ... }: {
  programs.zyouz = {
    enable = true;

    config = ''
      .{
          .layouts = .{
              .{
                  .name = "default",
                  .root = .{
                      .direction = .horizontal,
                      .children = .{
                          .{
                              .direction = .vertical,
                              .size = .{ .percent = 60 },
                              .children = .{
                                  .{
                                      .command = .{ "gati", "." },
                                      .size = .{ .percent = 75 },
                                      .mouse = .passthrough,
                                      .name = "editor",
                                  },
                                  .{
                                      .command = .{"zsh"},
                                      .size = .{ .percent = 25 },
                                      .name = "terminal",
                                  },
                              },
                          },
                          .{
                              .command = .{ "claude", "-c", "--permission-mode", "auto" },
                              .size = .{ .percent = 40 },
                              .name = "claude",
                          },
                      },
                  },
              },
          },
      }
    '';
  };
}
