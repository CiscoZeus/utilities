#!/bin/bash
# You need to define the following variables on codeship env variables before running this script
# Use $VERSION_NUMBER to specify a version in a filename/path
# Version must be specified in package.json file
#
# GITHUB_API_TOKEN="token for the zeusuibot"
# REPO_NAME="name of the repo"
# BUILD_COMMAND="commands to build file, separate commands by; BUILD_FILE will be replaced with the actual name"
# BUILD_PATH="path to the build file, can be left empty if its a root"
# Build file will be: $BUILD_FILE_PREFIX-$VERSION_NUMBER-$BUILD_FILE_SUFIX.$BUILD_FILE_EXTENSION
# BUILD_FILE_PREFIX="kibana"
# BUILD_FILE_SUFIX="x64"
# BUILD_FILE_EXTENSION="tar.gz"


check_for_env_vars() {
    if [ -z ${!1} ]; then
        echo "Please specify $1 in the env vars"
        exit 1
    fi
}

check_for_env_vars "GITHUB_API_TOKEN"
check_for_env_vars "REPO_NAME"
check_for_env_vars "BUILD_COMMAND"
check_for_env_vars "BUILD_FILE_PREFIX"
check_for_env_vars "BUILD_FILE_EXTENSION"

REPO_CHECK="$(curl --write-out %{http_code} --silent --output /dev/null -u zeusuibot:$GITHUB_API_TOKEN https://api.github.com/repos/CiscoZeus/$REPO_NAME)"

if [ "$REPO_CHECK" = "404" ]; then
    echo "Repository $REPO_NAME doesn't exist under CiscoZeus or zeusuibot has no access to it"
    exit 1
else
    echo "Repository $REPO_NAME found, proceeding with release"
fi

VERSION_NUMBER="$(cat package.json | python -c "import sys, json; print json.load(sys.stdin)['version']")"

if [ -n $BUILD_FILE_SUFIX ]; then
    BUILD_FILE=$BUILD_FILE_PREFIX-$VERSION_NUMBER-$BUILD_FILE_SUFIX.$BUILD_FILE_EXTENSION
else
    BUILD_FILE=$BUILD_FILE_PREFIX-$VERSION_NUMBER.$BUILD_FILE_EXTENSION
fi

GITHUB_RELEASE_API="https://api.github.com/repos/CiscoZeus/$REPO_NAME/releases"

echo "Running build commands"
BUILD_COMMAND="$(echo $BUILD_COMMAND | sed -e s/BUILD_FILE/$BUILD_FILE/g )"
eval $BUILD_COMMAND > /dev/null

echo "Checking for existance of release file on:"
echo "$BUILD_PATH$BUILD_FILE"
if [ -f "$BUILD_PATH$BUILD_FILE" ]; then
    echo "Release file found, proceeding with release"
else
    echo "Release file not found, aborting"
    exit 1
fi

upload_release_file() {
    echo "Uploading release file..."
    UPLOAD_CODE="$(curl -X POST --write-out %{http_code} --silent --output /dev/null -u zeusuibot:$GITHUB_API_TOKEN --header "Content-Type:application/zip" \
         --data-binary @$BUILD_PATH$BUILD_FILE \
         "https://uploads.github.com/repos/CiscoZeus/$REPO_NAME/releases/${RELEASE_ID}/assets?name=${BUILD_FILE}")"
    if [ "$UPLOAD_CODE" = "201" ]; then
        echo $'\nDone'
    else
        echo "Failed to upload file. Return code was: $UPLOAD_CODE"
        exit 1
    fi
}

echo "Checking if release with same version already exists..."
RELEASE_ID="$(curl -s -u zeusuibot:$GITHUB_API_TOKEN  --request GET $GITHUB_RELEASE_API/tags/$VERSION_NUMBER | python -c "import sys, json; print json.load(sys.stdin)['id']" 2>/dev/null || true)"

if [ -n "$RELEASE_ID" ]; then
    echo "Found release with same version number, looking for release file..."
    ASSET_ID="$(curl -s -u zeusuibot:$GITHUB_API_TOKEN  --request GET $GITHUB_RELEASE_API/$RELEASE_ID/assets | python -c "import sys, json;releases = json.load(sys.stdin); print [x for x in releases if x['name'] == '$BUILD_FILE'][0]['id']" 2>/dev/null || true)"
    if [ -n "$ASSET_ID" ]; then
        echo "Found release file, deleting it"
        curl --request DELETE -u zeusuibot:$GITHUB_API_TOKEN $GITHUB_RELEASE_API/assets/$ASSET_ID
        echo "Old release file deleted"
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
