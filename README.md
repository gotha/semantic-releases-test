# Semantic releases test

## Description

Small utility used to create semantic releases in github based on commit message prefixes

## Install

Clone this repo and run

```sh
./configure.sh
```

to check that all dependencies are present.
You need `git`, [hub](https://github.com/github/hub) and `awk`

Install by putting symlink to the shell script

```sh
ln -s /path/to/repo/rel.sh /usr/local/bin/rel
```

## Use

Go to the repo where you want to create release and execute:

```sh
rel
```

based on the prefixes of the commit messages that you have made a new version will be proposed.

If you have no github releases, version `0.0.1` will be proposed.

A new version will be calculated based on the prefixes of your commit messages:

- `fix -` will bump the patch version
- `feature -` will increase minor version
- `major -` will increment the major version

Tag name and release name will be identical.

## Todo

Currently automatic RC incrment for pre-releases is not implemented
