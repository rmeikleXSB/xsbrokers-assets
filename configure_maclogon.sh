#!/bin/bash

# Usage: configure_maclogon.sh /path/to/maclogon-x.x.pkg

# NOTE: The path to the MacLogon package is optional.
# This script will look for a package to configure
# in the current working directory if not provided.

version="2.0.5"

echo "Duo Security Mac Logon configuration tool v${version}."
echo "See https://duo.com/docs/macos for documentation"

read_bool() {
    local bool_val
    read -r bool_val
    while ! [[ "$bool_val" == "true" || "$bool_val" == "false" ]]; do
        read -rp "Invalid value. Enter true or false: " bool_val
    done
    echo "$bool_val"
}

read_bool_default_false() {
    local bool_val
    read -r bool_val
    while ! [[ -z "$bool_val" ]] && ! [[ "$bool_val" == "true" || "$bool_val" == "false" ]]; do
        read -rp "Invalid value. Enter true or false or leave it empty for false: " bool_val
    done
    # check if fail_open was passed and default it to false, if not passed
    if [[ -z "$bool_val" ]]; then
        echo "false"
    else
        echo "$bool_val"
    fi
}

# if a package was passed in, always use it
if [[ $# -ge 1 ]]; then
    pkg_path=$1
else
    # otherwise try to find the default package in this dir
    pkgs=( $(find . -name 'MacLogon-NotConfigured-*.pkg') )
    num_pkgs=${#pkgs[@]}

    if [[ "$num_pkgs" -eq "1" ]]; then
        pkg_path=${pkgs[0]}
    elif [[ "$num_pkgs" -eq "0" ]]; then
        echo "No packages found. Please provide a package."
        exit 1
    else
        echo "Multiple packages found. Please specify one."
        echo "Usage: configure_maclogon.sh /path/to/MacLogon-NotConfigured-x.x.pkg"
        exit 1
    fi
fi

if [ ! -f "${pkg_path}" ]; then
    echo "No package found at $pkg_path. Exiting."
    exit 1
fi

echo -n "Enter ikey: "
read -r ikey
echo -n "Enter skey: "
read -r skey
echo -n "Enter API Hostname: "
read -r api_hostname

echo -n "Should fail open (true or false) [default: false]: "
fail_open=$(read_bool_default_false)

echo -n "Should bypass 2FA when using smartcard (true or false) [default: false]: "
smartcard_bypass=$(read_bool_default_false)

echo -n "Should auto push if possible (true or false): "
auto_push=$(read_bool)

pkg_dir=$(dirname "${pkg_path}")
pkg_name=$(basename "${pkg_path}" | awk -F\. '{print $1 "." $2}')
tmp_path="/tmp/${pkg_name}"

echo -e "\nModifying ${pkg_path}...\n"

pkgutil --expand "${pkg_path}" "${tmp_path}"

echo -e "Updating config.plist ikey, skey, api_hostname, fail_open, smartcard_bypass, and auto_push config...\n"

defaults write "${tmp_path}"/Scripts/config.plist ikey -string "${ikey}"
defaults write "${tmp_path}"/Scripts/config.plist skey -string "${skey}"
defaults write "${tmp_path}"/Scripts/config.plist api_hostname -string "${api_hostname}"
defaults write "${tmp_path}"/Scripts/config.plist fail_open -bool "${fail_open}"
defaults write "${tmp_path}"/Scripts/config.plist smartcard_bypass -bool "${smartcard_bypass}"
defaults write "${tmp_path}"/Scripts/config.plist auto_push -bool "${auto_push}"
defaults write "${tmp_path}"/Scripts/config.plist twofa_unlock -bool false
plutil -convert xml1 "${tmp_path}/Scripts/config.plist"

out_pkg="${pkg_dir}/MacLogon-${version}.pkg"
echo -e "Finalizing package, saving as ${out_pkg}\n"
pkgutil --flatten "${tmp_path}" "${out_pkg}"

echo -e "Cleaning up temp files...\n"
rm -rf "${tmp_path}"

echo -e "Done! The package ${out_pkg} has been configured for your use."
exit 0
