{%- set envs = ['dev', 'qa', 'staging', 'prod', 'preprod'] %}
{%- set aenvs = [] %}{%- for i in envs %}{% if cookiecutter.get(i+'_host', '')%}{% set _ = aenvs.append(i) %}{%endif%}{%endfor%}
{%- set refenv = aenvs|length > 1 and aenvs[-2] or aenvs[-1] %}
# Initialize your development environment
- Only now launch pycharm and configure a project on this working directory

All following commands must be run only once at project installation.


## First clone

```sh
# check the remote protocol you may want to choose between http and ssh
git clone --recursive {{cookiecutter.git_project_url}}
{%if cookiecutter.use_submodule_for_deploy_code-%}git submodule init # only the fist time
git submodule update --recursive{%endif%}
```

## Before using any ansible command: a note on sudo

If your user is ``sudoer`` but is asking for you to input a password before elavating privileges,
You will need to add ``--ask-become-pass`` (or in earlier ansible versions: ``--ask-sudo-pass``) and maybe ``--become`` to any of the following ``ansible alike`` commands.

## Install corpusops
If you want to use ansible, or ansible vault (see passwords) or install docker via automated script
```sh
.ansible/scripts/download_corpusops.sh
.ansible/scripts/setup_corpusops.sh
```

## Install docker and docker compose
if you are under debian/ubuntu/mint/centos you can do the following:
```sh
local/*/bin/cops_apply_role --become \
    local/*/*/corpusops.roles/services_virt_docker/role.yml
```

... or follow official procedures for
  [docker](https://docs.docker.com/install/#releases) and
  [docker-compose](https://docs.docker.com/compose/install/).


## Update corpusops
You may have to update corpusops time to time with

```sh
./control.sh up_corpusops
```

## Configuration

Use the wrapper to init configuration files from their ``.dist`` counterpart
and adapt them to your needs.

```bash
./control.sh init
```

**Hint**: You may have to add `0.0.0.0` to `ALLOWED_HOSTS` in `local.py`.

## Login to the app docker registry

You need to login to our docker registry to be able to use it:


```bash
docker login {{cookiecutter.docker_registry}}  # use your gitlab user
```

{%- if cookiecutter.registry_is_gitlab_registry %}
**⚠️ See also ⚠️** the
    [project docker registry]({{cookiecutter.git_project_url.replace('ssh://', 'https://').replace('git@', '')}}/container_registry)
{%- else %}
**⚠️ See also ⚠️** the makinacorpus doc in the docs/tools/dockerregistry section.
{%- endif%}

# Use your development environment

## Update submodules

Never forget to grab and update regulary the project submodules:

```sh
git pull{% if cookiecutter.use_submodule_for_deploy_code
%}
git submodule init # only the fist time
git submodule update --recursive{%endif%}
```

## Control.sh helper

You may use the stack entry point helper which has some neat helpers but feel
free to use docker command if you know what your are doing.

```bash
./control.sh usage # Show all available commands
```

## Start the stack

After a last verification of the files, to run with docker, just type:

```bash
# First time you download the app, or sometime to refresh the image
./control.sh pull # Call the docker compose pull command
./control.sh up # Should be launched once each time you want to start the stack
```

## Launch app in foreground

```bash
./control.sh fg
```

**⚠️ Remember ⚠️** to use `./control.sh up` to start the stack before.

## Start a shell inside the {{cookiecutter.app_type}} container

- for user shell

    ```sh
    ./control.sh usershell
    ```
- for root shell

    ```sh
    ./control.sh shell
    ```

**⚠️ Remember ⚠️** to use `./control.sh up` to start the stack before.

## Run plain docker-compose commands

- Please remember that the ``CONTROL_COMPOSE_FILES`` env var controls which docker-compose configs are use (list of space separated files), by default it uses the dev set.

    ```sh
    ./control.sh dcompose <ARGS>
    ```

## Rebuild/Refresh local docker image in dev

```sh
./control.sh buildimages
```

## Running heavy session
Like for installing and testing packages without burning them right now in requirements.<br/>
You will need to add the network alias and maybe stop the plone worker

```sh
./control.sh stop {{cookiecutter.app_type}}
services_ports=1 ./control.sh usershell
sudo /init.sh do_fg
```

**⚠️ Remember ⚠️** to use `./control.sh up` to start the stack before.

## Run tests

```sh
./control.sh tests
# also consider: linting|coverage
```

**⚠️ Remember ⚠️** to use `./control.sh up` to start the stack before.

## File permissions

If you get annoying file permissions problems on your host in development, you can use the following routine to (re)allow your host
user to use files in your working directory


```sh
./control.sh open_perms_valve
```

## Docker volumes

Your application extensivly use docker volumes. From times to times you may
need to erase them (eg: burn the db to start from fresh)

```sh
docker volume ls  # hint: |grep \$app
docker volume rm $id
```

## Reusing a precached image in dev to accelerate rebuilds
Once you have build once your image, you have two options to reuse your image as a base to future builds, mainly to accelerate buildout successive runs.

- Solution1: Use the current image as an incremental build: Put in your .env

    ```sh
    {{cookiecutter.app_type.upper()}}_BASE_IMAGE={{ cookiecutter.docker_image }}:latest-dev
    ```

- Solution2: Use a specific tag: Put in your .env

    ```sh
    {{cookiecutter.app_type.upper()}}_BASE_IMAGE=a tag
    # this <a_tag> will be done after issuing: docker tag registry.makina-corpus.net/mirabell/chanel:latest-dev a_tag
    ```

## Integrating an IDE
- <strong>DO NOT START YET YOUR IDE</strong>
- Start the stack, but specially stop the app container as you will
  have to separatly launch it wired to your ide

    ```sh
    ./control.sh up
    ./control.sh down {{cookiecutter.app_type}}
    ```

### Using pycharm

- Tips and tricks to know:
    - the python interpreter (or wrapper in our case) the pycharm glue needs should be named `python.*`
    - Paths mappings are needed for pycharm `<= 2022`, unless pycharm will execute in its own folder under `/opt` totally messing the setup
    - you should have the latest (`2022-09-22`) code of the common glue (`local/plone-deploy-common`) for this to work
- Goto settings (CTRL-ALT-S)
    - `Pycharm >=2022`:
        - Create a `docker-compose` python interpreter:
            - compose files: `docker-compose.yml`, `docker-compose-dev.yml`, `docker-compose-build-dev.yml`, `docker-compose-build-dev.yml`
            - service: `plone`
            - Set python interpreter: `/app/sys/python-pycharm`, **BE SURE TO RESELECT AFTER INPUTING THE DIALOG BOX**
        - on project structure: make your project root is the **ContentRoot**, and add `src` and other TOP subfolders as sources folders
        - On Build, exec, deploy / Console:
            - Both **PLONE** and **PYTHON** Path Mapping: Add with browsing your local:`/absolute/path/src` , remote: `/app/src` <br/>
              (you should then see `</absolute/path/Project root>/src→/app/src`)
    - `Pycharm <=2022`:
        - Create a `docker-compose` python interpreter:
            - compose files: `docker-compose.yml`, `docker-compose-dev.yml`
            - Set python interpreter: `/app/sys/python-pycharm`
            - service: `plone`
        - On project python interpreter settings page, set:
            - Path Mapping: Add with browsing your local:`src` , remote: `/app/src` <br/>
              (you should then see `<Project root>/src→/app/src`)
    - **TODO**: how to integrate with a project
    - be sure that your firewall settings allow connection from the containers to your host ! See https://youtrack.jetbrains.com/issue/PY-21325

## Doc for deployment on environments
- [See here](./docs/README.md)

## FAQ

If you get troubles with the nginx docker env restarting all the time, try recreating it :

```bash
docker-compose -f docker-compose.yml -f docker-compose-dev.yml up -d --no-deps --force-recreate nginx backup
```

If you get the same problem with the {{cookiecutter.app_type}} docker env :

```bash
docker-compose -f docker-compose.yml -f docker-compose-dev.yml stop {{cookiecutter.app_type}} db
docker volume rm {{cookiecutter.lname}}-postgresql # check with docker volume ls
docker-compose -f docker-compose.yml -f docker-compose-dev.yml up -d db
# wait for database stuff to be installed
docker-compose -f docker-compose.yml -f docker-compose-dev.yml up {{cookiecutter.app_type}}
```

## Settings managment
- We embrace many concepts to manage our configurations, specially 12Factors.

## Pipelines workflows tied to deploy environments and built docker images
### TL;DR
- We use deploy branches where some git **branches** (main branch, tags, and environment related branches) are dedicated to deploy related **gitlab**, **configuration managment tool's environments**, and **docker images tags**.<br/>
- You can use them to deliver to a specific environment either by:
    1. Not using promotion workflow and only pushing to this branch and waiting for the whole pipeline to complete the image build, and then deploy on the targeted env.
    2. Using tags promotion: "Docker Image Promotion is the process of promoting Docker Images between registries to ensure that only approved and verified images are used in the right environments, such as production."<br/>
        - You **run or has run a successful pipeline with the code you want to deploy**, (surely ``{{cookiecutter.main_branch}}`` or a specific Tag).
        - You can then **``promote`` its related docker tag** to either **one or all** env(s) with the ``promote_*`` jobs and reuse the previously produced tag.<br/>
        - After the succesful promotion, you can then manually **deploy on the targeted env(s)**.
        - TIP: The Promote & Deploy steps can be done at once using the `promote_and_deploy_*` jobs.

### Using promotion in practice
- As an example, we are taking <br/>
  &nbsp;&nbsp;&nbsp;&nbsp;the ``{{refenv}}`` branch which is tied to <br/>
  &nbsp;&nbsp;&nbsp;&nbsp;the {{refenv}} **inventory ansible group**<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;and deliver the {{refenv}} **docker image**<br/>
  &nbsp;&nbsp;&nbsp;&nbsp;and associated resources on the **{{refenv}} environment**.
- First, run an entire pipeline on the branch (eg:``{{cookiecutter.main_branch}}``) and the commit you want to deploy.<br/>
  Please note that it can also be another branch like `stable` if `stable` branch was configured to produce the `stable` docker tags via the `TAGGUABLE_IMAGE_BRANCH` [`.gitlab-ci.yml`](./.gitlab-ci.yml) setting.
- Push your commit to the desired related env branche(s) (remove the ones you won't deploy now) to track the commit you are deploying onto

    ```sh
    # on local main branch
    git fetch --all
    git reset --hard origin/{{cookiecutter.main_branch}}
    git push --force origin{% for i in aenvs %} HEAD:{{i}}{%endfor %}
    ```
    1. Go to your gitab project ``pipelines`` section and immediately kill/cancel all launched pipelines.
    2. Find the killed pipeline on the environment (branch) you want to deploy onto (and if you don't have it, launch one via the ``Run pipeline`` button and **immediatly kill** it),<br/>
       Click on the ``canceled/running`` button link which links the pipeline details), <br/>
       It will lead to a jobs dashboard which is really appropriated to complete next steps.<br/>
       Either run:
        - one of the `promote_and_deploy_*` available on the main branch (``{{cookiecutter.main_branch}}``), Tags, Or the deploy branch related to the deployed environment.
        - or
            - ``promote_all_envs``: promote all deploy branches with the selected ``FROM_PROMOTE`` tag (see just below).
            - ``promote_single_env``: promote only this env with the selected ``FROM_PROMOTE`` tag (see just below).
        - Note that **in both jobs**, you can override the default promoted tag which is ``latest`` with the help of that ``FROM_PROMOTE`` pipeline/environment variable.<br/>
          This can help in those following cases:
            - If you want `production` to be deployed with the `dev` image, you can then set `FROM_PROMOTE=dev`.
            - If you want `dev` to be deployed with the `stable` image produced by the `stable` branch, you can then set `FROM_PROMOTE=stable`.
    3. Upon successful promotion, run the ``manual_deploy_$env`` job. (eg: ``manual_deploy_dev``)

{# no telport for now
# Teleport (load one env from one another)
init your vault (see [`docs/README.md`](./docs/README.md#docs#generate-vault-password-file))

```sh
CORPUSOPS_VAULT_PASSWORD="xxx" .ansible/scripts/setup_vaults.sh
.ansible/scripts/call_ansible.sh .ansible/playbooks/deploy_key_setup.yml
```

## Load a production database from old prod (standard modes)
```sh
.ansible/scripts/call_ansible.sh -vvvv .ansible/playbooks/teleport.yml \
    -e "{teleport_mode: standard, teleport_destination: controller, teleport_origin: {{cookiecutter.teleport_branch}}}"
```

## Load a production database from old prod (makinastates modes)
```sh
.ansible/scripts/call_ansible.sh -vvvv .ansible/playbooks/teleport.yml \
    -e "{teleport_mode: makinastates, teleport_destination: controller, teleport_origin: oldprod}"
```
/no teleport for now#}
