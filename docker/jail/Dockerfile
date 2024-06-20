# Start from a base image, for example Ubuntu
FROM ubuntu:22.04

# Set environment variables to avoid interactive prompts during installation
ENV DEBIAN_FRONTEND=noninteractive

# Update and install necessary packages
RUN apt-get update && \
    apt-get install -y sudo openssh-client && \
    apt-get clean

# Get the user ID and username from the host system
ARG UID
ARG USERNAME

# Create a user with the same UID and username as the host system
RUN useradd -m -s /bin/bash -u "$UID" "$USERNAME"

# Add the user to sudoers
RUN echo "$USERNAME ALL=(ALL) NOPASSWD:ALL" > "/etc/sudoers.d/$USERNAME" && \
    chmod 0440 "/etc/sudoers.d/$USERNAME"

# Set the working directory
WORKDIR /home/$USERNAME

# Switch to the new user
USER $USERNAME

# Start bash when the container runs
CMD ["/bin/bash"]