# force attach shell to a running docker 


The ```docker-force-attach.sh ``` script attaches a shell on a given docker container.
The script first tries to attach a shell with any one of the known shells, 
If this fails, then a statically compiled bash shell executable is downloaded from github and copied to the running container.

### Usage

```./docker-force-attach.sh <docker id>```

