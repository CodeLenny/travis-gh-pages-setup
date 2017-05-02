# Travis `gh-pages` Setup

Sets up [Travis CI][] to automatically publish to `gh-pages`.
Currently the process is intended for NodeJS projects only, but could be changed for other environments.

Automated Steps (steps can be opted out of):
- **Creating an empty `gh-pages` branch**
- **Creating an SSH key for deployment**
  - Runs `ssh-keygen` to create the key
  - Encrypts the file and adds to Travis CI configuration
  - Commits the encrypted key to the Git repository (for Travis CI to decrypt)
  - Requests the user to upload the public key as a GitHub deployment key
  - Deletes the public and private keys for security
- **Installs [gh-pages-travis][]** (an NPM package) to handle committing and pushing assets from Travis back to GitHub
- **Configures Travis CI**
  - Creates a Travis CI configuration file if needed (`.travis.yml`) setup for NodeJS
  - Adds [gh-pages-travis][] to run, setting Git details, the directory to upload, and linking the SSH key
  - Prevents Travis CI from running on the `gh-pages` branch

![configuration dialog](https://cloud.githubusercontent.com/assets/9272847/25643554/769a8484-2f6e-11e7-8a08-cc042af30b13.png)


## Usage

The script assumes that you are running on a Unix system with:
- git
- [travis.rb][], Travis CI's command line tool, authenticated with your account (`travis login`)
- The GitHub repository added as a remote repository (`git remote add ...`)

**Save and commit all work** if you will be creating a new, empty `gh-pages` branch.
All files in the repository will be removed, including untracked files.

To download and run the script immediately, use `curl`:

```bash
curl -o- https://raw.githubusercontent.com/CodeLenny/travis-gh-pages-setup/master/travis-gh-pages-setup.sh | bash
```

If you want to save the script to run multiple times, you can download and save the script on your computer.

```bash
curl https://raw.githubusercontent.com/CodeLenny/travis-gh-pages-setup/master/travis-gh-pages-setup.sh -o ~/bin/travis-gh-pages-setup.sh
```

By default, the script will open a dialog to walk you through the setup.  Each step of the script can be disabled,
and the different values used throughout the script can be altered on the configuration page.
A description of each variable is available on the "Change Value" page.

Variables can be preset by setting an environment variable when running the script.  All variables match the name given
in the configuration page, in all capitals and with spaces replaced with underscores.

For instance, the "Safe Clean" and "Deploy Branch" configuration options can be preset via:

```bash
SAFE_CLEAN=false DEPLOY_BRANCH="production" bash travis-gh-pages-setup.sh
```

[Travis CI]: https://travis-ci.org/
[gh-pages-travis]: https://www.npmjs.com/package/gh-pages-travis
[travis.rb]: https://github.com/travis-ci/travis.rb
