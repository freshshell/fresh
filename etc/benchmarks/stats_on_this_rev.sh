#!/bin/bash -e

rev="$(git log -1 --pretty='format:%h' HEAD)"
time="$(
  ruby etc/benchmarks/install_benchmark.rb |
  grep '^RUNTIME: ' |
  awk '{print $2}'
)"

echo $rev,$time
