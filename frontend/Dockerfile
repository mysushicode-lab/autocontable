FROM node:18-alpine as build

WORKDIR /app

ARG REACT_APP_API_URL
ARG CACHEBUST=2
ENV REACT_APP_API_URL=$REACT_APP_API_URL

COPY package*.json ./
RUN npm install

COPY . .
RUN sed -i "s|const API_BASE_URL = .*|const API_BASE_URL = 'https://api.carrosserie-erik.fr';|" src/api.js
RUN cat src/api.js | head -5
RUN npm run build

FROM nginx:alpine
COPY --from=build /app/build /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80
