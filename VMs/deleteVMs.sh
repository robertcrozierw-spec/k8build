#!/usr/bin/env bash
# Stop and delete all Lima instances

#--format '{{.Name}}' - Lima's list command supports Go's text/template syntax for formatting
# It fills in fields from each instance {{.Name}} means "just output the Name field."
for instance in $(limactl list --format '{{.Name}}'); do
  echo "Removing $instance..."
  limactl stop "$instance" 2>/dev/null # if this command prints an error message, throw it away instead of showing it on screen
  limactl delete "$instance"
done