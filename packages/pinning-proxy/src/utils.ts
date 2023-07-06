import type { Address } from "viem";

interface GetEnvParams {
    name: string;
    required?: boolean;
}

export const getEnv = ({ name }: GetEnvParams): string => {
    const value = process.env[name];
    if (!value) throw new Error(`Env ${name} is required`);
    return value;
};

interface GetIPFSClusterAuthTokenParams {
    ipfsClusterBaseURL: string;
    password: string;
}

export const getIPFSClusterAuthToken = async ({
    ipfsClusterBaseURL,
    password,
}: GetIPFSClusterAuthTokenParams): Promise<string> => {
    const response = await fetch(new URL("/token", ipfsClusterBaseURL), {
        method: "POST",
        headers: {
            Authorization: `Basic ${Buffer.from(
                `pinning-proxy:${password}`
            ).toString("base64")}`,
        },
    });
    if (!response.ok)
        throw new Error("Could not get ipfs cluster authentication token");
    const { token } = (await response.json()) as { token: string };
    return token;
};

interface UploadToIPFSClusterParams {
    ipfsClusterBaseURL: string;
    authToken: string;
    content: string;
}

export const uploadToIPFSCluster = async ({
    ipfsClusterBaseURL,
    authToken,
    content,
}: UploadToIPFSClusterParams) => {
    const formData = new FormData();
    formData.append("file", new Blob([content], { type: "text/plain" }));
    const response = await fetch(new URL("/add", ipfsClusterBaseURL), {
        method: "POST",
        body: formData,
        headers: {
            Accept: "application/json",
            Authorization: `Bearer ${authToken}`,
        },
    });
    if (!response.ok)
        throw new Error("Could not upload the data to IPFS cluster");
    const { cid } = (await response.json()) as { cid: string };
    return cid;
};

interface GetLoginMessageParams {
    address: Address;
    nonce: string;
}

export const getLoginMessage = ({ address, nonce }: GetLoginMessageParams) => {
    return (
        "Welcome to Carrot!\n\n" +
        "Sign this message to authenticate.\n\n" +
        "This request will not trigger a blockchain transaction or cost you any fees.\n\n" +
        "Your authentication status will reset after 24 hours.\n\n" +
        "Wallet address:\n" +
        `${address}\n\n` +
        "Nonce:\n" +
        nonce
    );
};
