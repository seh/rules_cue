load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive")
load("@bazel_gazelle//:deps.bzl", "gazelle_dependencies", "go_repository")

_cue_runtimes = {
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
    "0.3.1": [
        {
            "os": "Darwin",
            "arch": "amd64",
            "sha256": "c98e3f139418325f7b33e209cd1c41013c77270349225515e328a2918beaefb1",
        },
        {
            "os": "Linux",
            "arch": "amd64",
            "sha256": "a63533b74708c57e325ccfbefd717876205cb64d67166b6de2a27f5408577825",
        },
        {
            "os": "Linux",
            "arch": "arm64",
            "sha256": "a1e7f1f7f84a6d3df4532b5197c4d76ced37b2889505f88b8760d92c57a05f02",
        },
        {
            "os": "Windows",
            "arch": "amd64",
            "sha256": "23e7e57021a921cc5fb1d9a23dea4d430766e23e628e6ba7099f0f5ed39dc82f",
        },
    ],
}

def cue_register_toolchains(version = "0.3.2"):
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

def cue_rules_dependencies():
    go_repository(
        name = "com_github_cockroachdb_apd_v2",
        importpath = "github.com/cockroachdb/apd/v2",
        sum = "h1:y1Rh3tEU89D+7Tgbw+lp52T6p/GJLpDmNvr10UWqLTE=",
        version = "v2.0.1",
    )

    go_repository(
        name = "com_github_mpvl_unique",
        importpath = "github.com/mpvl/unique",
        sum = "h1:D5x39vF5KCwKQaw+OC9ZPiLVHXz3UFw2+psEX+gYcto=",
        version = "v0.0.0-20150818121801-cbe035fff7de",
    )

    go_repository(
        name = "com_github_pkg_errors",
        importpath = "github.com/pkg/errors",
        sum = "h1:iURUrRGxPUNPdy5/HRSm+Yj6okJ6UtLINN0Q9M4+h3I=",
        version = "v0.8.1",
    )

    go_repository(
        name = "org_cuelang_go",
        importpath = "cuelang.org/go",
        sum = "h1:RIZpXgS3nw+hWFDbxm5peKo3XHIDJTpcaS9TCmpcVrA=",
        version = "v0.1.1",
    )

    go_repository(
        name = "org_golang_x_xerrors",
        importpath = "golang.org/x/xerrors",
        sum = "h1:E7g+9GITq07hpfrRu66IVDexMakfv52eLZ2CXBWiKr4=",
        version = "v0.0.0-20191204190536-9bdfabe68543",
    )

    go_repository(
        name = "com_github_iancoleman_strcase",
        importpath = "github.com/iancoleman/strcase",
        sum = "h1:VHgatEHNcBFEB7inlalqfNqw65aNkM1lGX2yt3NmbS8=",
        version = "v0.0.0-20191112232945-16388991a334",
    )

    go_repository(
        name = "io_rsc_zipmerge",
        importpath = "rsc.io/zipmerge",
        sum = "h1:SQ3COGthAQ0mTF+xfVFKwmYag+U/QmnUVhNs4YEP8hQ=",
        version = "v0.0.0-20160407035457-24e6c1052c64",
    )
