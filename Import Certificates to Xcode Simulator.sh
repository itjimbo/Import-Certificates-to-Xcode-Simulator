#!/bin/zsh

# This script will import the root certificate into an Xcode simulator device.

#------------------------------------------------------------------------------#

function commandLineToolsNotInstalledPrompt() {
  jamfHelperCommandLineToolsNotInstalledPrompt=`"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" \
  -windowType utility \
  -icon "${jamfHelperErrorIcon}" \
  -title "Xcode - Command Line Tools" \
  -heading "Command Line Tools Not Installed" \
  -alignHeading natural \
  -description "Xcode Command Line Tools is not installed, or it is installed but not up to date. Please reinstall or update Command Line Tools." \
  -lockHUD \
  -button1 "OK"`
}

function simulatorNotFoundPrompt() {
  jamfHelperSimulatorNotFoundPrompt=`"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" \
  -windowType utility \
  -icon "${jamfHelperErrorIcon}" \
  -title "Xcode Simulator Error" \
  -heading "Xcode Simulator Not Found" \
  -alignHeading natural \
  -description "An Xcode simulator is not currently running. Please boot an Xcode simulator and click Try Again. ${NL}${NL}If this error continues to appear after a simulator has been booted, click Exit." \
  -button1 "Try Again" \
  -button2 "Exit" \
  -cancelButton "2"`
}

function certificatesInstalledPrompt() {
  jamfHelperCertificatesInstalledPrompt=`"/Library/Application Support/JAMF/bin/jamfHelper.app/Contents/MacOS/jamfHelper" \
  -windowType utility \
  -icon "${appIcon}" \
  -title "Xcode Certificate Import" \
  -heading "Certificates Installed Successfully" \
  -alignHeading natural \
  -description "The certificates have installed successfully to the following simulator: ${simulatorType}" \
  -lockHUD \
  -button1 "OK"`
}

#------------------------------------------------------------------------------#

function jamfHelperVariables() {
  # Default icon is: /System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns
  jamfHelperErrorIcon="/System/Library/CoreServices/CoreTypes.bundle/Contents/Resources/AlertStopIcon.icns"
  # Creates a new blank line for Jamf Helper.
  appIcon="/Applications/Xcode.app/Contents/Resources/Xcode.icns"
  NL=$'\n'
  deviceInformation
}

#------------------------------------------------------------------------------#

# Checks the device information.
function deviceInformation() {

  echo ""
  echo "`date` - Checking device information..."

  userName=$(defaults read /Library/Preferences/com.apple.loginwindow.plist lastUserName)

  # Obtains the version number of macOS.
  macOSVersion=$(sw_vers -productVersion)

  #Obtains the build of macOS.
  macOSBuild=$(sw_vers -buildVersion)

  # Obtains the processor's achitecture type.
  processorArchitecture=$(uname -m)

  if [[ "${processorArchitecture}" == "x86_64" ]]; then
    processorType="Intel"
  elif [[ "${processorArchitecture}" == "arm64" ]]; then
    processorType="Arm"
  elif [[ "${processorArchitecture}" == "" ]]; then
    echo "`date` - Error at function: deviceInformation"
    echo "`date` - Error details: processor is blank"
    exit 1
  else
    echo "`date` - Error at function: deviceInformation"
    echo "`date` - Error details: Processor type cannot be determined."
    echo "`date` - processorArchitecture: ${processorArchitecture}"
    exit 1
  fi

  # Obtains the amount of disk space available.
  diskSpaceAvailable=$(df -m | awk {'print $4'} | head -n 2 | tail -n 1)

  echo "`date` - macOS version: ${macOSVersion}"
  echo "`date` - macOS build: ${macOSBuild}"
  echo "`date` - Processor type: ${processorType}"
  echo "`date` - Available disk space: ${diskSpaceAvailable} MB"
  echo "`date` - Base path: ${basePath}"
  echo "`date` - Computer name: ${computerName}"
  echo "`date` - User name: ${userName}"

  checkCommandLineToolsInstallation

}

#------------------------------------------------------------------------------#

# Determine if Xcode Command Line Tools is installed.
function checkCommandLineToolsInstallation() {

  # Location for "simctl" tool of Command Line Tools
  simctlLocation="/Applications/Xcode.app/Contents/Developer/usr/bin/simctl"

  if [[ -x "${simctlLocation}" ]]; then
    echo "`date` - Is Command Line Tools installed: Yes"
    checkCertificateLocation
  else
    echo "`date` - Is Command Line Tools installed: No"
    echo "`date` - Notifying user that Command Line Tools is not up to date, or not installed."
    commandLineToolsNotInstalledPrompt
    echo "`date` - Abort mission."
    exit 1
  fi
}

#------------------------------------------------------------------------------#

function checkCertificateLocation() {
  infrastructureCertLocation="DIRECTORY/PATH/TO/CERTIFICATE"
  rootCertLocation="DIRECTORY/PATH/TO/CERTIFICATE"

  if [[ -e "${infrastructureCertLocation}" ]]; then
    echo "`date` - Infrastructure certificate was successfully downloaded to:"
    echo "`date` - ${infrastructureCertLocation}."
  else
    echo "`date` - Infrastructure certificate could not be downloaded from Jamf."
    echo "`date` - Abort mission."
    exit 1
  fi

  if [[ -e "${rootCertLocation}" ]]; then
    echo "`date` - Infrastructure certificate was successfully downloaded to:"
    echo "`date` - ${rootCertLocation}."
  else
    echo "`date` - Root certificate could not be downloaded from Jamf."
    echo "`date` - Abort mission."
    exit 1
  fi

  checkBootedSimulator
}

#------------------------------------------------------------------------------#

function checkBootedSimulator() {
  # This will display which simulators are currently booted.
  findBootedSimulator=$(su -l ${userName} -c "xcrun simctl list | grep 'Booted'")
  echo "`date` - Booted simulators:"
  echo "`date` - ${findBootedSimulator}"
  # This will display the ID of the simulator. Example: F4263449-57SV-4E31-86ER-F33C77218F26
  simulatorID=$(echo ${findBootedSimulator} | head -1 | grep -Eo '[aA0-zZ9]*-[aA0-zZ9]*-[aA0-zZ9]*-[aA0-zZ9]*-[aA0-zZ9]*')
  echo "`date` - Simulator ID:"
  echo "`date` - ${simulatorID}"
  # This will display the type of simulator that is running. Example: iPhone 13 Pro Max
  simulatorType=$(echo ${findBootedSimulator} | head -1 | awk -F '(' '{print $1}' | xargs)
  echo "`date` - Simulator type:"
  echo "`date` - ${simulatorType}"

  if [[ "${simulatorID}" == "" ]]; then
    echo "`date` - An Xcode simulator is not currently booted."
    simulatorNotFoundPrompt

    if [[ "${jamfHelperSimulatorNotFoundPrompt}" == "0" ]]; then
      jamfHelperVariables
    elif [[ "${jamfHelperSimulatorNotFoundPrompt}" == "2" ]]; then
      echo "`date` - User chose to exit."
      echo "`date` - Abort mission."
      exit 1
    fi
  else
    installCertificate
  fi
}

#------------------------------------------------------------------------------#

function installCertificate() {
  echo "`date` - Importing certificate from ${infrastructureCertLocation} to simulator ${simulatorType}"
  # Add infrastructure certificate.
  su -l ${userName} -c "xcrun simctl keychain ${simulatorID} add-cert ${infrastructureCertLocation}"

  echo "`date` - Importing certificate from ${rootCertLocation} to simulator ${simulatorType}"
  # Add root certificate.
  su -l ${userName} -c "xcrun simctl keychain ${simulatorID} add-root-cert ${rootCertLocation}"

  cleanUp
}

#------------------------------------------------------------------------------#

function cleanUp() {
  echo "`date` - Cleaning up files..."
  rm -rf "DIRECTORY/PATH/TO/CERTIFICATE"
  rm -rf "DIRECTORY/PATH/TO/CERTIFICATE"
  missionAccomplished
}

function missionAccomplished() {
  echo "`date` - Mission accomplished!"
  certificatesInstalledPrompt
  exit 0
}

#------------------------------------------------------------------------------#

# Sets new variables based on the Jamf parameters.
basePath="${1}"
computerName="${2}"
jamfHelperVariables
