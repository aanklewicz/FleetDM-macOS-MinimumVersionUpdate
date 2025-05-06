# Update Minimum DDM version in FleetDM

If you're using FleetDM with GitOps, you might want a method to update the latest version of macOS required for DDM automatically. 

Out of the box, this requires you to update the workstations.yml file to show the new version.

This script and runner will check to see what the latest version of macOS is. It will confirm that your settings are the same in your team config yml file. If not, it will update it, create a pull request for a human to manually approve the change.

## Setup

1. In ./runner-scripts/getCurrentmacOS.zsh, adjust the major and minor release delays to the number of days your organization delays those updates.

2. Update ymlConfigFile variable to point to your desired team config yml file.

3. Update macOSJsonFeed to point to your own instance of SOFA. Mac Admins Open Source suggests spinning up your SOFA instance to not put extra pressure on their instance.

4. Upload the runner-scripts directory and its contents to your GitOps repo

5. Upload the getCurrentmacOS.yml file to ./.github/workflows/getCurrentmacOS.yml