load("@bazel_skylib//lib:paths.bzl", "paths")

HELM_CMD_PREFIX = """
echo "#!/bin/bash" > $@
cat $(location @com_github_tmc_rules_helm//:runfiles_bash) >> $@
echo "export NAMESPACE=$$(grep NAMESPACE bazel-out/stable-status.txt | cut -d ' ' -f 2)" >> $@
echo "export BUILD_USER=$$(grep BUILD_USER bazel-out/stable-status.txt | cut -d ' ' -f 2)" >> $@
cat <<EOF >> $@
#export RUNFILES_LIB_DEBUG=1 # For runfiles debugging

export HELM=\$$(rlocation com_github_tmc_rules_helm/helm)
PATH=\$$(dirname \$$HELM):\$$PATH
"""

def helm_chart(name, srcs, update_deps = False):
    """Defines a helm chart (directory containing a Chart.yaml).

    Args:
        name: A unique name for this rule.
        srcs: Source files to include as the helm chart. Typically this will just be glob(["**"]).
        update_deps: Whether or not to run a helm dependency update prior to packaging.
    """
    filegroup_name = name + "_filegroup"
    helm_cmd_name = name + "_package.sh"
    package_flags = ""
    if update_deps:
        package_flags = "--dependency-update"
    native.filegroup(
        name = filegroup_name,
        srcs = srcs,
    )
    native.genrule(
        name = name,
        #srcs = ["@com_github_tmc_rules_helm//:runfiles_bash", filegroup_name, "@bazel_tools//tools/bash/runfiles"],
        srcs = [filegroup_name],
        outs = ["%s_chart.tar.gz" % name],
        tools = ["@com_github_tmc_rules_helm//:helm"],
        cmd = """
# find Chart.yaml in the filegroup
CHARTLOC=missing
for s in $(SRCS); do
  if [[ $$s =~ .*Chart.yaml ]]; then
    CHARTLOC=$$(dirname $$s)
    break
  fi
done
$(location @com_github_tmc_rules_helm//:helm) package {package_flags} $$CHARTLOC
mv *tgz $@
""".format(
            package_flags = package_flags,
        ),
    )

def _helm_cmd(cmd, args, name, helm_cmd_name, values_yaml):
    native.sh_binary(
        name = name + "." + cmd,
        srcs = [helm_cmd_name],
        deps = ["@bazel_tools//tools/bash/runfiles"],
        data = [values_yaml, "@com_github_tmc_rules_helm//:helm"],
        args = args,
    )

def helm_release(name, release_name, chart, values_yaml, namespace = "", context = ""):
    """Defines a helm release.

    A given target has the following executable targets generated:

    `(target_name).install`
    `(target_name).install.wait`
    `(target_name).status`
    `(target_name).delete`
    `(target_name).test`
    `(target_name).test.noclean`

    Args:
        name: A unique name for this rule.
        release_name: name of the release.
        chart: The chart defined by helm_chart.
        values_yaml: The values.yaml file to supply to the release.
        namespace: The namespace to install the release into. If empty will default the NAMESPACE environment variable and will fall back the the current username (via BUILD_USER).
    """
    helm_cmd_name = name + "_run_helm_cmd.sh"
    native.genrule(
        name = name,
        srcs = ["@com_github_tmc_rules_helm//:runfiles_bash", chart, values_yaml],
        stamp = True,
        outs = [helm_cmd_name],
        cmd = HELM_CMD_PREFIX + """
export CHARTLOC=$(location """ + chart + """)
EXPLICIT_NAMESPACE=""" + namespace + """
EXPLICIT_CONTEXT=""" + context + """
NAMESPACE=\$${EXPLICIT_NAMESPACE:-\$$NAMESPACE}
CONTEXT=\$${EXPLICIT_CONTEXT:-}
export NS=\$${NAMESPACE:-\$${BUILD_USER}}
export CTX=\$${CONTEXT:-$$(kubectl config current-context)}
if [ "\$$1" == "upgrade" ]; then
    helm \$$@ --namespace \$$NS --kube-context \$$CTX """ + release_name + """ \$$CHARTLOC --values=$(location """ + values_yaml + """)
else
    helm \$$@ --namespace \$$NS --kube-context \$$CTX """ + release_name + """
fi

EOF""",
    )
    _helm_cmd("install", ["upgrade", "--install"], name, helm_cmd_name, values_yaml)
    _helm_cmd("install.wait", ["upgrade", "--install", "--wait"], name, helm_cmd_name, values_yaml)
    _helm_cmd("status", ["status"], name, helm_cmd_name, values_yaml)
    _helm_cmd("delete", ["delete"], name, helm_cmd_name, values_yaml)
    _helm_cmd("test", ["test", "run", "--cleanup"], name, helm_cmd_name, values_yaml)
    _helm_cmd("test.noclean", ["test", "run"], name, helm_cmd_name, values_yaml)
