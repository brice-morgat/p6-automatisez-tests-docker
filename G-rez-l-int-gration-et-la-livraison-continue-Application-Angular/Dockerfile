FROM node:20.19-alpine AS builder

WORKDIR /app

COPY package.json package-lock.json ./
RUN npm ci

COPY . .
RUN npm run build

FROM nginx:1.27-alpine AS runtime

COPY nginx/nginx.conf /etc/nginx/nginx.conf
COPY --from=builder /app/dist/olympic-games-starter/browser/ /app/

EXPOSE 80

CMD ["nginx", "-g", "daemon off;"]
