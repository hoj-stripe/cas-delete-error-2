#!/usr/bin/env bash

platform="$(uname -s | tr '[:upper:]' '[:lower:]')"
arch="$(uname -m | tr '[:upper:]' '[:lower:]')"

export BAZEL_REMOTE_SHA_darwin_x86_64="555ae6076bf0d76516ecc5b7b1b64310642b6268b30601bccaa686bda89bb93c"
export BAZEL_REMOTE_SHA_darwin_arm64="7ceb05ff3014c8517fd4eb38ba18763fb20b0aa5400ec72f2f4b0b7dc1a9b73c"
export BAZEL_REMOTE_SHA_linux_x86_64="5e4b248262a56e389e9ee4212ffd0498746347fb5bf155785c9410ba2abc7b07"
export BAZEL_REMOTE_SHA_linux_arm64=""

VERSION="2.4.1"
url="https://github.com/buchgr/bazel-remote/releases/download/v${VERSION}/bazel-remote-${VERSION}-${platform}-${arch}"

mkdir -p .cache

BAZEL_REMOTE=".cache/bazel-remote"
if [[ -f "$BAZEL_REMOTE" ]]; then
    sha256=$(shasum -a256 "$BAZEL_REMOTE" | cut -d' ' -f1)
    expected_name="BAZEL_REMOTE_SHA_${platform}_${arch}"
    if [[ "$sha256" != "${!expected_name}" ]]; then
        echo "SHA mismatch on ${BAZEL_REMOTE}! removing it: expected ${!expected_name} but got $sha256"
        rm "$BAZEL_REMOTE"
    fi
fi

if [[ ! -f "$BAZEL_REMOTE" ]]; then
    wget "$url" -O "$BAZEL_REMOTE"
    chmod +x "$BAZEL_REMOTE"
fi

sha256=$(shasum -a256 "$BAZEL_REMOTE" | cut -d' ' -f1)
expected_name="BAZEL_REMOTE_SHA_${platform}_${arch}"
if [[ "$sha256" != "${!expected_name}" ]]; then
    echo "SHA mismatch on ${BAZEL_REMOTE}! expected ${!expected_name} but got $sha256"
    exit 1
fi

CACHE_DIR=$(mktemp -d)

$BAZEL_REMOTE --dir "$CACHE_DIR" --max_size 1 &
BAZEL_REMOTE_PID=$!

function cleanup {
    kill $BAZEL_REMOTE_PID
    if [[ -d "$CACHE_DIR" ]]; then
        echo "Run rm -rf \"$CACHE_DIR\" to clean up"
    fi
}

sleep 1

trap cleanup EXIT

bazel clean --expunge
bazel build //:file_1kb --remote_cache=grpc://localhost:9092
bazel_exit=$?
echo "Bazel exited with ${bazel_exit}"

echo -n "Does the expected output exist? ... "
if [[ -e bazel-bin/file_1kb ]]; then
    echo "Yes! ✅"
    rm -f bazel-bin/file_1kb
else
    echo "No! ❌"
fi

printf "\n\n"
echo "Removing the CAS object for file_1kb..."
find "$CACHE_DIR/cas.v2/5f/" -name '5f70bf18a086007016e948b04aed3b82103a36bea41755b6cddfaf10ace3c6ef-1024*' -print -delete

# Rerun to trigger the silent failure (Fixed with Bazel 7)
printf "\n\n"

bazel build //:file_1kb --remote_cache=grpc://localhost:9092
bazel_exit=$?
echo "Bazel exited with ${bazel_exit}"

echo -n "Does the expected output exist? ... "
if [[ -e bazel-bin/file_1kb ]]; then
    echo "Yes! ✅"
    rm -f bazel-bin/file_1kb
else
    echo "No! ❌"
fi
printf "\n\n"
echo "Removing the CAS object for file_1kb..."
find "$CACHE_DIR/cas.v2/5f/" -name '5f70bf18a086007016e948b04aed3b82103a36bea41755b6cddfaf10ace3c6ef-1024*' -print -delete

# Rerun to trigger the obvious failure
printf "\n\n"

bazel build //:copy_file_1kb --remote_cache=grpc://localhost:9092
bazel_exit=$?
echo "Bazel exited with ${bazel_exit}"

echo -n "Does the expected output exist? ... "
if [[ -e bazel-bin/copied_file_1kb ]]; then
    echo "Yes! ✅"
    rm -f bazel-bin/copied_file_1kb
else
    echo "No! ❌"
fi
printf "\n\n"
