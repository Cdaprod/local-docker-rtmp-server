# services/sanity-studio/Dockerfile

FROM --platform=linux/arm64 node:20

# Set working directory
WORKDIR /app

# Install dependencies cleanly
COPY package.json package-lock.json ./
RUN npm install

# Copy everything else
COPY . .

# Expose port for Sanity Studio
EXPOSE 3333

# Run Sanity dev server
CMD ["npx", "sanity", "dev"]