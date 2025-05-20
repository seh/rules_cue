load(
    "//cue:providers.bzl",
    "CUEModuleInfo",
)
load(
    "//cue/private:cue-module-cache.bzl",
    "cue_module_cache",
)

visibility("//cue")

def _cue_modules_summary_impl(ctx):
    cue_module_cache_repos_by_cue_module_file = "cue-module-cache-repos.bzl"
    ctx.file(
        cue_module_cache_repos_by_cue_module_file,
        "CUE_MODULE_CACHE_REPOS_BY_CUE_MODULE=" + repr(
            {
                # NB: If we serialize labels, when we load them later
                # from this file, Bazel "scopes" the labels to the
                # repository from which they're loaded, which isn't
                # what we mean to convey here.
                str(k): v
                for k, v in ctx.attr.cue_module_cache_repos_by_cue_module.items()
            },
        ),
    )
    ctx.file(
        "BUILD.bazel",
        "exports_files([" +
        ",".join(
            [
                '"' + f + '"'
                for f in [
                    cue_module_cache_repos_by_cue_module_file,
                ]
            ],
        ) +
        "])",
    )

_cue_modules_summary = repository_rule(
    implementation = _cue_modules_summary_impl,
    attrs = {
        "cue_module_cache_repos_by_cue_module": attr.label_keyed_string_dict(
            doc = "TODO(seh)",
            providers = [CUEModuleInfo],
        ),
    },
)

def _cue_module_cache_repo_name_for(bazel_module, cue_module_label):
    # TODO(seh): Is false aliasing possible here?
    return "_".join(
        [bazel_module.name] +
        ([cue_module_label.repo_name.replace("+", "_")] if cue_module_label.repo_name else []) +
        [
            cue_module_label.package.replace("/", "_"),
            cue_module_label.name,
        ],
    )

def _cue_modules_impl(ctx):
    cue_module_cache_repos_by_cue_module = dict()
    required_repository_names = set()
    required_dev_repository_names = set()
    for mod in ctx.modules:
        for cache in mod.tags.cache:
            is_dev_dependency = ctx.is_dev_dependency(cache)
            for cue_module_root in cache.module_roots:
                repository_name = _cue_module_cache_repo_name_for(mod, cue_module_root)
                cue_module_cache(
                    name = repository_name,
                    root = cue_module_root,
                )
                if mod.is_root:
                    if is_dev_dependency:
                        required_dev_repository_names.add(repository_name)
                    else:
                        required_repository_names.add(repository_name)
                cue_module_cache_repos_by_cue_module[cue_module_root] = str(Label("@{}//:cache.txt".format(repository_name)))

    # TODO(seh): Only create this repository on behalf of the root module?
    # TODO(seh): Distinguish its name for the root module? If so, how
    # would we know its name elsewhere in the "cue_module" rule's
    # attribute?
    # See https://bazel.build/external/extension#only_the_root_module_should_directly_affect_repository_names.
    modules_summary_repository_name = "cue_modules_summary"
    _cue_modules_summary(
        name = modules_summary_repository_name,
        cue_module_cache_repos_by_cue_module = cue_module_cache_repos_by_cue_module,
    )
    if ctx.root_module_has_non_dev_dependency:
        required_repository_names.add(modules_summary_repository_name)
    else:
        required_dev_repository_names.add(modules_summary_repository_name)

    return ctx.extension_metadata(
        root_module_direct_dev_deps = sorted([n for n in required_dev_repository_names]),
        root_module_direct_deps = sorted([n for n in required_repository_names]),
    )

cue_modules = module_extension(
    implementation = _cue_modules_impl,
    tag_classes = {
        "cache": tag_class(
            attrs = {
                "module_roots": attr.label_list(
                    doc = "Set of cue_module targets for which to cache CUE modules on which they depend.",
                    providers = [CUEModuleInfo],
                ),
            },
            doc = "TODO(seh)",
        ),
    },
)
