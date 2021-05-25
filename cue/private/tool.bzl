load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)

_cue_runtimes = {
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
    "0.4.0-rc.1": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "702ff6c6e04df5cf757512faa28ad0ee3bbd1992dcd315a5504c0c6600d8aa3a",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "a96f8dc767e83fa865a42d1ab5fbe604046f4b77c0c261def228f4ead556120b",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "55b30333e44177fc40004ef67411b7743997ca973b968ee6d7a573f7500daf76",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "45050f49862169d8153ecea3eb0b92550e83a1bc0f973489881460182371868c",
        },
    ],
    "0.3.2": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "b9a3fb15f9c52ce3d83c3696a675463b3cf203f75d94467378bf4987826396cd",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "c80da4c9439e633e293fcebf840d082048cb0a79faa61aa55e6edf13d8e7d4d5",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "a4f900c4640f67b49a55769adc9da1943193ce196181072d1f28e79e6ee48a32",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "3ee17ebb1a2565c16cdd3a66a165b70e8f47d5e86f230455dc629c9d0ce6a8c8",
        },
    ],
}

def cue_register_tool(version = "0.4.0"):
    for platform in _cue_runtimes[version]:
        suffix = "tar.gz"
        if platform["os"] == "Windows":
            suffix = "zip"
        http_archive(
            name = "cue_runtime_%s_%s" % (platform["os"].lower(), platform["arch"]),
            build_file_content = """exports_files(["cue"], visibility = ["//visibility:public"])""",
            url = "https://github.com/cuelang/cue/releases/download/v%s/cue_v%s_%s_%s.%s" % (version, version, platform["os"].lower(), platform["arch"], suffix),
            sha256 = platform["sha256"],
        )
