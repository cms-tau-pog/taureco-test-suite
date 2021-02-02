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
```
ts_active_project : print the name of the project you are currently working on
ts_project_data : print the meta data of your project like remote, branch, CMSSW packages...
ts_delete : remove the current project
```

## Manage builds and packages


## Testing


## Grid proxy
The test suite will automatically check your grid proxy when necessary, but you may want to use one of the following commands before directly launching CMSSW.
```
ts_check_proxy : check availability of a valid proxy and create a new one if necessary
ts_new_proxy : create a new proxy right away (e.g. if you consider the remaining life time of an existing proxy too short)
```
