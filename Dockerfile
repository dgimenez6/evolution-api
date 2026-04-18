# ESTADIO 1: Construcción
FROM node:24-alpine AS builder

RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl

WORKDIR /evolution

# 1. Copiamos archivos de configuración
COPY package*.json ./
COPY tsconfig.json ./
COPY tsup.config.ts ./

# 2. Instalamos dependencias (incluye Prisma)
RUN npm ci --silent

# 3. Copiamos la carpeta prisma 
# IMPORTANTE: Asegurate de que el archivo adentro se llame schema.prisma
COPY ./prisma ./prisma

# 4. Generamos el cliente de Prisma
# Esto debe ir ANTES del build para que TypeScript reconozca los modelos
RUN npx prisma generate --schema ./prisma/schema.prisma

# 5. Copiamos el código fuente y construimos
COPY ./src ./src
COPY ./public ./public
COPY ./manager ./manager
COPY ./runWithProvider.js ./
COPY ./Docker ./Docker

# 6. Compilamos el proyecto
RUN npm run build

# ESTADIO 2: Ejecución
FROM node:24-alpine AS final

RUN apk update && \
    apk add tzdata ffmpeg bash openssl

ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true
ENV NODE_ENV=production

WORKDIR /evolution

# Copiamos lo construido y las dependencias
COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js

# Exponemos el puerto de Railway
EXPOSE 8080

# Arrancamos directo. Sin scripts intermedios que busquen archivos .env
CMD ["node", "dist/main.js"]