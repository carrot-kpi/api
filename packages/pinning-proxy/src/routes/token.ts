import { badRequest, forbidden, internal } from "@hapi/boom";
import { object, string } from "joi";
import { isAddress, getAddress, recoverMessageAddress } from "viem/utils";
import type { Hex, Address } from "viem";
import { getNonce } from "../db";
import { getLoginMessage } from "../utils";
import type { Client } from "pg";
import type { ServerRoute } from "@hapi/hapi";
import { generateJWT } from "../auth";

interface GetTokenRouteParams {
    dbClient: Client;
    jwtSecretKey: string;
}

export const getTokenRoute = ({
    dbClient,
    jwtSecretKey,
}: GetTokenRouteParams): ServerRoute => {
    return {
        method: "POST",
        path: "/token",
        options: {
            plugins: {
                "hapi-swagger": {
                    description:
                        "Generates a new JWT token for a given user, and returns it." +
                        "The token will be valid for 24 hours",
                    responses: {
                        400: {
                            description:
                                "The signature parameter was either not given or not valid.",
                        },
                        200: {
                            description:
                                "The JWT was successfully created, the response contains it.",
                            schema: object({
                                token: string().label("The created JWT."),
                            }),
                        },
                    },
                },
            },
            auth: false,
            tags: ["api"],
            validate: {
                payload: object({
                    address: string()
                        .required()
                        .regex(/0x[a-fA-F0-9]{40}/)
                        .description(
                            "The address of the account which signed the login message."
                        ),
                    signature: string()
                        .required()
                        .regex(/0x[a-fA-F0-9]+/)
                        .description(
                            "A signed message that proves the user owns the address being authenticated. " +
                                "The signed message must be retrieved using the login message API."
                        ),
                }),
            },
        },
        handler: async (request, h) => {
            const { address, signature } = request.payload as {
                address: Address;
                signature: Hex;
            };

            if (!isAddress(address)) return badRequest("Invalid address");
            const checksummedAddress = getAddress(address);

            let nonce;
            try {
                nonce = await getNonce({
                    client: dbClient,
                    address: checksummedAddress,
                });
            } catch (error) {
                console.error(
                    `Could not get nonce for address ${checksummedAddress}`,
                    error
                );
                return badRequest(
                    `Could not get nonce for address ${checksummedAddress}`
                );
            }

            let recoveredAddress;
            try {
                recoveredAddress = await recoverMessageAddress({
                    message: getLoginMessage({
                        address: checksummedAddress,
                        nonce,
                    }),
                    signature,
                });
            } catch (error) {
                console.error("Error while recovering signer", error);
                return badRequest("Error while recovering signer");
            }

            if (recoveredAddress !== address)
                return forbidden("Address mismatch");

            let token;
            try {
                token = generateJWT({ jwtSecretKey });
            } catch (error) {
                console.error("Error while generating JWT", error);
                return internal("Error while generating JWT");
            }

            return h.response({ token }).type("application/json");
        },
    };
};
