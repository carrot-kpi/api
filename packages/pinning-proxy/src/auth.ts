import type { ServerAuthScheme } from "@hapi/hapi";
import { sign as signJWT, verify as verifyJWT } from "jsonwebtoken";

export const JWT_ISSUER = "carrot-pinning-proxy";

interface GetAuthenticationSchemeParams {
    jwtSecretKey: string;
}

export const getAuthenticationScheme = ({
    jwtSecretKey,
}: GetAuthenticationSchemeParams): ServerAuthScheme => {
    return () => ({
        authenticate: (request, h) => {
            const { authorization } = request.headers as {
                authorization?: string;
            };

            if (!authorization)
                return h.unauthenticated(
                    new Error("Missing Authorization header")
                );

            if (
                !authorization.match(
                    /^Bearer [0-9a-zA-Z]*\.[0-9a-zA-Z]*\.[0-9a-zA-Z-_]*$/
                )
            )
                return h.unauthenticated(
                    new Error("Malformed Authorization header")
                );

            const jwt = authorization.split(" ")[1];

            try {
                verifyJWT(jwt, jwtSecretKey, { issuer: JWT_ISSUER });
            } catch (error) {
                return h.unauthenticated(new Error("Invalid JWT"));
            }

            return h.authenticated({ credentials: {} });
        },
    });
};

interface GenerateJWTParams {
    jwtSecretKey: string;
}

export const generateJWT = ({ jwtSecretKey }: GenerateJWTParams) => {
    return signJWT({}, jwtSecretKey, {
        expiresIn: "24 hours",
        issuer: JWT_ISSUER,
    });
};
