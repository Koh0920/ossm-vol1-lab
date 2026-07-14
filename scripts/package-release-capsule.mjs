#!/usr/bin/env node

import {
  createHash,
  createPrivateKey,
  createPublicKey,
  sign,
} from "node:crypto";
import { spawnSync } from "node:child_process";
import {
  chmodSync,
  mkdirSync,
  readFileSync,
  rmSync,
  writeFileSync,
} from "node:fs";
import { basename, dirname, resolve } from "node:path";

const TAR_BLOCK_SIZE = 512;
const ED25519_PKCS8_PREFIX = Buffer.from("302e020100300506032b657004220420", "hex");
const BASE58_ALPHABET = "123456789ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz";

function fail(message) {
  console.error(message);
  process.exit(1);
}

function writeTarString(header, offset, length, value) {
  const bytes = Buffer.from(value, "utf8");
  if (bytes.length > length) fail(`tar field is too long: ${value}`);
  bytes.copy(header, offset);
}

function writeTarOctal(header, offset, length, value) {
  const encoded = value.toString(8).padStart(length - 1, "0") + "\0";
  writeTarString(header, offset, length, encoded);
}

function createTar(entries) {
  const chunks = [];
  for (const entry of entries) {
    if (!entry.path || entry.path.startsWith("/") || entry.path.includes("..")) {
      fail(`unsafe tar path: ${entry.path}`);
    }
    const header = Buffer.alloc(TAR_BLOCK_SIZE);
    writeTarString(header, 0, 100, entry.path);
    writeTarOctal(header, 100, 8, entry.mode ?? 0o644);
    writeTarOctal(header, 108, 8, 0);
    writeTarOctal(header, 116, 8, 0);
    writeTarOctal(header, 124, 12, entry.data.length);
    writeTarOctal(header, 136, 12, 0);
    header.fill(0x20, 148, 156);
    header[156] = "0".charCodeAt(0);
    writeTarString(header, 257, 6, "ustar\0");
    writeTarString(header, 263, 2, "00");
    writeTarString(header, 265, 32, "root");
    writeTarString(header, 297, 32, "root");
    const checksum = header.reduce((sum, byte) => sum + byte, 0);
    writeTarString(header, 148, 8, checksum.toString(8).padStart(6, "0") + "\0 ");
    chunks.push(header, entry.data);
    const padding = (TAR_BLOCK_SIZE - (entry.data.length % TAR_BLOCK_SIZE)) % TAR_BLOCK_SIZE;
    if (padding) chunks.push(Buffer.alloc(padding));
  }
  chunks.push(Buffer.alloc(TAR_BLOCK_SIZE * 2));
  return Buffer.concat(chunks);
}

function sha256(bytes) {
  return `sha256:${createHash("sha256").update(bytes).digest("hex")}`;
}

function base58(bytes) {
  let zeros = 0;
  while (zeros < bytes.length && bytes[zeros] === 0) zeros += 1;
  const digits = [0];
  for (const byte of bytes) {
    let carry = byte;
    for (let index = 0; index < digits.length; index += 1) {
      carry += digits[index] << 8;
      digits[index] = carry % 58;
      carry = Math.floor(carry / 58);
    }
    while (carry > 0) {
      digits.push(carry % 58);
      carry = Math.floor(carry / 58);
    }
  }
  return "1".repeat(zeros) + digits.reverse().map((digit) => BASE58_ALPHABET[digit]).join("");
}

function run(command, args) {
  const result = spawnSync(command, args, { encoding: "utf8", stdio: ["ignore", "pipe", "pipe"] });
  if (result.status !== 0) {
    fail(`${command} failed: ${result.stderr.trim()}`);
  }
}

const [outputArgument, keyArgument] = process.argv.slice(2);
if (!outputArgument || !keyArgument) {
  fail("usage: package-release-capsule.mjs <output.capsule> <publisher-signing-key.json>");
}

const projectRoot = resolve(dirname(new URL(import.meta.url).pathname), "..");
const outputPath = resolve(outputArgument);
const workDir = resolve(projectRoot, ".tmp", "release-capsule");
const manifest = readFileSync(resolve(projectRoot, "capsule.toml"));
const lock = readFileSync(resolve(projectRoot, "capsule.lock.json"));
const atoLock = readFileSync(resolve(projectRoot, "ato.lock.json"));
const readme = readFileSync(resolve(projectRoot, "README.md"));
const version = manifest.toString("utf8").match(/^version\s*=\s*"([^"]+)"/m)?.[1];
if (!version) fail("capsule.toml must declare a version");
const key = JSON.parse(readFileSync(resolve(keyArgument), "utf8"));
const secretKey = Buffer.from(key.secret_key, "base64");
const publicKey = Buffer.from(key.public_key, "base64");
if (key.key_type !== "ed25519" || secretKey.length !== 32 || publicKey.length !== 32) {
  fail("publisher signing key must contain a valid Ed25519 keypair");
}

rmSync(workDir, { recursive: true, force: true });
mkdirSync(workDir, { recursive: true });
mkdirSync(dirname(outputPath), { recursive: true });

const innerTarPath = resolve(workDir, "payload.tar");
const payloadPath = resolve(workDir, "payload.tar.zst");
writeFileSync(
  innerTarPath,
  createTar([
    { path: "config.json", data: Buffer.from("{}\n") },
    { path: "source/README.md", data: readme },
  ]),
);
run("zstd", ["-19", "--threads=0", "--force", innerTarPath, "-o", payloadPath]);
const payload = readFileSync(payloadPath);

const sbom = Buffer.from(
  JSON.stringify({
    SPDXID: "SPDXRef-DOCUMENT",
    creationInfo: {
      created: new Date(Number(process.env.SOURCE_DATE_EPOCH ?? "0") * 1000).toISOString(),
      creators: ["Tool: ossm-vol1-lab/package-release-capsule"],
    },
    dataLicense: "CC0-1.0",
    documentNamespace: `https://ato.run/spdx/ossm-vol1-lab/${sha256(manifest).slice(7)}`,
    name: `ossm-vol1-lab-${version}`,
    packages: [],
    spdxVersion: "SPDX-2.3",
  }),
);

const privateKey = createPrivateKey({
  key: Buffer.concat([ED25519_PKCS8_PREFIX, secretKey]),
  format: "der",
  type: "pkcs8",
});
const derivedPublicKey = createPublicKey(privateKey).export({ format: "der", type: "spki" }).subarray(-32);
if (!derivedPublicKey.equals(publicKey)) fail("public key does not match the stored secret key");
const keyId = `did:key:z${base58(Buffer.concat([Buffer.from([0xed, 0x01]), publicKey]))}`;
const signedAt = new Date(Number(process.env.SOURCE_DATE_EPOCH ?? Math.floor(Date.now() / 1000)) * 1000).toISOString();
const preimage = {
  alg: "ed25519",
  key_id: keyId,
  manifest_hash: sha256(manifest),
  payload_hash: sha256(payload),
  signed_at: signedAt,
  version: "1",
};
const signature = sign(null, Buffer.from(JSON.stringify(preimage)), privateKey).toString("base64");
const signatureJson = Buffer.from(JSON.stringify({
  alg: preimage.alg,
  key_id: preimage.key_id,
  manifest_hash: preimage.manifest_hash,
  payload_hash: preimage.payload_hash,
  signature,
  signed_at: preimage.signed_at,
  version: preimage.version,
}));

writeFileSync(
  outputPath,
  createTar([
    { path: "capsule.toml", data: manifest },
    { path: "ato.lock.json", data: atoLock },
    { path: "capsule.lock.json", data: lock },
    { path: "sbom.spdx.json", data: sbom },
    { path: "signature.json", data: signatureJson },
    { path: "payload.tar.zst", data: payload },
    { path: "README.md", data: readme },
  ]),
);
chmodSync(outputPath, 0o644);
console.log(JSON.stringify({ artifact: outputPath, file: basename(outputPath), sha256: sha256(readFileSync(outputPath)) }));
