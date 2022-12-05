# force attach shell to a running docker 

The script attaches a shell to a running docker container, even if the image of the container does not include a shell.
For this purpose a statically compiled bash shell is downloaded and copied to the running container.

```./docker-force-attach.sh <docker id>```
