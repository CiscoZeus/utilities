#!/bin/bash
# You need to define the following variables on codeship env variables before running this script
# Use $VERSION_NUMBER to specify a version in a filename/path
# Version must be specified in package.json file
#
# GITHUB_API_TOKEN="token for the zeusuibot"
# REPO_NAME="name of the repo"
# BUILD_COMMAND="commands to build file, separate commands by;"
# BUILD_FILE="name of the file generate by the build command"
# BUILD_PATH="path to the build file, can be left empty if its a root"

check_for_env_vars() {
    if [ -z ${!1} ]; then
        echo "Please specify $1 in the env vars"
        exit 1
    fi
}

check_for_env_vars "GITHUB_API_TOKEN"
check_for_env_vars "REPO_NAME"
check_for_env_vars "BUILD_COMMAND"
check_for_env_vars "BUILD_FILE"

REPO_CHECK="$(curl --write-out %{http_code} --silent --output /dev/null -u zeusuibot:$GITHUB_API_TOKEN https://api.github.com/repos/CiscoZeus/$REPO_NAME)"

if [ "$REPO_CHECK" = "404" ]; then
    echo "Repository $REPO_NAME doesn't exist under CiscoZeus or zeusuibot has no access to it"
    exit 1
else
    echo "Repository $REPO_NAME found, proceeding with release"
fi

GITHUB_RELEASE_API="https://api.github.com/repos/CiscoZeus/$REPO_NAME/releases"

eval $BUILD_COMMAND > /dev/null

VERSION_NUMBER="$(cat package.json | python -c "import sys, json; print json.load(sys.stdin)['version']")"

upload_release_file() {
    echo "Uploading release file..."
    curl -X POST -u zeusuibot:$GITHUB_API_TOKEN --header "Content-Type:application/zip" \
         --data-binary @$BUILD_PATH$BUILD_FILE \
         "https://uploads.github.com/repos/CiscoZeus/$REPO_NAME/releases/${RELEASE_ID}/assets?name=${BUILD_FILE}"
    echo $'\nDone'
}

echo "Checking if release if same version already exists..."
RELEASE_ID="$(curl -s -u zeusuibot:$GITHUB_API_TOKEN  --request GET $GITHUB_RELEASE_API/tags/$VERSION_NUMBER | python -c "import sys, json; print json.load(sys.stdin)['id']" 2>/dev/null || true)"

if [ -n "$RELEASE_ID" ]; then
    echo "Found release with same version number, looking for release file..."
    ASSET_ID="$(curl -s -u zeusuibot:$GITHUB_API_TOKEN  --request GET $GITHUB_RELEASE_API/$RELEASE_ID/assets | python -c "import sys, json;releases = json.load(sys.stdin); print [x for x in releases if x['name'] == '$BUILD_FILE'][0]['id']" 2>/dev/null || true)"
    if [ -n "$ASSET_ID" ]; then
        echo "Found release file, deleting it"
        curl --request DELETE -u zeusuibot:$GITHUB_API_TOKEN $GITHUB_RELEASE_API/assets/$ASSET_ID
        echo "Old release deleted"
        upload_release_file
    else
        echo "Release file not found, will just upload new one"
        upload_release_file
    fi
else
    echo "Release for $VERSION_NUMBER not found, creating a new one"
    RELEASE_ID="$(curl -u zeusuibot:$GITHUB_API_TOKEN  --request POST --data "{\"tag_name\":\"${VERSION_NUMBER}\",\"target_commitish\":\"master\",\"name\":\"${VERSION_NUMBER}\",\"body\":\"Release for version ${VERSION_NUMBER}\",\"draft\":false,\"prerelease\":false}" $GITHUB_RELEASE_API | python -c "import sys, json; print json.load(sys.stdin)['id']")"

    upload_release_file
fi