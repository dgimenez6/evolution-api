# ESTADIO 1: Construcción
FROM node:24-alpine AS builder

# Instalamos dependencias del sistema necesarias
RUN apk update && \
    apk add --no-cache git ffmpeg wget curl bash openssl

WORKDIR /evolution

# Copiamos archivos de configuración de dependencias
COPY ./package*.json ./
COPY ./tsconfig.json ./
COPY ./tsup.config.ts ./

# Instalamos dependencias de Node
RUN npm ci --silent

# Copiamos el resto del código fuente y carpetas necesarias
COPY ./src ./src
COPY ./public ./public
COPY ./prisma ./prisma
COPY ./manager ./manager
COPY ./runWithProvider.js ./
COPY ./Docker ./Docker

# Generamos el cliente de Prisma (vital para que el build no de error de tipos)
RUN npx prisma generate

# Compilamos el proyecto (genera la carpeta /dist)
RUN npm run build

# ESTADIO 2: Ejecución (Imagen final liviana)
FROM node:24-alpine AS final

# Instalamos solo lo necesario para correr la app
RUN apk update && \
    apk add tzdata ffmpeg bash openssl

# Configuración de entorno
ENV TZ=America/Sao_Paulo
ENV DOCKER_ENV=true
ENV NODE_ENV=production

WORKDIR /evolution

# Copiamos solo los archivos construidos y las dependencias desde el builder
COPY --from=builder /evolution/package.json ./package.json
COPY --from=builder /evolution/package-lock.json ./package-lock.json
COPY --from=builder /evolution/node_modules ./node_modules
COPY --from=builder /evolution/dist ./dist
COPY --from=builder /evolution/prisma ./prisma
COPY --from=builder /evolution/public ./public
COPY --from=builder /evolution/runWithProvider.js ./runWithProvider.js

# Exponemos el puerto que configuramos en Railway
EXPOSE 8080

# COMANDO FINAL: Arrancamos la app directamente con Node.
# Esto evita que los scripts internos busquen archivos .env que no existen
# y fuerza a la app a usar las Variables de Entorno de Railway.
CMD ["node", "dist/main.js"]