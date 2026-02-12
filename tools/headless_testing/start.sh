#!/bin/bash

mkdir -p "$1/demos"
mkdir -p "$1/testlog"
rm -rf "$1/LuaUI/Config"
$1/engine/*/spring-headless --isolation --write-dir "$1" "$2"
echo "--- Contents of /bar/demos: ---"
ls -la "$1/demos"
echo "--- Contents of /bar/testlog: ---"
ls -la "$1/testlog"
echo "--- Contents of /bar/cache: ---"
ls -la "$1/cache"
echo "--- Contents of /bar: ---"
ls -la "$1"