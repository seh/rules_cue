load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)

_cue_runtimes = {
    "0.4.0-beta.1": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "3949038e2eab93ab066874ede21910d64f46ac89520a7a873a6e871d94769947",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "187bddf61b87f14c735e2404a5f3fa08dba949457e17104bf248b1d1a7e267dd",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "676ee508fe1908fd84b59959d3150f3b5b0248d73a7fda95d768a2f7ab1c4062",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "5f443bde940beeb34798822797e32f2ba2c2e283e97be9fdc34083017efe6e4b",
        },
    ],
    "0.4.0-alpha.2": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "f92186a816e4f285d2908856c653d1288befd8cd98f7d7466c02ef1a31d64de4",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "45ee3566098abe53e4c5d5d6a5d92d4f9ecc3768d5bdff3dff88474d0bf85e6d",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "3882aa887bc928081f35559312d344e4cb4dc282b9c751990df92aa33fdc1a9a",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "4ed38cba4a40c7a0f60f3b66c601bb812855b8dd597b74421271cecdeeeba7c4",
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

def cue_register_tool(version = "0.4.0-beta.1"):
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
