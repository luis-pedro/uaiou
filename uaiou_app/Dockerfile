# Flutter Web da feira: compila e serve os estÃ¡ticos com nginx.
FROM ghcr.io/cirruslabs/flutter:3.44.0 AS build
WORKDIR /app
COPY pubspec.* ./
RUN flutter pub get
COPY . .
ARG UAIOU_API_BASE_URL=https://uaiou-backend-feira.up.railway.app/api/v1
RUN flutter build web --release --dart-define=UAIOU_API_BASE_URL=${UAIOU_API_BASE_URL}

FROM nginx:alpine
COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/templates/default.conf.template
ENV PORT=8080
