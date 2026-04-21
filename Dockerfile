# ---- Build stage ----
FROM elixir:1.18-otp-27-alpine AS build

RUN apk add --no-cache build-base git nodejs npm

WORKDIR /app

ENV MIX_ENV=prod

RUN mix local.hex --force && mix local.rebar --force

COPY mix.exs mix.lock ./
RUN mix deps.get --only prod
RUN mix deps.compile

COPY config config
COPY priv priv
COPY lib lib
COPY assets assets

RUN mix compile
RUN mix assets.deploy
RUN mix release

# ---- Runtime stage ----
FROM elixir:1.18-otp-27-alpine AS runtime

RUN apk add --no-cache libstdc++ openssl ncurses-libs

WORKDIR /app

COPY --from=build /app/_build/prod/rel/canvas_mcp ./
RUN touch .env

ENV PHX_SERVER=true

EXPOSE 4000

CMD ["bin/canvas_mcp", "start"]
