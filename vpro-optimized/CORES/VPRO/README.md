# VPRO Core

Hardware Description of the Vectorprocessor 

# EIS Configuration

## GIT Config (EIS)

- Create empty directory for this repo: `mkdir VPRO`
- Initialize Git: `git init`
- Edit Git configuration file: `nano .git/config`
```
[core]
	repositoryformatversion = 0
	filemode = true
	bare = false
	logallrefupdates = true

[remote "eis"]
	url = git@git.eis.tu-bs.de:asip/cores/vpro.git
    fetch = +refs/heads/*:refs/remotes/origin/*
[branch "behavioral"]
    remote = eis
    merge = refs/heads/behavioral

[remote "tu"]
    url = git@git.rz.tu-bs.de:theoretische-informatik/ti/zuse-ki-avf/vpro.git
    fetch = +refs/heads/behavioral:refs/remotes/origin/behavioral
[branch "main"]
	remote = eis
	merge = refs/heads/main
```
- Pull EIS internal branches: `git pull eis && git checkout main`
    - including behavioral branch

- **tu** Behavioral Branch: `git checkout behavioral`
    - Get **tu** changes on behavioral branch to current branch (behavioral): `[behavioral] git pull tu behavioral`
    - Push current changes on behavioral branch to **tu**: `[behavioral] git push tu`

###### Two remotes: **tu** (external) and **eis** (internal)  
Branch **behavioral** is pulled from tu (external: `git checkout behavioral`  
Branch **master** and others are pulled from eis (internal): `git checkout main`  

(maybe: --allow-unrelated-histories)
