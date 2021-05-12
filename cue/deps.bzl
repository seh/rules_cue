load(
    "//cue/private:repositories.bzl",
    _cue_rules_dependencies = "cue_rules_dependencies",
)
load(
    "//cue/private:tool.bzl",
    _cue_register_tool = "cue_register_tool",
)

cue_register_tool = _cue_register_tool
cue_rules_dependencies = _cue_rules_dependencies
