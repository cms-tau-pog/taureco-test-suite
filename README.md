# taureco-test-suite
Test suite for managing and testing tau-pog developments for cmssw.

## Getting started
In order to create a new project, simply run:
```
source source_me.sh <PROJECT>
```
You will be asked for the CMSSW build to be used (latest nightly build by default), the packages to be added, the remote and branch to work on.
The project is set up in `projects/<PROJECT>`.

In order to resume work on a project from a new session or after working on a different project, simply run the same source command again. You will end up in the CMSSW environment of the project.

The provided user commands are listed after the sourcing. They all begin `ts_` such that they can easily found via auto-completion of your terminal.

## Basic commands
* `ts_active_project` : Print the name of the project you are currently working on.
* `ts_project_data` : Print the meta data of your project like remote, branch, CMSSW packages...
* `ts_delete` : Remove the current project.

## Manage builds, packages, branches, backports
* `ts_checkout_new_cmssw_build` : Sets up another CMSSW build with the same configuration of packages and branches, then copies you local changes. Future test suite operations will run on the new build. The old build is kept. You can delete it by hand as soon as you are sure that everything is working well with the new build. -  This function is particularly useful if you are working with nightly builds that expire after some time.
* `ts_add_package <SUBSYSTEM/PACKAGE>` : Add a new CMSSW package to the project.
* `ts_set_remote <GITHUBREMOTE>` : Set the project remote and fetch it.
* `ts_set_remote <BRANCH>` : Set the project branch. If the branch already exists locally, git checks out this one, otherwise it tries to get it from the project remote.
* `ts_rebase_to_master` : Fetch CMSSW master and rebase current branch to it, which might be necessary for avoiding merge conflicts. The inclusion of recent commits from master may cause compilation failures in your current setup. In this case you can use `ts_checkout_new_cmssw_build` to switch to the latest nightly build.
* `ts_backport` : Creates a new project in order to prepare a backport branch. You will be asked for the CMSSW release that you want to reside on. The backport project is set up with the same other settings as the original projects. A backport branch is created and the commits from the original development are automatically cherry-picked. You might have to resolve merge conflicts by hand.

## Testing
### Mandatory integration tests
The integration tests that are required for any CMSSW code integration can be launched via the following commands. Compilation is run in advance.
* `ts_test_standard_sequence` : Run the full sequence of the following tests.
    * `ts_test_code_checks` : Run scram for checks of code and format rules. Required changes are usually applied automatically but you need to commit them yourself.
    * `ts_test_unit` : Run unit tests.
    * `ts_test_matrix` : Run matrix tests (limited).

### Other tests
Yet to come...

## Grid proxy
The test suite will automatically check your grid proxy when necessary, but you may want to use one of the following commands before directly launching CMSSW.
* `ts_check_proxy` : Check availability of a valid proxy and create a new one if necessary.
* `ts_new_proxy` : Create a new proxy right away (e.g. if you consider the remaining life time of an existing proxy too short).
