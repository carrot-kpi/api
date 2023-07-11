import { server as createServer } from "@hapi/hapi";
import type { RegisterOptions } from "hapi-swagger";
import { initializeDatabase } from "./db";
import { getLoginMessageRoute } from "./routes/login-message";
import { getTokenRoute } from "./routes/token";
import { getPinsRoute } from "./routes/pins";
import { config } from "dotenv";
import { getAuthenticationScheme } from "./auth";
import { requireEnv } from "./utils";

if (process.env.NODE_ENV !== "production") config();

const HOST = requireEnv({ name: "HOST", value: process.env.HOST });
const PORT = requireEnv({ name: "PORT", value: process.env.PORT });
const JWT_SECRET_KEY = requireEnv({
    name: "JWT_SECRET_KEY",
    value: process.env.JWT_SECRET_KEY,
});
const DB_CONNECTION_STRING = requireEnv({
    name: "DB_CONNECTION_STRING",
    value: process.env.DB_CONNECTION_STRING,
});
const IPFS_CLUSTER_BASE_URL = requireEnv({
    name: "IPFS_CLUSTER_BASE_URL",
    value: process.env.IPFS_CLUSTER_BASE_URL,
});
const IPFS_CLUSTER_AUTH_USER = requireEnv({
    name: "IPFS_CLUSTER_AUTH_USER",
    value: process.env.IPFS_CLUSTER_AUTH_USER,
});
const IPFS_CLUSTER_AUTH_PASSWORD = requireEnv({
    name: "IPFS_CLUSTER_AUTH_PASSWORD",
    value: process.env.IPFS_CLUSTER_AUTH_PASSWORD,
});

const start = async () => {
    let dbClient;
    try {
        dbClient = await initializeDatabase({
            connectionString: DB_CONNECTION_STRING,
        });
    } catch (error) {
        console.error("Could not connect to database", error);
        process.exit(1);
    }

    const server = createServer({
        host: HOST,
        port: PORT,
    });

    await server.register([
        require("@hapi/inert"),
        require("@hapi/vision"),
        {
            plugin: require("hapi-swagger"),
            options: <RegisterOptions>{
                info: {
                    title: "Pinning proxy API",
                    version: "1.0.0",
                    description:
                        "An API to access Carrot's pinning services to upload campaigns data to IPFS. It's authenticated using Ethereum signatures.",
                    contact: {
                        name: "Carrot Labs",
                        email: "tech@carrot-labs.xyz",
                    },
                },
            },
        },
    ]);

    server.auth.scheme(
        "jwt",
        getAuthenticationScheme({ jwtSecretKey: JWT_SECRET_KEY })
    );
    server.auth.strategy("jwt", "jwt");
    server.auth.default("jwt");

    server.route(getLoginMessageRoute({ dbClient }));
    server.route(getTokenRoute({ dbClient, jwtSecretKey: JWT_SECRET_KEY }));
    server.route(
        getPinsRoute({
            ipfsClusterBaseURL: IPFS_CLUSTER_BASE_URL,
            ipfsClusterUser: IPFS_CLUSTER_AUTH_USER,
            ipfsClusterPassword: IPFS_CLUSTER_AUTH_PASSWORD,
        })
    );

    try {
        await server.start();
        console.log(`Server running on ${server.info.uri}`);
    } catch (error) {
        console.error(`Could not start server`, error);
    }
};

start();
