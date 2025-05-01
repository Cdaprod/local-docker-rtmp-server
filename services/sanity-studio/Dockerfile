# services/sanity-studio/Dockerfile

FROM node:20

# Set working directory
WORKDIR /app

# Install global Sanity CLI
RUN yarn global add sanity

# Install esbuild manually for ARM64 (fixes the install.js issue)
RUN yarn add esbuild --dev --platform=linuxarm64

# Set yarn configs
RUN yarn config set nodeLinker node-modules

# Copy package.json and install dependencies
COPY package.json yarn.lock ./
RUN yarn install

# Copy all project files
COPY . .

# Expose Sanity dev server port
EXPOSE 3333

# Default command
CMD ["yarn", "dev"]