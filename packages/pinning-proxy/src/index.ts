import { server as createServer } from "@hapi/hapi";
import type { RegisterOptions } from "hapi-swagger";
import { initializeDatabase } from "./db";
import { getEnv } from "./utils";
import { getLoginMessageRoute } from "./routes/login-message";
import { getTokenRoute } from "./routes/token";
import { getPinsRoute } from "./routes/pins";
import { config } from "dotenv";
import { getAuthenticationScheme } from "./auth";

if (process.env.NODE_ENV !== "production") config();

const HOST = getEnv({ name: "HOST" });
const PORT = getEnv({ name: "PORT" });
const JWT_SECRET_KEY = getEnv({ name: "JWT_SECRET_KEY" });
const DB_CONNECTION_STRING = getEnv({ name: "DB_CONNECTION_STRING" });
const IPFS_CLUSTER_BASE_URL = getEnv({ name: "IPFS_CLUSTER_BASE_URL" });
const IPFS_CLUSTER_AUTH_PASSWORD = getEnv({
    name: "IPFS_CLUSTER_AUTH_PASSWORD",
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
