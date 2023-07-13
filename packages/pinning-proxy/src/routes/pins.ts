import { badGateway } from "@hapi/boom";
import { object, string } from "joi";
import { getIPFSClusterAuthToken, uploadToIPFSCluster } from "../utils";
import type { ServerRoute } from "@hapi/hapi";

interface GetPinsRouteParams {
    ipfsClusterBaseURL: string;
    ipfsClusterUser: string;
    ipfsClusterPassword: string;
}

export const getPinsRoute = ({
    ipfsClusterBaseURL,
    ipfsClusterUser,
    ipfsClusterPassword,
}: GetPinsRouteParams): ServerRoute => {
    return {
        method: "POST",
        path: "/pins",
        options: {
            plugins: {
                "hapi-swagger": {
                    responses: {
                        400: {
                            description: "The request was not valid.",
                        },
                        502: {
                            description: "The data could not be stored.",
                        },
                        200: {
                            description: "The data was successfully stored.",
                            schema: object({
                                cid: string().label(
                                    "The cid for the stored data."
                                ),
                            }).required(),
                        },
                    },
                },
            },
            description: "Store text-like data on Carrot IPFS nodes.",
            notes:
                "Stores text-like data on the Carrot IPFS nodes. " +
                "The data is converted to text before the storing happens, " +
                "so trying to store binary data won't end with the expected result.",
            tags: ["api"],
            payload: {
                maxBytes: 1024, // 1kb
            },
            validate: {
                headers: object({
                    authorization: string()
                        .required()
                        .regex(
                            /^Bearer [0-9a-zA-Z]*\.[0-9a-zA-Z]*\.[0-9a-zA-Z-_]*$/
                        ),
                }).unknown(),
                payload: object({
                    content: string()
                        .regex(/^[A-Za-z0-9+/]*={0,2}$/)
                        .required()
                        .description("The base64-encoded text to store."),
                }),
            },
        },
        handler: async (request, h) => {
            let authToken;
            try {
                authToken = await getIPFSClusterAuthToken({
                    ipfsClusterBaseURL,
                    user: ipfsClusterUser,
                    password: ipfsClusterPassword,
                });
            } catch (error) {
                console.error("Could not authenticate to IPFS cluster", error);
                return badGateway("Could not upload file");
            }

            const { content: base64Content } = request.payload as {
                content: string;
            };
            const content = Buffer.from(base64Content, "base64").toString();

            let cid;
            try {
                cid = await uploadToIPFSCluster({
                    ipfsClusterBaseURL,
                    authToken,
                    content,
                });
            } catch (error) {
                console.error("Could not upload to IPFS cluster", error);
                return badGateway("Could not upload file");
            }

            return h.response({ cid }).code(200);
        },
    };
};
