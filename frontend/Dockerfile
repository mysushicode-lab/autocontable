FROM node:18-alpine

WORKDIR /app

# Install dependencies (including devDependencies needed for build)
COPY package*.json ./
RUN npm ci

# Copy source
COPY . .

# Build-time variables (baked into client-side JS)
ARG NEXT_PUBLIC_API_URL=/api
ARG NEXT_PUBLIC_SITE_URL=https://factpilot.fr

ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_PUBLIC_SITE_URL=$NEXT_PUBLIC_SITE_URL

# Build Next.js app
RUN npm run build

# Runtime variable for server-side proxy (not baked into client)
# Set via docker-compose environment at runtime
ENV BACKEND_URL=http://backend:8000

EXPOSE 3000

CMD ["npm", "start"]
