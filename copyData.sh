#!/bin/bash
# Copies sample data to an exisiting, blank iOS simulator
# Might want to change bundle id below if you're not using the default one
# example usage:
# - Run app on xcode on a simulator called "iPhone 12"
# - Stop app
# - run `./copyData.sh iPhone\ 12`
# - Re-run app in Xcode (repeat if the data does not appear)

BUNDLE_ID="com.marcofiletti.ios.Big-Arrow"

# exit if number of arguments is not 1
if [[ $# != 1 ]]; then
    (>&2 echo "Must pass name of device as argument")
    exit 1
fi
device=$1
cd $(xcrun simctl get_app_container "$device" "$BUNDLE_ID" data) &&
rsync -aI "$OLDPWD/SampleData/" ./
cd "$OLDPWD"
