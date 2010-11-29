#!/bin/bash
# Copyright 2009 Backelite
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
# http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

set -e

# Unlock the keychain
SECURITY_FILE="$(dirname $0)/security.pass"
if [ -f "$SECURITY_FILE" ]; then
	security unlock -p "$(cat "$SECURITY_FILE")" #|| { echo "## error: '$SECURITY_FILE': should contain the keychain password (no linefeed at the end) ##" ; exit 1 }
else
	echo "## WARNING: '$SECURITY_FILE': no such file: unable to unlock keychain ##"
fi

# for debug, and after the unlock so the password is not write in the console
# set -x

# "CODE_SIGNING_IDENTITY=$code_signing_identity" "PROVISIONING_PROFILE=$provisioning_id"
params=("-configuration" "$CONFIGURATION" "-sdk" "$SDK")

if [ -n "$TARGET" ]; then
  params[${#params[@]}]="-target"
  params[${#params[@]}]="$TARGET"
fi

# In the Xcode project, you can assign the GCC_PREPROCESSOR_DEFINITIONS and use the $(WEB_SERVICES_CONFIG) variable
if [ -n "$WEB_SERVICES_CONFIG" ]; then
  echo "NOTICE: The value of WEB_SERVICES_CONFIG is $WEB_SERVICES_CONFIG"
  params[${#params[@]}]="WEB_SERVICES_CONFIG=${WEB_SERVICES_CONFIG}"
else
  echo "NOTICE: The env. variable WEB_SERVICES_CONFIG is not set"
fi

echo "## CLEANING OLD BUILDS ##"
rm -rf "build/${CONFIGURATION}-iphoneos"
rm -rf "archives/${TARGET}-${CONFIGURATION}-"*

code_signing="$(find "code-signing/${PROVISIONING}" | grep '\.mobileprovision$')"
declare -i nb_provision="$(env echo "$code_signing" | wc -l)"

if [ "$code_signing" = "" ] || [ "$nb_provision" -eq 0 ]; then
		echo "## WARNING: no provisioning profile found in \"code-signing/${PROVISIONING}\" !##"
fi

env echo "$code_signing" | while read provision_file; do
	(
	echo "## BUILD WITH PROVISION $(basename "${provision_file}") ##"
	# Importing profiles
	provision_name="$(basename "$provision_file" .mobileprovision)"
	provision_id="$(grep -a -A 1 "<key>UUID</key>" "$provision_file" | tail -n1 | sed "s/.*<string>\(.*\)<\/string>.*/\1/")"
	provision_install_path="$HOME/Library/MobileDevice/Provisioning Profiles/$provision_id.mobileprovision"
	if [ "$provision_file" -nt "$provision_install_path" ]; then
		echo "installing '$provision_file' to '$provision_install_path'"
		cp -p "$provision_file" "$provision_install_path"
	fi

	params[${#params[@]}]="PROVISIONING_PROFILE=${provision_id}"

	echo xcodebuild "${params[@]}"
	xcodebuild "${params[@]}"

	# Create archive filename
	archive_name="${TARGET}-${CONFIGURATION}"

	# Append Web service config to archive name
	if [ -n "$WEB_SERVICES_CONFIG" ]; then
		archive_name="${archive_name}-${WEB_SERVICES_CONFIG}_WS"
	fi

	# Preparing archive
	if [ "$nb_provision" -gt 1 ]; then
		archive_name="${archive_name}-${provision_name}"
	fi

	# Finally, append the build ID
	archive_name="${archive_name}-${BUILD_ID}"

	echo "## ARCHIVE ${archive_name} ##"
	mkdir -p "archives/${archive_name}"
	cp "${provision_file}" "archives/${archive_name}"
	cp -R "build/${CONFIGURATION}-iphoneos/"*.app* "archives/${archive_name}"
	( cd archives && ditto -c -k "${archive_name}" "${archive_name}.zip" )
		echo "## ARCHIVE DONE ##"
	)
done

exit


# ===============
# = ENVIRONMENT =
# ===============
# Les variables suivantes sont mises à disposition des scripts shell par hudson
# BUILD_NUMBER      # Le numéro du build courant, par exemple "153"
# BUILD_ID          # L'identifiant du build courant, par exemple "2005-08-22_23-59-59" (YYYY-MM-DD_hh-mm-ss)
# JOB_NAME          # Nom du projet de ce build, par exemple "foo"
# BUILD_TAG         # Le texte "hudson-${JOB_NAME}-${BUILD_NUMBER}", facile à placer dans un fichier de ressource, ou un jar, pour identification future.
# EXECUTOR_NUMBER   # Le numéro unique qui identifie l'exécuteur courant (parmi les exécuteurs d'une même machine) qui a contruit ce build.
                    # Il s'agit du numéro que vous voyez dans le "statut de l'exécuteur du build", sauf que la numérotation commence à 0 et non à 1.
# WORKSPACE         # Le chemin absolu vers le répertoire de travail.
# HUDSON_URL        # L'URL complète de Hudson, au format http://server:port/hudson/
# SVN_REVISION      #
