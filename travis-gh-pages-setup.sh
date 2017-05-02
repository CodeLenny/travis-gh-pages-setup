#!/bin/bash

# `travis-gh-pages-setup` sets up a NodeJS repository to publish build assets on `gh-pages` from Travis CI.
# https://github.com/CodeLenny/travis-gh-pages-setup

# Copyright (c) 2017 Ryan Leonard.
# See https://github.com/CodeLenny/travis-gh-pages-setup/blob/master/LICENSE.md for full license.

[ -d .git ] || { echo "Error: Current directory is not a git repository ('.git' directory not found)."; exit 1; }

[ "$(git remote | wc -l)" == "0" ] && { echo "Error: No git remotes found.  ('git remote' returned 0 lines)"; exit 1; }

command -v "travis" >/dev/null 2>&1 || {
  echo "Error: 'travis' not found.  https://github.com/travis-ci/travis.rb"; exit 1;
}

# TODO: Check that repo is owned by user (so travis encrypt will work)

VARIABLES=(); VARIABLES_READABLE=()

# Compute the width and height of the current console
console_size () { CONSOLE_WIDTH=$(tput cols); CONSOLE_HEIGHT=$(tput lines); }

# Prepares generic variables needed across all variable inputs.
# Usage: <variable name> <variable index>
variable_unpack () {
  console_size
  READABLE=${VARIABLES_READABLE[$2]}; HELP="__$1_HELP"; OPTIONS="__$1_INPUT"
}

# Usage: <variable name> <variable index>
variable_select () {
  variable_unpack "$1" "$2"
  local MENU_HEIGHT=$((CONSOLE_HEIGHT - 3))
  local ITEMS=(); local i=0; for option in "${!OPTIONS}"; do ITEMS+=($((++i)) "$option"); done
  local result=$(dialog --title "Change $READABLE" --ok-label "Update Value" --cancel-label "Back" --stdout \
    --menu "${!HELP}" $((CONSOLE_HEIGHT / 2)) $((CONSOLE_WIDTH / 2)) $MENU_HEIGHT "${ITEMS[@]}")
  if [ "$?" == "0" ]; then printf -v "$1" "$(echo "${!OPTIONS}" | sed "${result}q;d" )"; fi
}

# Usage: <variable name> <variable index>
variable_inputbox () {
  variable_unpack "$1" "$2"
  local ref="$1"
  local result=$(dialog --title "Change $READABLE" --ok-label "Update Value" --cancel-label "Back" --stdout \
    --inputbox "${!HELP}" $((CONSOLE_HEIGHT / 2)) $((CONSOLE_WIDTH / 2)) "${!ref}")
  if [ "$?" == "0" ]; then printf -v "$1" "$result"; fi
}

# Usage: <variable name> <variable index>
variable_truefalse () {
  variable_unpack "$1" "$2"
  local opts=(); while IFS= read -r option; do opts+=("$option"); done <<< "${!OPTIONS}"
  dialog --title "Change $READABLE" --extra-button --ok-label "'true'" --cancel-label "'false'" --extra-label "Back" \
    "${opts[@]}" --yesno "${!HELP}" $((CONSOLE_HEIGHT / 2)) $((CONSOLE_WIDTH / 2))
  local result=$?
  if [ "$result" == "0" ]; then printf -v "$1" "true"; fi
  if [ "$result" == "1" ]; then printf -v "$1" "false"; fi
}

variable_gui () {
  console_size
  local ITEMS=()
  for (( i = 0; i<${#VARIABLES[@]}+1; i++ )); do
    local NAME="${VARIABLES[$i]}"; ITEMS+=("${VARIABLES_READABLE[$i]}" "${!NAME}")
  done
  result=$(dialog --title "Configuration" --extra-button --ok-label "Change Value" --extra-label "Abort" \
    --cancel-label "Start Program" --stdout --menu "Configuration options are shown below, along with the current \
    configuration values.  A description for each variable is available on the 'Change Value' screen." \
    $((CONSOLE_HEIGHT - 3)) $((CONSOLE_WIDTH / 2)) $((CONSOLE_HEIGHT - 6)) "${ITEMS[@]}")
  local exitCode=$?
  if [ "$exitCode" == "0" ]; then
    for (( i = 0; i<${#VARIABLES_READABLE[@]}+1; i++ )); do
      if [ "${VARIABLES_READABLE[$i]}" == "$result" ]; then index=$i; break; fi
    done
    local variable=${VARIABLES[$index]}
    local gui_display_fn="__${variable}_TYPE"; local gui_display_fn="variable_${!gui_display_fn}"
    $gui_display_fn $variable $index
    variable_gui
  elif [ "$exitCode" == "3" ]; then
    exit 1
  fi
}

# Declare a "default variable" - a variable with a sane default value that most likely won't need to be changed.
# Usage: variable <variable name> <default> <description> <input type> <input options>
# Example: variable GIT_HOST "GitHub" "The remote repository host." "select" "GitHub\nGitLab\nSelf-Hosted GitLab"
variable () {
  local READABLE=$(echo "$1" | sed -r 's/^([A-Z0-9])([A-Z0-9]*)/\1\L\2/' | sed -r 's/_([A-Z0-9])([A-Z0-9]*)/ \1\L\2/g')
  VARIABLES+=("$1"); VARIABLES_READABLE+=("$READABLE")
  local value="${!1}"
  printf -v "$1" "${value:-$2}"
  printf -v "__$1_HELP" "$3"; printf -v "__$1_TYPE" "$4"; printf -v "__$1_INPUT" -- "$5"
}

variable STAGE_1_CREATE_BRANCH "true" "Creates an empty 'gh-pages' branch and push upstream." "truefalse" \
  '--ok-label\nCreate Branch\n--cancel-label\nSkip Stage'
variable STAGE_2_DEPLOY_KEY "true" "Create an SSH deploy key and add it to the Travis config." "truefalse" \
  '--ok-label\nCreate Key\n--cancel-label\nSkip Stage'
variable STAGE_3_TRAVIS_CONFIG "true" "Add 'gh-pages-travis' package to publish documentation, and modify '.travis.yml'\
  to configure the build" '--ok-label\nConfigure Travis\n--cancel-label\nSkip Stage'
variable KEY_EMAIL "deploy@travis-ci.org" "An email address included in the SSH deploy key" "inputbox" ""
variable DEPLOY_BRANCH "master" "The branch that should trigger publishing assets in CI." "inputbox" ""
variable SOURCE_DIR "doc" "The directory that should be published to GitHub Pages." "inputbox" ""
variable GIT_NAME "travis" "The name used for automated git commits when publishing pages." "inputbox" ""
variable GIT_EMAIL "deploy@travis-ci.org" "An email address for automated git commits when publishign pages" "inputbox"\
  ""
variable SAFE_CLEAN "true" "Do you want to be asked about items being removed by 'git clean'?" "truefalse" \
  '--ok-label\nAsk Me\n--cancel-label\nRemove Everything'
variable KEY_FILE "id_rsa" "The location of the deploy key in the repository" "inputbox" ""
variable CURRENT_BRANCH "$(git symbolic-ref --short -q HEAD)" "The name of the current branch." "inputbox" ""
REMOTE_LIST=$(git remote); REMOTE0=$(echo "$REMOTE_LIST" | tail -n 1)
variable GITHUB_UPSTREAM "$REMOTE0" "The local name for the upstream git remote." "select" "$REMOTE_LIST"
variable BRANCH_NAME "gh-pages" "The name of the remote branch to update during build." "inputbox" ""

variable_gui

###  Create empty gh-pages branch  ###

if [ "$STAGE_1_CREATE_BRANCH" == "true" ]; then
  echo "Creating $BRANCH_NAME branch."
  git symbolic-ref HEAD refs/heads/$BRANCH_NAME
  rm .git/index
  if [ "$SAFE_CLEAN" == "true" ]; then
    echo "Deleting contents of the directory to create a clean '$BRANCH_NAME' branch."
    echo "Please follow the prompt to remove all files."
    git clean -idx
  else 
    git clean -fdx
  fi
  git commit --allow-empty -m "Started '$BRANCH_NAME' branch."
  git push $GITHUB_UPSTREAM $BRANCH_NAME
  git checkout $CURRENT_BRANCH
  echo "'$BRANCH_NAME' branch created and pushed to '$GITHUB_UPSTREAM'."
fi

###  Setup Travis CI configuration  ####

if [ "$STAGE_2_DEPLOY_KEY" == "true" ]; then
  echo "Setting up deploy key."
  ssh-keygen -t rsa -C "$KEY_EMAIL" -f $KEY_FILE -N ''
  travis encrypt-file "$KEY_FILE" --add
  console_size
  dialog --title "Deploy Key" --extra-button --yes-label "Don't Delete Keys"  --extra-label "Delete Keys" \
    --no-label "Abort" --yesno \
    "SSH key '$KEY_FILE' has been created.  Please copy/paste the contents of '$KEY_FILE.pub' into the GitHub \
    settings for your repository.\nOnce the file has been uploaded, both '$KEY_FILE' and '$KEY_FILE.pub' should be \
    deleted." \
    $((CONSOLE_HEIGHT / 2)) $((CONSOLE_WIDTH / 2))
  if [ "$?" == "3" ]; then exit 1; fi
  if [ "$?" == "1" ]; then rm -rf $KEY_FILE $KEY_FILE.pub; fi
  console_size
  dialog --title "Commit Encrypted Deploy Key?" --yesno "Can I add and commit '$KEY_FILE.enc'?" $((CONSOLE_HEIGHT / 2))\
    $((CONSOLE_WIDTH / 2))
  if [ "$?" == "0" ]; then
    git add "$KEY_FILE.enc"
    git commit -m "Added '$KEY_FILE.enc' for automated deployments."
  fi
fi

if [ "$STAGE_3_TRAVIS_CONFIG" == "true" ]; then
  npm install yawn-yaml-cli
  npm install --save-dev gh-pages-travis
  
  if [ ! -f ".travis.yml" ]; then
    echo ".travis.yml doesn't exist, initializing now."
    echo "language: node_js" > .travis.yml
    echo "node_js: node" >> .travis.yml
  fi
  
  $(npm bin)/yawn push .travis.yml env.global "DEPLOY_BRANCH=\"$DEPLOY_BRANCH\""
  $(npm bin)/yawn push .travis.yml env.global "SOURCE_DIR=\"$SOURCE_DIR\""
  $(npm bin)/yawn push .travis.yml env.global "TARGET_BRANCH=\"$BRANCH_NAME\""
  $(npm bin)/yawn push .travis.yml env.global "SSH_KEY=\"$KEY_FILE\""
  $(npm bin)/yawn push .travis.yml env.global "GIT_NAME=\"$GIT_NAME\""
  $(npm bin)/yawn push .travis.yml env.global "GIT_EMAIL=\"$GIT_EMAIL\""
  
  scriptlen=$($(npm bin)/yawn get .travis.yml script 2>/dev/null | wc -l)
  if [ "$scriptlen" == "0" ]; then
    $(npm bin)/yawn push .travis.yml script "npm test"
  fi
  $(npm bin)/yawn push .travis.yml script "\"\$(npm bin)/gh-pages-travis\""
  
  $(npm bin)/yawn push .travis.yml branches.except "$BRANCH_NAME"
fi

cat << EOF
This directory is now setup to publish the contents of $SOURCE_DIR to $BRANCH_NAME during the Travis CI build.

If $SOURCE_DIR is populated via a script, add the script to '.travis.yml' above the line '\$(npm bin)/gh-pages-travis'.
EOF
