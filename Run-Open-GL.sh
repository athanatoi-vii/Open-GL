#!/bin/bash

# Adrres Directory
dirpath="/"

# Get the name of the C++ file from the user
read -p "Enter the name of the C++ file Or Enter Find To change the search path: " filename

# Check if the string in the variable is in the list
while [[ "$filename" == "find" || "$filename" == "Find" ]]; do
  # Get the directory name from the user
  read -p "Enter the name of the directory: " dirname
  
  # Search for the directory
  dirpath=$(find / -type d -name "$dirname" 2>/dev/null | head -n 1)
  
  # Check if the directory is found or not
  if (( ${#dirpath} == 0 )); then
    echo "Error: Directory not found"
    read -p "Enter the name of the C++ file Or Enter Find To change the search path: " filename
  else
    echo "Directory found: $dirpath"
    dirpath="$dirpath"
    read -p "Enter the name of the C++ file Or Enter Find To change the search path: " filename
  fi
done

# Check if the file has a .cpp extension
if [[ "$filename" != *.cpp ]]; then
  echo "Error: The file must have a .cpp extension."
  exit 1
fi

# Search for the C++ file in the system
filepath=$(find "$dirpath" -name "$filename" 2>/dev/null | head -n 1)

# Check if the file is found or not
if (( ${#filepath} == 0 )); then
  echo "Error: File not found"
  exit 1
fi

# Check Internet
C_Internet=0

check_internet()
{
  if ((C_Internet == 0)); then
    if ! wget -q --spider http://google.com; then
      echo "No Internet connection"
      exit 1
    fi
    C_Internet=1
  fi
}

# Check Update And Upgrade
C_Update=0

# Update And Upgrade
update_and_upgrade()
{
  if ((C_Update == 0)); then
    check_internet
    echo "Updating package lists..."
    sudo apt update
    C_Update=1
  fi
}

# Install g++ compiler if not installed
if ! command -v g++ &>/dev/null; then
    read -p "To Install g++ enter install or enter below to End the program and manually install g++: " input
    while [[ "$input" != install && "$input" != Install && "$input" != end && "$input" != End ]]; do
      read -p "Try agin: " input
    done
    if [[ "$input" == install ||  "$input" == Install ]];then
      update_and_upgrade
      echo "Installing g++ compiler..."
      sudo apt install -y g++
    else
      exit 1
    fi
fi

# Extract necessary libraries from #include directives
includs=()

while IFS= read -r line; do
    matches=$(echo "$line" | grep -oP '(?<=<).+?(?=>)')
    for match in $matches; do
        if [[ ! " ${includs[@]} " =~ " ${match} " ]]; then
            includs+=("$match")
        fi
    done
done < "$filepath"

# Initial arrays
packages=("libgl1-mesa-dev" "libglu1-mesa-dev" "freeglut3-dev")
flags=("-lGL" "-lGLU" "-lglut")
Open_GL_I=0
Open_GL_P=0

# Define mapping of include files to packages and linker flags
declare -A include_to_package=(
  ["GL/glew.h"]="libglew-dev"
  ["GL/freeglut.h"]="freeglut3-dev"
  ["GL/glext.h"]="libgl1-mesa-dev"
  ["glm/glm.hpp"]="libglm-dev"
  ["glm/gtc/type_ptr.hpp"]="libglm-dev"
  ["glm/gtc/matrix_transform.hpp"]="libglm-dev"
  ["GLFW/glfw3.h"]="libglfw3-dev"
  ["assimp/Importer.hpp"]="libassimp-dev"
)

declare -A include_to_flag=(
  ["GL/glew.h"]="-lGLEW"
  ["GL/freeglut.h"]=""
  ["GL/glext.h"]=""
  ["glm/glm.hpp"]=""
  ["glm/gtc/type_ptr.hpp"]=""
  ["glm/gtc/matrix_transform.hpp"]=""
  ["GLFW/glfw3.h"]="-lglfw"
  ["assimp/Importer.hpp"]="-lassimp"
)

# Function to add unique elements to an array
add_unique()
{
  local element="$1"
  local array_name="$2[@]"
  local array=("${!array_name}")

  for item in "${array[@]}"; do
    if [[ "$item" == "$element" ]]; then
      return 0
    fi
  done
  array+=("$element")
  eval "$2=(\"\${array[@]}\")"
}

# Process each include file
for includ in "${includs[@]}"; do
  if [[ -n "${include_to_package[$includ]}" ]]; then
    add_unique "${include_to_package[$includ]}" packages
    Open_GL_P=1
  fi
  if [[ -n "${include_to_flag[$includ]}" ]]; then
    add_unique "${include_to_flag[$includ]}" flags
    Open_GL_I=1
  fi
done

# Function to check if a package is installed
is_installed()
{
  dpkg-query -W -f='${Status}' "$1" 2>/dev/null | grep -c "ok installed"
}

# Function to install a package if not already installed
install_package()
{
  if [[ $(is_installed "$1") -eq 0 ]]; then
    echo "Package $1 is not installed. Installing..."
    sudo apt-get install -y "$1"
  fi
}

# Process each package in the array
if ((Open_GL_P == 1)); then
  for package in "${packages[@]}"; do
    if [[ $(is_installed "$package") -eq 0 ]]; then
      read -p "To Install $package enter install or enter below to End the program and manually install $package: " input
      while [[ "$input" != install && "$input" != Install && "$input" != end && "$input" != End ]]; do
        read -p "Try agin: " input
      done
      if [[ "$input" == install || "$input" == Install ]];then
        install_package "$package"
      else
        exit 1
      fi
    fi
  done
fi

# Extract the filename without the extension
basename=$(basename "$filepath" .cpp)

# Compile the C++ file
if ((Open_GL_I == 1)); then
  g++ -o "$basename" "$filepath" "${flags[@]}"
else
  g++ -o "$basename" "$filepath"
fi

# Check if compilation was successful
if (( $? == 0 )); then
  echo "Compilation successful"
  # Run the executable file
  ./"$basename"
else
  echo "Error during compilation"
  exit 1
fi
