#!/usr/bin/env python

# Commit to a file using the GitHub API
# as documented here:
# http://www.levibotelho.com/development/commit-a-file-with-the-github-api/

import os
import sys
import json
import base64
import httplib
from stat import *

def get_url(url, post_data = None):
    if url.find("://") == -1:
        url = "https://api.github.com%s" % url

    if not os.environ.has_key("GITHUB_TOKEN"):
        raise Exception("Set the GITHUB_TOKEN variable")

    (proto, host_path) = url.split('//')
    (host_port, path) = host_path.split('/', 1)
    path = '/' + path

    if url.startswith('https'):
        conn = httplib.HTTPSConnection(host_port)
    else:
        conn = httplib.HTTPConnection(host_port)

    # GitHub requires a valid UA string
    headers = {
        'User-Agent' : 'Mozilla/5.0 (X11; Linux x86_64; rv:10.0.5) Gecko/20120601 Firefox/10.0.5',
        'Authorization': 'token %s' % os.environ['GITHUB_TOKEN'],
    }

    method = 'GET'
    if post_data:
        method = 'POST'
        post_data = json.dumps(post_data)

    conn.request(method, path, body=post_data, headers=headers)
    response = conn.getresponse()

    if (response.status == 404):
        raise Exception("404 - %s not found" % url)

    result = response.read().decode('UTF-8', 'replace')
    try:
        return json.loads(result)
    except ValueError:
        return result

def post_url(url, data):
    return get_url(url, data)

if __name__ == "__main__":
    with open(os.environ["GITHUB_EVENT_PATH"]) as f:
        event = json.load(f)
    
    GITHUB_REPO = event["pull_request"]["head"]["repo"]["full_name"]
    GITHUB_BRANCH = event["pull_request"]["head"]["ref"]

    if len(sys.argv) != 3:
        print("""
usage: ./update_pr.py \"message\" file

where file is the file to update
""")
        sys.exit(1)

    MESSAGE = sys.argv[1]

    GITHUB_FILE = sys.argv[2]
    with open(GITHUB_FILE, 'r') as f:
        CONTENT = f.read()

    if oct(os.stat("vend.sh")[ST_MODE])[-3] == '7':
        MODE = "100755"
    else:
        MODE = "100644"

    # step 1: Get a reference to HEAD
    data = get_url("/repos/%s/git/refs/heads/%s" % (GITHUB_REPO, GITHUB_BRANCH))
    HEAD = {
        'sha' : data['object']['sha'],
        'url' : data['object']['url'],
    }

    # step 2: Grab the commit that HEAD points to
    data = get_url(HEAD['url'])
    # remove what we don't need for clarity
    for key in data.keys():
        if key not in ['sha', 'tree']:
            del data[key]
    HEAD['commit'] = data

    # step 4: Get a hold of the tree that the commit points to
    data = get_url(HEAD['commit']['tree']['url'])
    HEAD['tree'] = { 'sha' : data['sha'] }

    ####
    #### WARNING WRITE OPERATIONS BELOW
    ####

    # step 3: Post your new file to the server
    data = post_url(
                "/repos/%s/git/blobs" % GITHUB_REPO,
                {
                    'content' : CONTENT,
                    'encoding' : 'utf-8'
                }
            )
    HEAD['UPDATE'] = { 'sha' : data['sha'] }

    # step 5: Create a tree containing your new file
    data = post_url(
                "/repos/%s/git/trees" % GITHUB_REPO,
                {
                    "base_tree": HEAD['tree']['sha'],
                    "tree": [{
                        "path": GITHUB_FILE,
                        "mode": MODE,
                        "type": "blob",
                        "sha": HEAD['UPDATE']['sha']
                    }]
                }
            )
    HEAD['UPDATE']['tree'] = { 'sha' : data['sha'] }

    # step 6: Create a new commit
    data = post_url(
                "/repos/%s/git/commits" % GITHUB_REPO,
                {
                    "message": MESSAGE,
                    "parents": [HEAD['commit']['sha']],
                    "tree": HEAD['UPDATE']['tree']['sha']
                }
            )
    HEAD['UPDATE']['commit'] = { 'sha' : data['sha'] }

    # step 7: Update HEAD, but don't force it!
    data = post_url(
                "/repos/%s/git/refs/heads/%s" % (GITHUB_REPO, GITHUB_BRANCH),
                {
                    "sha": HEAD['UPDATE']['commit']['sha']
                }
            )

    if data.has_key('object'): # PASS
        sys.exit(0)
    else: # FAIL
        print(data['message'])
        sys.exit(1)