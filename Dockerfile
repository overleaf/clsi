FROM node:6.13.0 as app

COPY ./ /app

WORKDIR /app

RUN npm install


RUN npm run compile:all

FROM node:6.13.0

COPY --from=app /app /app

WORKDIR /app


# All app and node_modules will be owned by root.
# The app will run as the 'app' user, and so not have write permissions
# on any files it doesn't need.
RUN useradd --user-group --create-home --home-dir /app --shell /bin/false app

RUN [ -e ./install_deps.sh ] && ./install_deps.sh

USER app
CMD ["node","app.js"]
