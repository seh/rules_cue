load(
    "@bazel_tools//tools/build_defs/repo:http.bzl",
    "http_archive",
)

_cue_runtimes = {
    "0.5.0-beta.2": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "3e09097396c513795fcfe58adeb648cc860091ce72a14404b5c5594c1e4b063f",
        },
        {
            "os": "Darwin",
            "arch": "arm64",
            "sha256": "d0f0e27f4086e283de52acf3367c3a3671843f3dae9b1fc42d54c5311d529fc0",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "2442309d506008061414f13625633370b904cd0b2a4e4b157f33d3b773584640",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "de7d476a3775aa860a991edf1a7cef4cb223b28e15145ec62afb00c0ee569c1c",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "7aa4fad5cdc97c78dacc5ee294c6f5faaf057d870b495ef91fb0e3b80c529931",
        },
        {
            "os": "Windows",
            "arch": "arm64",
            "sha256": "716a0a6bbf4e086a2defc9ecbe2d95f1f7f01888265e9cc5763b50043d827245",
        },
    ],
    "0.5.0-beta.1": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "936dedc7f1630821956bae5d8aab7b0f0c5c63ea56d329c5030b59fb2613b0cd",
        },
        {
            "os": "Darwin",
            "arch": "arm64",
            "sha256": "9fa583fcdd45e4f446388aca1f50acc213c2186fe0491e21448051eed0d2b2a2",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "8fba35aa3aaa9ab7ec012f6522d006125168605c24fe93e14f6aec5789f99df0",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "4d9c36b4b491ba4a4bf851eda384402bd98e4ba0b54aeccedc51067644a43848",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "015dac67700ebed36babb9b72d1823a7590bbfabf929dd7df308b44c3ed532c1",
        },
        {
            "os": "Windows",
            "arch": "arm64",
            "sha256": "6002984bfec5362572eaf7995b19bf55c0085f6e9171614e2f4b8ad3c84dfc6e",
        },
    ],
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
