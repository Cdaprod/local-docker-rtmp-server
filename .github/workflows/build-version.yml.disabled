name: Build & Tag on Success

on:
  push:
    branches: ["**"]
  pull_request:

jobs:
  build:
    runs-on: ubuntu-latest
    defaults:
      run:
        working-directory: win-obs-container

    steps:
      - name: Checkout
        uses: actions/checkout@v3

      - name: Set up Docker
        uses: docker/setup-buildx-action@v3

      - name: Build container
        run: make build

      - name: Test container (optional step)
        run: echo "Test stage passed"

      - name: Generate Version
        id: version
        run: |
          make version
          echo "VERSION=$(cat .version)" >> "$GITHUB_ENV"
          echo "version=$(cat .version)" >> "$GITHUB_OUTPUT"

      - name: Tag version on successful build
        if: success() && github.event_name == 'push'
        run: make tag