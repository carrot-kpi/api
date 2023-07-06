import type { ServerRoute } from "@hapi/hapi";
import { badRequest, internal } from "@hapi/boom";
import { object, string } from "joi";
import { isAddress, getAddress } from "viem/utils";
import { updateOrInsertNonce } from "../db";
import { getLoginMessage } from "../utils";
import type { Client } from "pg";

interface GetLoginMessageRouteParams {
    dbClient: Client;
}

export const getLoginMessageRoute = ({
    dbClient,
}: GetLoginMessageRouteParams): ServerRoute => {
    return {
        method: "PUT",
        path: "/login-message/{address}",
        options: {
            plugins: {
                "hapi-swagger": {
                    description:
                        "Updates or creates a new nonce for a given address (user), " +
                        "and returns the login message that a user needs to sign in order " +
                        "to authenticate, with the nonce baked in. This is used in order " +
                        "to avoid signature replay attacks.",
                    responses: {
                        400: {
                            description:
                                "The address parameter was either not given or not valid.",
                        },
                        200: {
                            description:
                                "The nonce was created; The response contains the full login " +
                                "message to sign in order to authenticate.",
                            schema: object({
                                message: string().label(
                                    "The login message with the baked in nonce."
                                ),
                            }).required(),
                        },
                    },
                },
            },
            auth: false,
            tags: ["api"],
            validate: {
                params: object({
                    address: string()
                        .required()
                        .regex(/0x[a-fA-F0-9]{40}/)
                        .description(
                            "The address for which to generate the login message."
                        ),
                }),
            },
        },
        handler: async (request, h) => {
            const { address } = request.params;
            if (!isAddress(address)) return badRequest("invalid address");
            const checksummedAddress = getAddress(address);

            let nonce;
            try {
                nonce = await updateOrInsertNonce({
                    client: dbClient,
                    address: checksummedAddress,
                });
            } catch (error) {
                console.error(
                    `Could not update or insert nonce for address ${checksummedAddress}`,
                    error
                );
                return internal("could not update or create nonce");
            }

            return h
                .response({
                    message: getLoginMessage({
                        address: checksummedAddress,
                        nonce,
                    }),
                })
                .type("application/json");
        },
    };
};
