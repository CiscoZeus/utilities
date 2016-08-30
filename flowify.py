import shutil
import time

from github import Github
from git import Repo

GITHUB_USERNAME=""
GITHUB_PASSWORD=""

g = Github(GITHUB_USERNAME, GITHUB_PASSWORD)
for repo in g.get_organization("CiscoZeus").get_repos():
    try:
        print "Cloning repository:", repo.name
        cloned_repo = Repo.clone_from(repo.ssh_url, "/tmp/"+repo.name)
        dev_branch = cloned_repo.create_head("develop")
        print "Creating develop from master"
        cloned_repo.head.reference = dev_branch
        origin = cloned_repo.remote('origin')
        origin.push('develop')
        shutil.rmtree("/tmp/"+repo.name)
        time.sleep(10)
    except:
        print "failed on repository:", repo.name
