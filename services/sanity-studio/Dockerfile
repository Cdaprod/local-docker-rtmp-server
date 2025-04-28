# services/sanity-studio/Dockerfile

FROM node:20

# Set working directory
WORKDIR /app

# Install global Sanity CLI
RUN yarn global add sanity

# Copy package.json and install dependencies
COPY package.json yarn.lock ./
RUN yarn install

# Copy all project files
COPY . .

# Expose Sanity dev server port
EXPOSE 3333

# Default command
CMD ["yarn", "dev"]