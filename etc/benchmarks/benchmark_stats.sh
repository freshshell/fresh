#!/bin/bash -e

if [ -e stats.csv ]; then
  rm stats.csv
fi

run-command-on-git-revisions -v $1 $2 "sh etc/benchmarks/stats_on_this_rev.sh >> stats.csv"
