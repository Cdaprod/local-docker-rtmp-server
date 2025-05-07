### GitHub Repository CI Workflows:

#### - Dynamic Service Tagging

- Tracks every service individually: success ✅ or failed ❌.
- Prints a Build Report at the end of the run.
- Fails the job only at the end if any service failed -- after finishing all services first.
	
#### - Publish OBS Runtime Image

- Specific to publishing obs-runtime-builder when you create a version tag (like v1.2.3). It's independent of the dynamic service build.

#### - CI-Build Root Compose

- For building and running your root docker-compose.yml. Different job. Needed.

#### - Generate NodeProp Configuration

- Specific to NodeProp YAML automation, unrelated to Docker builds. Very useful if you use .nodeprop.yml.

#### - Generate Docker Compose Diagram

- For visualizing your docker-compose.yaml as an SVG diagram. Very cool and separate from builds.
