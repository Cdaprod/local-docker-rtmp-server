FROM node:20-bullseye

WORKDIR /app

# Use yarn v1 (works cleanly on ARM)
RUN npm install -g yarn@1.22.22

# Install esbuild manually for ARM64
RUN yarn add --dev esbuild --platform=linuxarm64

COPY package.json yarn.lock ./
RUN yarn install

COPY . .

EXPOSE 3333

CMD ["yarn", "dev"]