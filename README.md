# docker-php - Docker image for PHP with commmon extensions

This whole repository provides a Docker image for PHP, pre-configured with commonly used extensions and tools. It is designed to simplify the setup of PHP development and production environments.

## Features

- PHP with popular extensions
- FFMPEG for multimedia processing
- Easy to customize via Dockerfile

## Usage

1. Clone the repository:
    ```bash
    git clone https://github.com/yourusername/docker-php.git
    cd docker-php
    ```

2. Build the Docker image:
    ```bash
    docker build -t my-php-image .
    ```

3. Run a container:
    ```bash
    docker run -it --rm my-php-image
    ```

## Customization

You can modify the `Dockerfile` to add or remove PHP extensions as needed.

## License

This project is licensed under the Unlicense (Unported License).
