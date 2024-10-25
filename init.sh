#!/bin/bash

# Variables
REPO_URL="https://github.com/Quanta-Tools/Quanta.git"
PLIST_NAME="Quanta.plist"
PLIST_PATH="./$PLIST_NAME"
PBXPROJ_PATH=""
BACKUP_PATH=""

# Check and install dependencies
check_dependencies() {
  # Check if Homebrew is installed
  if ! command -v brew >/dev/null 2>&1; then
    echo "Installing Homebrew..."
    /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

    # Add Homebrew to PATH for the current session
    eval "$(/opt/homebrew/bin/brew shellenv)"
  fi

  # Check if jq is installed
  if ! command -v jq >/dev/null 2>&1; then
    echo "Installing jq..."
    brew install jq
  fi

  # Check if plutil is available (should be pre-installed on macOS)
  if ! command -v plutil >/dev/null 2>&1; then
    echo "Error: plutil not found. This script requires macOS."
    exit 1
  fi

  echo "All dependencies are installed."
}

# Helper function to generate 24-character hex UUID (Xcode style)
generate_uuid() {
  uuidgen
}

# Convert binary plist to JSON for easier manipulation
convert_to_json() {
  local temp_json="/tmp/project.json"
  plutil -convert json -o "$temp_json" "$PBXPROJ_PATH"
  echo "$temp_json"
}

# Convert JSON back to binary plist
convert_to_plist() {
  local json_path="$1"
  plutil -convert binary1 -o "$PBXPROJ_PATH" "$json_path"
}

# Backup the project file
backup_project() {
  BACKUP_PATH="${PBXPROJ_PATH}.backup"
  cp "$PBXPROJ_PATH" "$BACKUP_PATH"
  echo "Created backup at $BACKUP_PATH"
}

# Restore from backup if something goes wrong
restore_backup() {
  if [ -f "$BACKUP_PATH" ]; then
    cp "$BACKUP_PATH" "$PBXPROJ_PATH"
    echo "Restored from backup"
    rm "$BACKUP_PATH"
  fi
}

# Find the main group UUID
find_main_group() {
  local json_path="$1"
  local main_group_uuid=$(jq -r '.rootObject as $root | .objects[$root].mainGroup' "$json_path")
  echo "$main_group_uuid"
}

# Find all target UUIDs
find_target_uuids() {
  local json_path="$1"
  jq -r '.rootObject as $root | .objects[$root].targets[]' "$json_path"
}

# Find resource build phase UUID for a target
find_resource_phase() {
  local json_path="$1"
  local target_uuid="$2"
  jq -r --arg target "$target_uuid" '
        .objects[$target].buildPhases[] as $phase
        | select(.objects[$phase].isa == "PBXResourcesBuildPhase")
        | $phase
    ' "$json_path"
}

# Add file reference to project
add_file_reference() {
  local json_path="$1"
  local file_uuid=$(generate_uuid)

  # Create file reference entry
  local file_ref='{
        "isa": "PBXFileReference",
        "lastKnownFileType": "text.plist",
        "path": "'"$PLIST_NAME"'",
        "sourceTree": "<group>"
    }'

  # Add to objects dictionary
  jq --arg uuid "$file_uuid" --argjson ref "$file_ref" '.objects[$uuid] = $ref' "$json_path" >"${json_path}.tmp"
  mv "${json_path}.tmp" "$json_path"

  echo "$file_uuid"
}

# Add file to main group
add_to_main_group() {
  local json_path="$1"
  local main_group_uuid="$2"
  local file_uuid="$3"

  # Add file UUID to group's children array
  jq --arg group "$main_group_uuid" --arg file "$file_uuid" '
        .objects[$group].children += [$file]
    ' "$json_path" >"${json_path}.tmp"
  mv "${json_path}.tmp" "$json_path"
}

# Create build file entry for a target
create_build_file() {
  local json_path="$1"
  local file_uuid="$2"
  local build_file_uuid=$(generate_uuid)

  # Create build file entry
  local build_file='{
        "isa": "PBXBuildFile",
        "fileRef": "'"$file_uuid"'"
    }'

  # Add to objects dictionary
  jq --arg uuid "$build_file_uuid" --argjson ref "$build_file" '.objects[$uuid] = $ref' "$json_path" >"${json_path}.tmp"
  mv "${json_path}.tmp" "$json_path"

  echo "$build_file_uuid"
}

# Add build file to target's resource phase
add_to_resource_phase() {
  local json_path="$1"
  local phase_uuid="$2"
  local build_file_uuid="$3"

  # Add build file UUID to phase's files array
  jq --arg phase "$phase_uuid" --arg file "$build_file_uuid" '
        .objects[$phase].files += [$file]
    ' "$json_path" >"${json_path}.tmp"
  mv "${json_path}.tmp" "$json_path"
}

# Step 1: Find the .xcodeproj file in the current directory
find_xcodeproj() {
  local xcodeproj_count=$(find . -maxdepth 1 -name "*.xcodeproj" | wc -l)

  if [ "$xcodeproj_count" -eq 0 ]; then
    echo "No .xcodeproj file found in the current directory."
    exit 1
  elif [ "$xcodeproj_count" -gt 1 ]; then
    echo "Multiple .xcodeproj files found. Please make sure there's only one."
    exit 1
  else
    PROJECT_PATH=$(find . -maxdepth 1 -name "*.xcodeproj" | head -n 1)
    PBXPROJ_PATH="$PROJECT_PATH/project.pbxproj"
    echo "Found Xcode project: $PROJECT_PATH"
  fi
}

# Step 2: Generate the Quanta.plist file with a random UUID
generate_plist_file() {
  if [ -f "$PLIST_PATH" ]; then
    echo "$PLIST_NAME already exists."
  else
    echo "Creating $PLIST_NAME"
    UUID=$(uuidgen)
    cat <<EOF >"$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>AppId</key>
    <string>$UUID</string>
</dict>
</plist>
EOF
    echo "$PLIST_NAME created with UUID: $UUID"
  fi
}

# Step 3: Add Quanta.plist to the Xcode project
add_plist_to_project() {
  echo "Adding $PLIST_NAME to Xcode project"

  # Create JSON representation
  local json_path=$(convert_to_json)

  # Find required UUIDs
  local main_group_uuid=$(find_main_group "$json_path")

  # Add file reference
  local file_uuid=$(add_file_reference "$json_path")

  # Add to main group
  add_to_main_group "$json_path" "$main_group_uuid" "$file_uuid"

  # Process each target
  while read -r target_uuid; do
    local phase_uuid=$(find_resource_phase "$json_path" "$target_uuid")
    local build_file_uuid=$(create_build_file "$json_path" "$file_uuid")
    add_to_resource_phase "$json_path" "$phase_uuid" "$build_file_uuid"
  done < <(find_target_uuids "$json_path")

  # Convert back to binary plist
  convert_to_plist "$json_path"
  rm "$json_path"
}

# Add Swift package dependency to project
add_package_dependency() {
  echo "Adding Swift package dependency from $REPO_URL"

  local json_path=$(convert_to_json)
  local package_uuid=$(generate_uuid)
  local version_uuid=$(generate_uuid)

  # Create package reference entry
  local package_ref='{
        "isa": "XCRemoteSwiftPackageReference",
        "repositoryURL": "'"$REPO_URL"'",
        "requirement": {
            "kind": "upToNextMajorVersion",
            "minimumVersion": "1.0.0"
        }
    }'

  # Add package reference to objects
  jq --arg uuid "$package_uuid" --argjson ref "$package_ref" '
        .objects[$uuid] = $ref
    ' "$json_path" >"${json_path}.tmp"
  mv "${json_path}.tmp" "$json_path"

  # Add package reference to package references array in root object
  jq --arg uuid "$package_uuid" '
        .rootObject as $root 
        | if .objects[$root].packageReferences == null then
            .objects[$root].packageReferences = [$uuid]
          else
            .objects[$root].packageReferences += [$uuid]
          end
    ' "$json_path" >"${json_path}.tmp"
  mv "${json_path}.tmp" "$json_path"

  # For each target, add package product dependency
  while read -r target_uuid; do
    local product_uuid=$(generate_uuid)

    # Create package product dependency entry
    local product_ref='{
            "isa": "XCSwiftPackageProductDependency",
            "package": "'"$package_uuid"'",
            "productName": "'"${REPO_URL##*/}"'"
        }'

    # Add product reference to objects
    jq --arg uuid "$product_uuid" --argjson ref "$product_ref" '
            .objects[$uuid] = $ref
        ' "$json_path" >"${json_path}.tmp"
    mv "${json_path}.tmp" "$json_path"

    # Add product reference to target dependencies
    jq --arg target "$target_uuid" --arg product "$product_uuid" '
            .objects[$target].packageProductDependencies += [$product]
        ' "$json_path" >"${json_path}.tmp"
    mv "${json_path}.tmp" "$json_path"

    echo "Added package dependency to target $target_uuid"
  done < <(find_target_uuids "$json_path")

  # Convert back to binary plist
  convert_to_plist "$json_path"
  rm "$json_path"
}

# Check if Xcode is running
check_xcode_running() {
  if pgrep -x "Xcode" >/dev/null; then
    echo "⚠️  WARNING: Xcode is currently running! (see pgrep -x Xcode)"
    echo "Please close Xcode and run this script again."
    echo "Do you want to continue anyway and potentially corrupt your project?"
    read -p "Continue (y/N): " response

    # Convert response to lowercase
    response=$(echo "$response" | tr '[:upper:]' '[:lower:]')

    # Check if response is not "y" or "yes"
    if [[ "$response" != "y" && "$response" != "yes" ]]; then
      echo "Aborting script execution."
      exit 1
    fi

    echo "Continuing"
  fi
}

# Main execution
set -e # Exit on any error

# Check if Xcode is running first
check_xcode_running

# Check for root permissions if needed for Homebrew installation
if [ "$EUID" -ne 0 ] && ! command -v brew >/dev/null 2>&1; then
  echo "This script needs to install Homebrew, which requires sudo access."
  sudo -v
fi

# Execute steps
echo "Checking and installing dependencies..."
check_dependencies

echo "Starting Xcode project modification..."
find_xcodeproj
backup_project

# Try to perform modifications
if generate_plist_file && add_plist_to_project && add_package_dependency; then
  echo "Setup complete! If swift package manager is causing build errors, try opening Xcode, and running"
  echo " File > Packages > Reset Package Caches."
  rm "$BACKUP_PATH"
else
  echo "An error occurred. Rolling back changes..."
  restore_backup
  exit 1
fi
