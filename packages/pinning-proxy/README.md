<br />

<p align="center">
    <img src="../../.github/static/logo.svg" alt="Carrot logo" width="60%" />
</p>

<br />

<p align="center">
    Carrot is a web3 protocol trying to make incentivization easier and more capital
    efficient.
</p>

<br />

<p align="center">
    <img src="https://img.shields.io/badge/License-GPLv3-blue.svg" alt="License: GPL v3">
</p>

# Carrot pinning proxy

This project implements a simple server that acts as a proxy to Carrot's IPFS
pinning services. The pinning capabilities are protected by a signature-based
authentication scheme with signature replay protection.

## Tech used

The server is developed in Typescript using `hapi`. The plugins used are:

- `boom`: used to easily handle error responses.
- `inert`, `vision` and `swagger`: used to serve a static OpenAPI documentation
  of the service.

Additionally, request validation is performed using `joi`.

## Testing the server

Start by installing the dependencies using `yarn`. From the root of the
monorepo:

```
yarn install
```

Once the dependencies are installed, create a `.env` file at the root of this
package. For convenience, you can copy and paste the provided `.env.example`
file and rename it to `.env`. The latter is the suggested option as the
`.env.example` file also has sensible values that are compatible out of the box
with the Docker Compose containerized related infrastructure (see below for the
details).

The required env variables are:

- `HOST`: the server's host.
- `PORT`: the server's port.
- `JWT_SECRET_KEY`: the secret key used to sign the issued JWTs. It's of utmost
  importance to keep this value secret.
- `IPFS_CLUSTER_BASE_URL`: the base URL where the proxied IPFS cluster API is
  being exposed.
- `IPFS_CLUSTER_AUTH_USER`: the IPFS cluster API user as set using the
  `basic_auth_credentials` parameter (see
  [here](https://ipfscluster.io/documentation/reference/configuration/)). This
  will be used to request the API auth token through which pins can be added
- `IPFS_CLUSTER_AUTH_PASSWORD`: the IPFS cluster API password as set using the
  `basic_auth_credentials` parameter (see
  [here](https://ipfscluster.io/documentation/reference/configuration/)). This
  will be used to request the API auth token through which pins can be added.

Once the `.env` file has been created, it's necessary to have all the correlated
infrastructure up and running in order to properly test the server. In
particular we need:

- A `Postgres` database in which the server can store nonces to avoid signature
  replay attacks.
- An `IPFS` node on which to pin our data.
- An `IPFS cluster` instance, connected to the IPFS node, with its REST API
  exposed. We'll use this as the backend pinning service to which the server
  will forward authenticated requests.

For convenience, these pieces of infrastructure can easily be bootstrapped using
the provided `docker-compose.yaml` file at the root of the package. Run the
following command to bootstrap everything:

```
docker compose up
```

> **Warning** Make sure your env variables and the containers' settings (such as
> the Postgres credentials etc) match up.

At this point you can go ahead and start the server using with the following
command launched from the server package's root:

```
yarn start
```

Keep in mind that no automatic restart of the server's code on changes has been
implemented, so as of now if you want to change something you'll have to kill
and restart the server manually.

## OpenAPI

The OpenAPI specification is exposed under `/swagger.json`, while the Swagger UI
is exposed under `/documentation`, so you can easily test the API that way.

## Docker build

To build a Docker image of the service, run the following command from the root
of the monorepo:

```
docker build . -f packages/pinning-proxy/Dockerfile
```
