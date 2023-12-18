genrule(
    name = "fill_file_1kb",
    outs = ["file_1kb"],
    cmd = "head -c 1024 </dev/zero >$@",
    tags = ["manual"],
)

genrule(
    name = "copy_file_1kb",
    srcs = ["file_1kb"],
    outs = ["copied_file_1kb"],
    cmd = "cat $(SRCS) > $@",
    tags = ["manual"],
)
