import { Client } from "pg";
import { isAddress } from "viem/utils";
import type { Address } from "viem";
import { randomBytes } from "node:crypto";
import { NONCE_LENGTH_BYTES } from "./commons";

interface InitializeDatabaseParams {
    connectionString: string;
}

export const initializeDatabase = async ({
    connectionString,
}: InitializeDatabaseParams): Promise<Client> => {
    const client = await new Client({ connectionString });
    await client.connect();
    await client.query(
        `CREATE TABLE IF NOT EXISTS nonces (address VARCHAR(42) PRIMARY KEY, value VARCHAR(${
            NONCE_LENGTH_BYTES * 2
        }))`
    );
    return client;
};

interface UpdateOrInsertNonceParams {
    client: Client;
    address: Address;
}

export const updateOrInsertNonce = async ({
    client,
    address,
}: UpdateOrInsertNonceParams): Promise<string> => {
    if (!isAddress(address))
        throw new Error(`Invalid address ${address} given`);
    const nonce = randomBytes(NONCE_LENGTH_BYTES).toString("hex");
    await client.query(
        "INSERT INTO nonces (address, value) VALUES ($1, $2) ON CONFLICT (address) DO UPDATE SET value = EXCLUDED.value",
        [address, nonce]
    );
    return nonce;
};

interface GetNonceParams {
    client: Client;
    address: Address;
}

export const getNonce = async ({
    client,
    address,
}: GetNonceParams): Promise<string> => {
    if (!isAddress(address))
        throw new Error(`Invalid address ${address} given`);
    const result = await client.query(
        "SELECT value FROM nonces WHERE address = $1",
        [address]
    );
    const nonce = result.rows[0]?.value;
    if (!nonce) throw new Error(`No nonce value found for address ${address}`);
    return nonce;
};
