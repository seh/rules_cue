load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)

_cue_runtimes = {
    "0.4.2": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "3da1576d36950c64acb7d7a7b80f34e5935ac76b9ff607517981eef44a88a31b",
        },
        {
            "os": "Darwin",
            "arch": "arm64",
            "sha256": "21fcfbe52beff7bae510bb6267fe33a5785039bd7d5f32e3c3222c55580dd85c",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "d43cf77e54f42619d270b8e4c1836aec87304daf243449c503251e6943f7466a",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "6515c1f1b6fc09d083be533019416b28abd91e5cdd8ef53cd0719a4b4b0cd1c7",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "95be4cd6b04b6c729f4f85a551280378d8939773c2eaecd79c70f907b5cae847",
        },
        {
            "os": "Windows",
            "arch": "arm64",
            "sha256": "e03325656ca20d464307f68e3070d774af37e5777156ae983e166d7d7aed60df",
        },
    ],
    "0.4.1": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "9904f316160803cb011b7ed7524626719741a609623fe89abf149ab7522acffd",
        },
        {
            "os": "Darwin",
            "arch": "arm64",
            "sha256": "ff47c8e52a82aa3cf5d02647a6422dd9e824c5210607655a6c8abe700eae56d1",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "d3f1df656101a498237d0a8b168a22253dde11f6b6b8cc577508b13a112142de",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "e0d63e0df5231687acfd6da09bd672b5b11008a4cfa1927046ec9802864280e6",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "5bfb9934b71878633691dc0b373214105361491effa28461abb336c338c41176",
        },
        {
            "os": "Windows",
            "arch": "arm64",
            "sha256": "1b9b7ddf17ec59447147e8199207bf3e3311f242d7b745ea317679f01782779a",
        },
    ],
}

def cue_register_tool(version = "0.4.2"):
    for platform in _cue_runtimes[version]:
        suffix = "tar.gz"
        if platform["os"] == "Windows":
            suffix = "zip"
        http_archive(
            name = "cue_runtime_%s_%s" % (platform["os"].lower(), platform["arch"]),
            build_file_content = """exports_files(["cue"], visibility = ["//visibility:public"])""",
            url = "https://github.com/cue-lang/cue/releases/download/v%s/cue_v%s_%s_%s.%s" % (version, version, platform["os"].lower(), platform["arch"], suffix),
            sha256 = platform["sha256"],
        )
