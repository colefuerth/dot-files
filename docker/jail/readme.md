# jail

I have dubbed this jail since it lets me test things in a blank cage

## Purpose

This container exists so that there is a quickly accessible container where I can test "new" things from scratch

## Building the container

1. You will need `docker` installed and running on your system.
   1. If you are using WSL2, then you *should* already have docker installed on Windows. (If not, something was installed incorrectly; WSL2 and docker kind of go hand in hand on Windows.) Just make sure you are running `Docker Desktop` on your host, and that your current WSL2 instance is the primary, and the `docker` command should be available in WSL2.
   2. If you are using VMWare, you will need to install docker on your guest OS. I do not personally recommend using this method if you are on VMWare, since now you are nesting virtualization, and `buildcore` is the largest and most common thing you build; I recommend building on the VM and docker-izing everything else instead. **However**, you can install docker on your Linux distro by following the [official instructions](https://docs.docker.com/engine/install/) for your distro.
2. `cd` into this folder; you must be in the same directory as the Dockerfile you are building.
3. `./builder.sh` **OR** `docker build -t jail . --build-arg USERNAME=$(whoami) --build-arg UID=$(id -u)`

## Running a one-time/temp container

If you want a one-off container, run the command:

```bash
docker run -it --rm \
   -v $HOME/.ssh:/home/$(whoami)/.ssh:ro \
   -e USERNAME=$(whoami) \
   jail
```

*Note:* if you need more than 10gb of disk space, you will need a volume. This can be done by adding the arg `-v jail_home:/home/$(whoami)` to the `docker run` command.

## Running a persistent container

There are functions that I have defined for this, which I will detail below. These exist in the [docker_sd] aliases file, but you can add them to .bashrc.

The benefit to this is, you have a mirrored, blank environment in which to test things that persists between runs, and that the 10gb size limit is gone.

`jail` will run a container whether it exists or not (create if not exist), and `unjail` will clear out the previous jail.

```bash
# Run the last jail container if it exists, else create a new one
jail() {
    local container_name="jail"
    if [ "$(docker ps -aq -f name=^/${container_name}$)" ]; then
        if [ "$(docker ps -aq -f status=exited -f name=^/${container_name}$)" ]; then
            echo "Starting existing jail container..."
            docker start -ai ${container_name}
        else
            echo "Attaching to running jail container..."
            docker attach ${container_name}
        fi
    else
        echo "Creating new jail container..."
        docker run -it \
            -v $HOME/.ssh:/home/$(whoami)/.ssh:ro \
            -v jail_home:/home/$(whoami) \
            -e USERNAME=$(whoami) \
            --name ${container_name} \
            jail
    fi
}

# Delete the jail container and its associated volume, but don't remove the base image
unjail() {
    local container_name="jail"
    local volume_name="jail_home"

    # Stop the container if it's running
    if [ "$(docker ps -q -f name=^/${container_name}$)" ]; then
        echo "Stopping jail container..."
        docker stop ${container_name}
    fi

    # Remove the container
    if [ "$(docker ps -aq -f name=^/${container_name}$)" ]; then
        echo "Removing jail container..."
        docker rm ${container_name}
    else
        echo "Jail container does not exist."
    fi

    # Remove the volume
    if [ "$(docker volume ls -q -f name=^${volume_name}$)" ]; then
        echo "Removing jail volume..."
        docker volume rm ${volume_name}
    else
        echo "Jail volume does not exist."
    fi

    echo "Jail container and volume have been removed. The jail image remains intact."
}
```

## Interacting with BitBucket from inside the container (not recommended, but available if you need to do it)

This is generally not recommended, as sharing private keys is generally just a no-no, but I have it turned on for convenience.

However, having been warned, the command `-v "$HOME/.ssh:$HOME/.ssh"` option has been added to the `docker run` command to allow the container to access your host SSH key.

Alternatively, if you want to be a little more secure, you can generate a new SSH key pair, and pass those in to the container. If you are doing bitbucket things inside this container, I would recommend you do this, so you can track whether things were pushed from the container or the host. There should be a way in bitbucket to specify certain keys to have only read permission, which is what I recommend doing.
