FROM ghcr.io/cirruslabs/flutter:stable AS build

WORKDIR /app

COPY . .

RUN flutter config --enable-web
RUN flutter pub get

ARG API_BASE_URL=https://api.clubbar.com.br

RUN flutter build web --dart-define=API_BASE_URL=${API_BASE_URL}

FROM nginx:alpine

COPY --from=build /app/build/web /usr/share/nginx/html
COPY nginx.conf /etc/nginx/conf.d/default.conf

EXPOSE 80