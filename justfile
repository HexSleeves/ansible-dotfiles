set dotenv-load := false

playbook := "site.yml"

default:
    @just --list

list:
    @just --list

doctor:
    ansible --version
    ansible-galaxy collection list

collections:
    ansible-galaxy collection install -r requirements.yml --upgrade

syntax:
    ansible-playbook --syntax-check {{playbook}}

check *args:
    ansible-playbook {{playbook}} --check --diff {{args}}

apply *args:
    ansible-playbook {{playbook}} --diff {{args}}

bootstrap *args:
    bash scripts/bootstrap.sh {{args}}

tags tags *args:
    ansible-playbook {{playbook}} --tags {{tags}} --diff {{args}}

check-tags tags *args:
    ansible-playbook {{playbook}} --tags {{tags}} --check --diff {{args}}

packages *args:
    ansible-playbook playbooks/packages.yml --diff {{args}}

secrets *args:
    ansible-playbook playbooks/secrets.yml --diff {{args}}

dotfiles *args:
    ansible-playbook playbooks/dotfiles.yml --diff {{args}}

refresh-gpg:
    bash scripts/export-keys.sh --ansible-vault

test:
    bash -n scripts/export-keys.sh
    bash -n tests/export-keys-regression.sh
    bash -n tests/chezmoi-update-noninteractive.sh
    bash -n tests/no-deprecated-apt-repository.sh
    bash -n tests/no-ssh-sockets-mode-flap.sh
    bash tests/chezmoi-update-noninteractive.sh
    bash tests/no-deprecated-apt-repository.sh
    bash tests/no-ssh-sockets-mode-flap.sh
    bash tests/export-keys-regression.sh
    ansible-playbook --syntax-check {{playbook}}

verify:
    just test
    git diff --check
    git diff --cached --check
