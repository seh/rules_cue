CUEModuleInfo = provider(
    doc = "Collects files from cue_module targets for use by referring cue_instance targets.",
    fields = {
        "module_file": """The "module.cue" file in the module directory.""",
        # TODO(seh): Consider abandoning this field in favor of using cue_instance for these.
        "external_package_sources": "The set of files in this CUE module defining external packages.",
    },
)

CUEInstanceInfo = provider(
    doc = "Collects files and references from cue_instance targets for use in downstream consuming targets.",
    fields = {
        "directory_path": """Directory path (a "short path") to the CUE instance.""",
        "files": "The CUE files defining this instance.",
        "module": "The CUE module within which this instance sits.",
        "package_name": "Name of the CUE package to load for this instance.",
        "transitive_files": "The set of files (including other instances) referenced by this instance.",
    },
)
