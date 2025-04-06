# RPM Repository Mirror

This project provides a Docker-based solution for creating a mirror of an RPM repository. It includes all necessary scripts and configuration files to set up and run the repository synchronization process.

## Project Structure

- **Dockerfile**: Contains instructions to build the Docker image for the RPM repository mirror.
- **scripts/mirror-repo.sh**: Script responsible for syncing the RPM repositories using `dnf` or `yum`.
- **config/repo-config.repo**: Configuration file specifying the repository URLs and options for synchronization.
- **data**: Directory to hold mirrored repository data. (Tracked by Git with `.gitkeep`)
- **docker-compose.yml**: Defines services, networks, and volumes for the Docker application.
- **README.md**: Documentation for building and running the Docker container.

## Prerequisites

- Docker installed on your machine.
- Docker Compose installed (if using `docker-compose.yml`).

## Building the Docker Image

To build the Docker image, navigate to the project directory and run:

```
docker build -t rpm-repo-mirror .
```

## Running the Container

To run the container, use the following command:

```
docker run --rm -v $(pwd)/data:/data rpm-repo-mirror
```

This command mounts the `data` directory to persist the mirrored repository data.

## Usage

After running the container, the RPM repositories specified in the `config/repo-config.repo` file will be synchronized to the `data` directory.

## Contributing

Feel free to submit issues or pull requests for improvements or additional features.