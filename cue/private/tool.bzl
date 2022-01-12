load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)

_cue_runtimes = {
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
    "0.4.0": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "24717a72b067a4d8f4243b51832f4a627eaa7e32abc4b9117b0af9aa63ae0332",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "a118177d9c605b4fc1a61c15a90fddf57a661136c868dbcaa9d2406c95897949",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "d101a36607981a7652b7961955a84102c912ac35ca9d91de63a0201f2416ecfa",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "13a2db61e78473db0fab0530e8ebf70aa37ed6fb88ee14df240880ec7e70c0f1",
        },
    ],
}

def cue_register_tool(version = "0.4.1"):
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
