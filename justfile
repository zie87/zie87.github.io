# vim: set ft=make :
root_dir := justfile_directory()

#target := "atmega328p"
#buildtype := "debug"

default:
	@just --list

_run-in-guix-shell cmd *args:
	#!/usr/bin/env -S sh -eu
	guix shell -m manifest.scm -- just {{ cmd }} {{ args }}

_start-jekyll:
	bundle exec jekyll s

_start-jekyll-draft:
	bundle exec jekyll s --draft

# start jekyll server (normal mode)
start: (_run-in-guix-shell "_start-jekyll")

# start jekyll server (draft mode)
start_draft: (_run-in-guix-shell "_start-jekyll-draft")
