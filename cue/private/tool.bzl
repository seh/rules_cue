load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)

_cue_runtimes = {
    "0.4.3": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "1161254cf38b928b87a7ac1552dc2e12e6c5da298f9ce370d80e5518ddb6513d",
        },
        {
            "os": "Darwin",
            "arch": "arm64",
            "sha256": "3d84b85a7288f94301a4726dcf95b2d92c8ff796c4d45c4733fbdcc04ceaf21d",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "5e7ecb614b5926acfc36eb1258800391ab7c6e6e026fa7cacbfe92006bac895c",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "a8c3f4140d18c324cc69f5de4df0566e529e1636cff340095a42475799bf3fed",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "67f76e36809565c1396cea1b44978d98807d980d55a7ddc3979396d34fac1037",
        },
        {
            "os": "Windows",
            "arch": "arm64",
            "sha256": "a87573f32213a72d763dd624a1b63414e3d862ae4cef0b2698652aef380ebe60",
        },
    ],
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
}

def cue_register_tool(version = "0.4.3"):
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
