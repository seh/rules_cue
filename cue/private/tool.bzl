load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)

_cue_runtimes = {
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
    "0.4.0-beta.2": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "b9907d8ee02eaf0c66b8a09a103f7861cf797710923be2e3d7da3d35531a2c17",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "5e5dde1b57960751c1af0a0e7ea4751566b83d904ba0b1eb6a1b79ddc76574b8",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "49cd67a23a51bf1aa4f785365afd666dafedbc144b4458c91edb02ad0785d907",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "9feeed6eb1eb71856836344243d5ec2e17ace877ed2b00dae17e7d584a6b2109",
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

def cue_register_tool(version = "0.4.0-rc.1"):
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
