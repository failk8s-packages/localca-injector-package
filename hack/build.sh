#!/usr/bin/env bash

set -eo pipefail

SOURCE="${BASH_SOURCE[0]}"
while [ -h "$SOURCE" ]; do # resolve $SOURCE until the file is no longer a symlink
  BASE_DIR="$( cd -P "$( dirname "$SOURCE" )" && pwd )"
  SOURCE="$(readlink "$SOURCE")"
  [[ $SOURCE != /* ]] && SOURCE="$DIR/$SOURCE" # if $SOURCE was a relative symlink, we need to resolve it relative to the path where the symlink file was located
done
BASE_DIR="$( cd -P "$( dirname "$SOURCE" )/.." && pwd )"

CONFIG_FILE=${CONFIG_FILE:-"$BASE_DIR/config.json"}

_registry=$(cat $CONFIG_FILE | jq -r '.registry')
_name=$(cat $CONFIG_FILE | jq -r '.package.name')
_version=$(cat $CONFIG_FILE | jq -r '.package.version')


function build {
    # Create bundle in target with processed files
    rm -rf $BASE_DIR/target && mkdir $BASE_DIR/target

    echo "Creating bundle files:"
    cp -R $BASE_DIR/src/bundle $BASE_DIR/target/bundle
    mkdir -p $BASE_DIR/target/bundle/config/upstream
    ytt --data-values-file $CONFIG_FILE -f $BASE_DIR/src/templates/package/bundle/upstream.yaml --output-files $BASE_DIR/target/bundle/config/upstream --ignore-unknown-comments
    ytt --data-values-file $CONFIG_FILE -f $BASE_DIR/src/templates/package/bundle/images.yml --output-files $BASE_DIR/target/bundle --ignore-unknown-comments
    ytt --data-values-file $CONFIG_FILE -f $BASE_DIR/src/templates/package/bundle/bundle.yaml --output-files $BASE_DIR/target/bundle/.imgpkg --ignore-unknown-comments

    # Create imgpkgBundle
    echo "Updating package: $_name:$_version"
    ytt --data-values-file $BASE_DIR/src/example-values/minikube.yaml -f $BASE_DIR/target/bundle | kbld -f - --imgpkg-lock-output $BASE_DIR/target/bundle/.imgpkg/images.yml
    imgpkg push --bundle $_registry/$_name-package:$_version --file $BASE_DIR/target/bundle

    # Create manifests
    rm -rf $BASE_DIR/target/k8s && rm -rf $BASE_DIR/target/test && mkdir -p $BASE_DIR/target/k8s && mkdir -p $BASE_DIR/target/test 
    echo "Creating manifest files:"
    ytt --data-values-file $CONFIG_FILE -f $BASE_DIR/src/templates/package/k8s --output-files $BASE_DIR/target/k8s --ignore-unknown-comments
    ytt --data-values-file $CONFIG_FILE -f $BASE_DIR/src/templates/package/test --output-files $BASE_DIR/target/test --ignore-unknown-comments
    if [[ "$_version" != "develop" ]]; then
      kbld -f $BASE_DIR/target/k8s/package.yaml | sponge $BASE_DIR/target/k8s/package.yaml
    fi

    echo "============"
    echo "Now you can test your package"
    echo ""
    echo "deploy your package:"
    echo "      kubectl apply -f $BASE_DIR/target/k8s"
    echo "test your package:"
    echo "      kubectl apply -f $BASE_DIR/target/test"
    echo "Watch progress"
    echo "      watch kubectl get packageinstall $_name-package -n $_name-package"
}

build