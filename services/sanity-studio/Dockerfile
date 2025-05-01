# services/sanity-studio/Dockerfile

FROM node:20

WORKDIR /app

# Enable Corepack if staying on Yarn 4
# RUN corepack enable && corepack prepare yarn@4.9.1 --activate

# Optional: Downgrade if using Yarn 1
RUN corepack disable

# Install CLI for Sanity without 'global'
RUN yarn dlx sanity@latest init --project

# Install esbuild manually for ARM64
RUN yarn add --dev esbuild --platform=linuxarm64

# Set yarn configs (only valid with node_modules linker)
RUN yarn config set nodeLinker node-modules

COPY package.json yarn.lock ./
RUN yarn install

COPY . .

EXPOSE 3333

CMD ["yarn", "dev"]