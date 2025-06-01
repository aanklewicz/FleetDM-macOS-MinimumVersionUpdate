#!/bin/zsh --no-rcs

## ====================================================================================================
## Created 2025 05 06
## By Adam Anklewicz for Thumbtack Inc. endpoint team
## aanklewicz@thumbtack.com
## ====================================================================================================

# How many days before the users are required to update to the latest version.
majorReleaseDelay=90
minorReleaseDelay=14

# Location of Fleet YML config file
ymlConfigFile="./teams/workstations.yml"

# Location of YQ
yq=$(which yq)

# Initialize $jsonFeed as a blank string
# If you are using your own instance of SOFA, please put the URL in this variable. Otherwise, it will default to the generic SOFA feed.
macOSJsonFeed=""

## ====================================================================================================

# Check if $macOSJsonFeed is blank
if [[ -z "${macOSJsonFeed}" ]]; then
    # If blank, set it to the fallback URL
    macOSJsonFeed="https://sofafeed.macadmins.io/v1/macos_data_feed.json"
fi

# Error check
echo "Using the SOFA feed ${macOSJsonFeed}"

# Download the data from SOFA
jsonData=$(curl -s ${macOSJsonFeed})

# Extract the latest ProductVersion and ReleaseDate using jq and the yml using yq
latestProductVersion=$(echo "$jsonData" | jq -r '.OSVersions[0].Latest.ProductVersion')
releaseDate=$(echo "$jsonData" | jq -r '.OSVersions[0].Latest.ReleaseDate')
releaseDate=$(echo "$releaseDate" | sed 's/T.*//')
macosUpdatesDeadline=$(${yq} .controls.macos_updates.deadline <${ymlConfigFile})
macosUpdatesVersion=$(${yq} .controls.macos_updates.minimum_version <${ymlConfigFile})

# Print the extracted values
echo "Latest macOS Version: $latestProductVersion"
echo "Release Date: $releaseDate"
echo "Current version in Fleet: $macosUpdatesVersion"
echo "Current deadline in Fleet: $macosUpdatesDeadline"

if [[ $latestProductVersion == $macosUpdatesVersion ]]; then
    echo "Versions match, nothing to change, exiting."
    exit 0
else

    # Extract the latest product version and get the major version number
    latest_version=$(echo "$jsonData" | jq -r '.OSVersions[0].Latest.ProductVersion')
    major_version=$(echo "$latest_version" | cut -d'.' -f1)

    echo "Latest Version: $latest_version"
    echo "Major Version: $major_version"

    # Find the earliest release date for the major version
    earliest_release_date=$(echo "$jsonData" | jq -r --arg mv "$major_version" '.OSVersions[0].SecurityReleases[] | select(.ProductVersion | startswith($mv)) | .ReleaseDate' | sort | head -n 1)

    echo "Earliest Release Date for Major Version $major_version: $earliest_release_date"

    # Function to calculate date difference in days (GNU date)
    date_difference() {
        local start_date="$1" # YYYY-MM-DD
        local end_date="$2"   # YYYY-MM-DD

        local start_seconds=$(date -j -f "%Y-%m-%d" "$start_date" "+%s")
        local end_seconds=$(date -j -f "%Y-%m-%d" "$end_date" "+%s")

        local diff_seconds=$((end_seconds - start_seconds))
        local diff_days=$((diff_seconds / 86400))

        echo "$diff_days"
    }

    # Get today's date in YYYY-MM-DD format (GNU date)
    today=$(date "+%Y-%m-%d")

    # Calculate the difference in days
    days_ago=$(date_difference "$earliest_release_date" "$today")

    # Check if the release was more than majorReleaseDelay days ago
    if (($days_ago > $majorReleaseDelay)); then
        release="minor"
    else
        release="major"
    fi

    echo "Release Type: $release"

    # If it's a minor update, set the new due date. to release date + $minorReleaseDelay
    if [[ $release = "minor" ]]; then
        newDueDate=$(date -j -v+${minorReleaseDelay}d -f "%Y-%m-%d" "$releaseDate" "+%Y-%m-%d")
        echo "New due date: $newDueDate"
    elif [[ $release = "major" ]]; then
        newDueDate=$(date -j -v+${majorReleaseDelay}d -f "%Y-%m-%d" "$releaseDate" "+%Y-%m-%d")
        echo "New due date: $newDueDate"
    else
        echo "ERROR: Is neither a major nor a minor release. Exiting."
        exit 1
    fi

    # Update values
    yq -i ".controls.macos_updates.deadline = \"${newDueDate}\"" ${ymlConfigFile}
    yq -i ".controls.macos_updates.minimum_version = \"${latestProductVersion}\"" ${ymlConfigFile}

fi

exit 0
