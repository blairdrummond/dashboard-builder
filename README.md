# App builder

Register your dashboard in the DASHBOARDS file, with:

- The dashboard name
- The username/repo of your github repo
- The commit sha you want deployed
- The sha256sum of the zip of the repo corresponding to that commit

**Dependencies:**

The builder application requires the tool [s2i](https://github.com/openshift/source-to-image) to be installed.

It also requires `jq`
