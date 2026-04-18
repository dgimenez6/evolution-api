FROM node:24-alpine AS builder
RUN apk update && apk add --no-cache git ffmpeg wget curl bash openssl
WORKDIR /evolution
COPY package*.json ./
COPY tsconfig.json ./
COPY tsup.config.ts ./
RUN npm ci --silent
COPY ./prisma ./prisma
RUN npx prisma generate --schema ./prisma/schema.prisma
COPY ./src ./src
COPY ./public ./public
COPY ./manager ./manager
COPY ./runWithProvider.js ./
COPY ./Docker ./Docker
RUN npm run build

FROM node:24-alpine AS final
RUN apk update && apk add tzdata ffmpeg bash openssl
ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true
ENV NODE_ENV=production
WORKDIR /evolution
COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js
EXPOSE 8080
CMD ["sh", "-c", "npx prisma db push && node dist/main.js"]