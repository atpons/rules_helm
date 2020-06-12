load("@bazel_tools//tools/build_defs/repo:http.bzl", "http_archive", "http_file")
load("@bazel_tools//tools/build_defs/repo:git.bzl", "new_git_repository")

def helm_repositories():
    skylib_version = "0.8.0"
    http_archive(
        name = "bazel_skylib",
        type = "tar.gz",
        url = "https://github.com/bazelbuild/bazel-skylib/releases/download/{}/bazel-skylib.{}.tar.gz".format(skylib_version, skylib_version),
        sha256 = "2ef429f5d7ce7111263289644d233707dba35e39696377ebab8b0bc701f7818e",
    )

    http_archive(
        name = "helm",
        sha256 = "3156e4fe5f034e5b127cf165d61a8a1c48eb7a73b14689b273de5e6117df6fe2",
        urls = ["https://get.helm.sh/helm-v3.2.3-linux-amd64.tar.gz"],
        build_file = "@com_github_tmc_rules_helm//:helm.BUILD",
        #
    )

    http_archive(
        name = "helm_osx",
        sha256 = "3062b35ec858b55810623f105eaa092a13676151d494cc8b1f0798b7354f555f",
        urls = ["https://get.helm.sh/helm-v3.2.3-alpha.1-darwin-amd64.tar.gz"],
        build_file = "@com_github_tmc_rules_helm//:helm.BUILD",
    )
